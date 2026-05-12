const assert = require('assert');
const path = require('path');

const sidecar = require('../tools/playwright_advisor_scan_sidecar');

const RUNTIME_STUB = 'copy(String((() => { const op = @@OP@@; const args = @@ARGS@@ || {}; return JSON.stringify({ op, args }); })()))';

function testReadOnlyAllowlist() {
  assert.deepStrictEqual(sidecar.DEFAULT_BUNDLE_OPS, [
    'advisor_state_snapshot',
    'advisor_active_modal_status',
    'gather_rapport_snapshot',
    'asc_drivers_vehicles_snapshot',
    'scan_current_page'
  ]);
  for (const op of sidecar.DEFAULT_BUNDLE_OPS) {
    assert.ok(sidecar.READ_ONLY_OPS.includes(op), `default op must be read-only: ${op}`);
  }
  for (const mutatingOp of ['click_by_id', 'click_by_text', 'fill_gather_defaults', 'confirm_potential_vehicle']) {
    assert.throws(() => sidecar.assertReadOnlyOps([mutatingOp]), /Refusing non-read-only Advisor op/);
  }
}

function testPayloadRenderingRefusesMutations() {
  const args = sidecar.buildArgsForOp('advisor_state_snapshot');
  const rendered = sidecar.renderOperatorPayload(RUNTIME_STUB, 'advisor_state_snapshot', args);
  assert.ok(rendered.includes('const op = "advisor_state_snapshot"'));
  assert.ok(rendered.includes('"advisorQuotingButtonId":"group2_Quoting_button"'));
  assert.ok(!rendered.includes('@@OP@@'));
  assert.ok(!rendered.includes('@@ARGS@@'));

  assert.throws(
    () => sidecar.renderOperatorPayload(RUNTIME_STUB, 'fill_participant_modal', {}),
    /Refusing non-read-only Advisor op/
  );
}

function testDirectCdpFallbackSelection() {
  const missingRequire = (packageName) => {
    const error = new Error(`missing ${packageName}`);
    error.code = 'MODULE_NOT_FOUND';
    throw error;
  };
  assert.strictEqual(sidecar.loadPlaywright({ requireFn: missingRequire }), null);
  assert.strictEqual(sidecar.selectScanBackend(null), 'direct-cdp');
  assert.strictEqual(sidecar.selectScanBackend({ chromium: {} }), 'playwright-cdp');
}

function testAdvisorArgsMirrorSnapshotContract() {
  const scanArgs = sidecar.buildArgsForOp('scan_current_page', {
    label: 'CONTRACT_TEST',
    reason: 'unit'
  });
  assert.strictEqual(scanArgs.label, 'CONTRACT_TEST');
  assert.strictEqual(scanArgs.reason, 'unit');
  assert.strictEqual(scanArgs.urls.rapportContains, '/rapport');
  assert.strictEqual(scanArgs.urls.ascProductContains, '/ASCPRODUCT/');
  assert.strictEqual(scanArgs.texts.customerSummaryStartHereText, 'START HERE (Pre-fill included)');
  assert.strictEqual(scanArgs.selectors.driverVehicleContinueId, 'profile-summary-submitBtn');

  const snapshotArgs = sidecar.buildArgsForOp('advisor_state_snapshot');
  assert.strictEqual(snapshotArgs.source, 'playwright-sidecar');
  assert.strictEqual(snapshotArgs.selectors.createQuotesButtonId, 'consentModalTrigger');
}

function testActualRuntimeRendersReadOnlyOps() {
  const runtime = sidecar.loadOperatorRuntime();
  for (const op of sidecar.DEFAULT_BUNDLE_OPS) {
    const rendered = sidecar.renderOperatorPayload(runtime, op, sidecar.buildArgsForOp(op));
    assert.ok(rendered.includes(`const op = "${op}"`), `rendered runtime missing op literal for ${op}`);
    assert.ok(!rendered.includes('@@OP@@'), `rendered runtime kept op marker for ${op}`);
    assert.ok(!rendered.includes('@@ARGS@@'), `rendered runtime kept args marker for ${op}`);
  }
}

