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

function run() {
  testReadOnlyAllowlist();
  testPayloadRenderingRefusesMutations();
  testAdvisorArgsMirrorSnapshotContract();
  testActualRuntimeRendersReadOnlyOps();
  testArgParsingAndOutputGuard();
  testOutputParsingAndSummaries();
  process.stdout.write('playwright_scan_sidecar_contract_tests: PASS\n');
}

run();