function testDirectCdpRequestsAreReadOnlyRuntimeEvaluateOnly() {
  const requests = sidecar.buildDirectCdpEvaluationRequests(RUNTIME_STUB, [
    'advisor_state_snapshot',
    'scan_current_page'
  ], {
    label: 'CONTRACT_TEST',
    reason: 'direct-cdp'
  });
  assert.strictEqual(requests.length, 2);
  for (const request of requests) {
    assert.strictEqual(request.method, 'Runtime.evaluate');
    assert.strictEqual(request.params.awaitPromise, true);
    assert.strictEqual(request.params.returnByValue, true);
    assert.strictEqual(request.params.userGesture, false);
    assert.ok(request.params.expression.includes("Function('copy'"));
    assert.ok(!request.params.expression.includes('Page.navigate'));
    assert.ok(!request.params.expression.includes('Input.dispatchKeyEvent'));
    assert.ok(!request.params.expression.includes('Input.insertText'));
    assert.ok(!request.params.expression.includes('Runtime.callFunctionOn'));
    assert.ok(!request.params.expression.includes('Page.captureScreenshot'));
  }

  assert.throws(
    () => sidecar.buildDirectCdpEvaluationRequests(RUNTIME_STUB, ['click_by_id'], {}),
    /Refusing non-read-only Advisor op/
  );
  assert.throws(
    () => sidecar.buildDirectCdpEvaluateExpression(RUNTIME_STUB, 'fill_gather_defaults', {}),
    /Refusing non-read-only Advisor op/
  );
}

function testDirectCdpMethodGuard() {
  assert.deepStrictEqual(sidecar.DIRECT_CDP_METHODS, ['Runtime.evaluate']);
  sidecar.assertCdpMethodAllowed('Runtime.evaluate');
  for (const method of [
    'Page.navigate',
    'Input.dispatchKeyEvent',
    'Input.insertText',
    'Runtime.callFunctionOn',
    'Page.captureScreenshot',
    'Page.startScreencast'
  ]) {
    assert.throws(() => sidecar.assertCdpMethodAllowed(method), /Refusing/);
  }
}

async function testDirectCdpScanUsesTargetListAndRuntimeEvaluateOnly() {
  const sentMethods = [];
  const fakeClient = {
    send(method, params) {
      sentMethods.push({ method, params });
      assert.strictEqual(method, 'Runtime.evaluate');
      return Promise.resolve({
        result: {
          type: 'string',
          value: JSON.stringify({
            ok: true,
            op: 'advisor_state_snapshot',
            route: 'RAPPORT',
            confidence: 0.88,
            blockers: [],
            allowedNextActions: [],
            unsafeReason: null
          })
        }
      });
    },
    close() {
      throw new Error('provided test client should not be closed by sidecar');
    }
  };
  const fetchImpl = async (url) => {
    assert.ok(String(url).endsWith('/json'));
    return {
      ok: true,
      status: 200,
      statusText: 'OK',
      json: async () => [{
        type: 'page',
        url: 'https://advisorpro.allstate.com/#/apps/intel/102/rapport',
        title: 'Advisor Pro',
        webSocketDebuggerUrl: 'ws://127.0.0.1:9222/devtools/page/1'
      }]
    };
  };
  const config = sidecar.parseArgv([
    '--op=advisor_state_snapshot',
    '--no-write',
    '--timeout-ms=1000'
  ], { env: {}, cwd: path.resolve(__dirname, '..') });
  const envelope = await sidecar.runScanWithDirectCdp(config, {
    client: fakeClient,
    fetchImpl,
    runtimeText: RUNTIME_STUB
  });
  assert.strictEqual(envelope.connection.kind, 'direct-cdp');
  assert.strictEqual(envelope.target.url, 'https://advisorpro.allstate.com/#/apps/intel/102/rapport');
  assert.deepStrictEqual(sentMethods.map((entry) => entry.method), ['Runtime.evaluate']);
  assert.strictEqual(envelope.results.length, 1);
}

function testArgParsingAndOutputGuard() {
  const config = sidecar.parseArgv([
    '--cdp-url=http://127.0.0.1:9333',
    '--target-url-contains=advisorpro.allstate.com,example.internal',
    '--op=advisor_state_snapshot,scan_current_page',
    '--output=logs/test_playwright_scan.json',
    '--timeout-ms=1500'
  ], { env: {}, cwd: path.resolve(__dirname, '..') });
  assert.strictEqual(config.cdpUrl, 'http://127.0.0.1:9333');
  assert.deepStrictEqual(config.targetUrlContains, ['advisorpro.allstate.com', 'example.internal']);
  assert.deepStrictEqual(config.ops, ['advisor_state_snapshot', 'scan_current_page']);
  assert.strictEqual(config.timeoutMs, 1500);

  const aliasConfig = sidecar.parseArgv([
    '--target-url-token=advisor.example',
    '--op=advisor_state_snapshot'
  ], { env: {} });
  assert.deepStrictEqual(aliasConfig.targetUrlContains, ['advisor.example']);

  assert.throws(
    () => sidecar.parseArgv(['--op=advisor_state_snapshot,click_by_id'], { env: {} }),
    /Refusing non-read-only Advisor op/
  );
  assert.throws(
    () => sidecar.assertOutputPathSafe(path.resolve(__dirname, '..', 'docs', 'raw_scan.json')),
    /outside logs/
  );
  sidecar.assertOutputPathSafe(path.resolve(__dirname, '..', 'logs', 'playwright_advisor_scan_latest.json'));
}

function testOutputParsingAndSummaries() {
  const stateParsed = sidecar.parseOpOutput('advisor_state_snapshot', JSON.stringify({
    route: 'RAPPORT',
    confidence: 0.88,
    blockers: [],
    allowedNextActions: ['inspect_rapport'],
    unsafeReason: null
  }));
  assert.strictEqual(stateParsed.type, 'json');
  assert.deepStrictEqual(sidecar.summarizeOpResult('advisor_state_snapshot', stateParsed), {
    route: 'RAPPORT',
    confidence: 0.88,
    blockerCount: 0,
    allowedNextActionCount: 1,
    unsafe: '0'
  });

  const kvParsed = sidecar.parseOpOutput('gather_rapport_snapshot', 'result=OK\nrouteFamily=INTEL_102_RAPPORT\nblockerCode=\n');
  assert.strictEqual(kvParsed.type, 'keyValue');
  assert.strictEqual(kvParsed.value.result, 'OK');
  assert.strictEqual(sidecar.summarizeOpResult('gather_rapport_snapshot', kvParsed).routeFamily, 'INTEL_102_RAPPORT');

  const scanParsed = sidecar.parseOpOutput('scan_current_page', JSON.stringify({
    url: 'https://advisorpro.allstate.com/#/apps/intel/102/rapport',
    heading: 'Gather Data',
    fields: [{ id: 'field' }],
    buttons: [{ id: 'button' }],
    alerts: []
  }));
  assert.strictEqual(sidecar.summarizeOpResult('scan_current_page', scanParsed).fieldCount, 1);
}

async function run() {
  testReadOnlyAllowlist();
  testPayloadRenderingRefusesMutations();
  testDirectCdpFallbackSelection();
  testAdvisorArgsMirrorSnapshotContract();
  testActualRuntimeRendersReadOnlyOps();
  testDirectCdpRequestsAreReadOnlyRuntimeEvaluateOnly();
  testDirectCdpMethodGuard();
  await testDirectCdpScanUsesTargetListAndRuntimeEvaluateOnly();
  testArgParsingAndOutputGuard();
  testOutputParsingAndSummaries();
  process.stdout.write('playwright_scan_sidecar_contract_tests: PASS\n');
}

run().catch((error) => {
  process.stderr.write(String(error && error.stack || error));
  process.exit(1);
});
