#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const OPERATOR_RUNTIME_PATH = path.join(REPO_ROOT, 'assets', 'js', 'advisor_quote', 'ops_result.js');
const DEFAULT_OUTPUT_PATH = path.join(REPO_ROOT, 'logs', 'playwright_advisor_scan_latest.json');
const DEFAULT_ARCHIVE_DIR = path.join(REPO_ROOT, 'logs', 'playwright_advisor_scans');
const TOOL_NAME = 'playwright_advisor_scan_sidecar';
const DIRECT_CDP_METHODS = Object.freeze([
  'Runtime.evaluate'
]);
const FORBIDDEN_CDP_METHOD_PATTERNS = Object.freeze([
  /^Page\.navigate$/,
  /^Input\./,
  /^Page\.captureScreenshot$/,
  /^Page\.startScreencast$/,
  /^Runtime\.callFunctionOn$/
]);

const READ_ONLY_OPS = Object.freeze([
  'advisor_state_snapshot',
  'advisor_active_modal_status',
  'gather_rapport_snapshot',
  'asc_drivers_vehicles_snapshot',
  'scan_current_page'
]);

const DEFAULT_BUNDLE_OPS = Object.freeze([
  'advisor_state_snapshot',
  'advisor_active_modal_status',
  'gather_rapport_snapshot',
  'asc_drivers_vehicles_snapshot',
  'scan_current_page'
]);

const DEFAULT_ADVISOR_ARGS = Object.freeze({
  selectors: Object.freeze({
    advisorQuotingButtonId: 'group2_Quoting_button',
    searchCreateNewProspectId: 'outOfLocationCreateNewProspectButton',
    beginQuotingContinueId: 'PrimaryApplicant-Continue-button',
    prospectFirstNameId: 'ConsumerData.People[0].Name.GivenName',
    prospectLastNameId: 'ConsumerData.People[0].Name.Surname',
    prospectDobId: 'ConsumerData.People[0].Personal.BirthDt',
    prospectGenderId: 'ConsumerData.People[0].Personal.GenderCd.SrcCd',
    prospectAddressId: 'ConsumerData.Assets.Properties[0].Addr.Addr1',
    prospectCityId: 'ConsumerData.Assets.Properties[0].Addr.City',
    prospectStateId: 'ConsumerData.Assets.Properties[0].Addr.StateProvCd.SrcCd',
    prospectZipId: 'ConsumerData.Assets.Properties[0].Addr.PostalCode',
    prospectPhoneId: 'ConsumerData.People[0].Communications.PhoneNumber',
    sidebarAddProductId: 'addProduct',
    quoteBlockAddProductId: 'quotesButton',
    createQuotesButtonId: 'consentModalTrigger',
    selectProductRatingStateId: 'SelectProduct.RatingState',
    selectProductProductId: 'SelectProduct.Product',
    selectProductContinueId: 'selectProductContinue',
    consumerReportsConsentYesId: 'orderReportsConsent-yes-btn',
    driverVehicleContinueId: 'profile-summary-submitBtn',
    participantSaveId: 'PARTICIPANT_SAVE-btn',
    removeParticipantSaveId: 'REMOVE_PARTICIPANT_SAVE-btn',
    addAssetSaveId: 'ADD_ASSET_SAVE-btn',
    confirmVehicleId: 'confirmNewVehicle',
    incidentContinueId: 'CONTINUE_OFFER-btn',
    incidentBackId: 'BACK_TO_PROFILE_SUMMARY-btn'
  }),
  urls: Object.freeze({
    rapportContains: '/rapport',
    customerSummaryContains: '/apps/customer-summary/',
    productOverviewContains: '/apps/intel/102/overview',
    selectProductContains: '/selectProduct',
    ascProductContains: '/ASCPRODUCT/'
  }),
  texts: Object.freeze({
    duplicateHeading: 'This Prospect May Already Exist',
    customerSummaryStartHereText: 'START HERE (Pre-fill included)',
    customerSummaryQuoteHistoryText: 'Quote History',
    customerSummaryAssetsDetailsText: 'Assets Details',
    productOverviewHeading: 'Select Product',
    productOverviewAutoTile: 'Auto',
    productOverviewContinueText: 'Save & Continue to Gather Data',
    selectProductCurrentInsuredQuestion: 'Is the customer currently insured?',
    selectProductAnswerYesText: 'Yes',
    driversVehiclesHeading: 'Drivers and vehicles',
    incidentsHeading: 'Incidents',
    consumerReportsHeading: 'order consumer reports',
    marriedLabel: 'Married',
    spouseSelectId: 'maritalStatusWithSpouse_spouseName'
  })
});

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function splitList(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function readOption(argv, index) {
  const token = argv[index];
  const equalIndex = token.indexOf('=');
  if (equalIndex >= 0) {
    return { value: token.slice(equalIndex + 1), nextIndex: index };
  }
  if (index + 1 >= argv.length || argv[index + 1].startsWith('--')) {
    throw new Error(`Missing value for ${token}`);
  }
  return { value: argv[index + 1], nextIndex: index + 1 };
}

function sanitizeFilenameToken(value, fallback = 'scan') {
  const cleaned = String(value || '')
    .trim()
    .replace(/https?:\/+[^ ]+/gi, '')
    .replace(/[\\/:"*?<>|#%{}[\]^`~&=+@!$,;]+/g, '_')
    .replace(/[^A-Za-z0-9_.-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^[_ .-]+|[_ .-]+$/g, '')
    .slice(0, 80);
  return cleaned || fallback;
}

function makeTimestampRunId(date = new Date()) {
  const pad = (value, width = 2) => String(value).padStart(width, '0');
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
    '_',
    pad(date.getHours()),
    pad(date.getMinutes()),
    pad(date.getSeconds()),
    '_',
    pad(date.getMilliseconds(), 3)
  ].join('');
}

function parseArgv(argv, options = {}) {
  const env = options.env || process.env;
  const cwd = options.cwd || REPO_ROOT;
  const config = {
    cdpUrl: env.PLAYWRIGHT_CDP_URL || 'http://127.0.0.1:9222',
    targetUrlContains: ['advisorpro.allstate.com'],
    ops: [],
    outputPath: DEFAULT_OUTPUT_PATH,
    archiveDir: DEFAULT_ARCHIVE_DIR,
    runId: '',
    label: 'PLAYWRIGHT_SIDECAR_SCAN',
    reason: 'scan-only-foundation',
    timeoutMs: 5000,
    cdpEvalTimeoutMs: 30000,
    pageIndex: null,
    noWrite: false,
    stdout: false,
    allowNonAdvisor: false,
    allowOutputOutsideLogs: false,
    listOps: false,
    help: false,
    cwd
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--help' || token === '-h') {
      config.help = true;
      continue;
    }
    if (token === '--list-ops') {
      config.listOps = true;
      continue;
    }
    if (token === '--no-write') {
      config.noWrite = true;
      config.stdout = true;
      continue;
    }
    if (token === '--stdout') {
      config.stdout = true;
      continue;
    }
    if (token === '--allow-non-advisor') {
      config.allowNonAdvisor = true;
      continue;
    }
    if (token === '--allow-output-outside-logs') {
      config.allowOutputOutsideLogs = true;
      continue;
    }
    if (token.startsWith('--cdp-url')) {
      const option = readOption(argv, i);
      config.cdpUrl = option.value;
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--target-url-contains')) {
      const option = readOption(argv, i);
      config.targetUrlContains = splitList(option.value);
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--target-url-token')) {
      const option = readOption(argv, i);
      config.targetUrlContains = splitList(option.value);
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--op')) {
      const option = readOption(argv, i);
      config.ops.push(...splitList(option.value));
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--output')) {
      const option = readOption(argv, i);
      config.outputPath = option.value;
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--archive-dir')) {
      const option = readOption(argv, i);
      config.archiveDir = option.value;
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--run-id')) {
      const option = readOption(argv, i);
      config.runId = sanitizeFilenameToken(option.value, 'run');
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--label')) {
      const option = readOption(argv, i);
      config.label = option.value;
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--reason')) {
      const option = readOption(argv, i);
      config.reason = option.value;
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--timeout-ms')) {
      const option = readOption(argv, i);
      config.timeoutMs = Number(option.value);
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--cdp-eval-timeout-ms')) {
      const option = readOption(argv, i);
      config.cdpEvalTimeoutMs = Number(option.value);
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--page-index')) {
      const option = readOption(argv, i);
      config.pageIndex = Number(option.value);
      i = option.nextIndex;
      continue;
    }
    throw new Error(`Unknown argument: ${token}`);
  }

  if (!Number.isFinite(config.timeoutMs) || config.timeoutMs < 250) {
    throw new Error('--timeout-ms must be a number >= 250');
  }
  if (!Number.isFinite(config.cdpEvalTimeoutMs) || config.cdpEvalTimeoutMs < 250) {
    throw new Error('--cdp-eval-timeout-ms must be a number >= 250');
  }
  if (config.pageIndex != null && (!Number.isInteger(config.pageIndex) || config.pageIndex < 0)) {
    throw new Error('--page-index must be a non-negative integer');
  }
  config.ops = normalizeOps(config.ops.length ? config.ops : DEFAULT_BUNDLE_OPS);
  return config;
}

function normalizeOps(ops) {
  const normalized = [];
  for (const op of ops) {
    const name = String(op || '').trim();
    if (!name) continue;
    if (!normalized.includes(name)) normalized.push(name);
  }
  assertReadOnlyOps(normalized);
  return normalized;
}

function assertReadOnlyOps(ops) {
  const denied = ops.filter((op) => !READ_ONLY_OPS.includes(op));
  if (denied.length) {
    throw new Error(`Refusing non-read-only Advisor op(s): ${denied.join(', ')}`);
  }
}

function loadOperatorRuntime(runtimePath = OPERATOR_RUNTIME_PATH) {
  const text = fs.readFileSync(runtimePath, 'utf8');
  for (const marker of ['@@OP@@', '@@ARGS@@', 'copy(String(']) {
    if (!text.includes(marker)) {
      throw new Error(`Advisor runtime is missing marker: ${marker}`);
    }
  }
  return text;
}

function buildArgsForOp(op, config = {}) {
  const args = deepClone(DEFAULT_ADVISOR_ARGS);
  if (op === 'scan_current_page') {
    args.label = config.label || 'PLAYWRIGHT_SIDECAR_SCAN';
    args.reason = config.reason || 'scan-only-foundation';
  }
  if (op === 'advisor_state_snapshot') {
    args.source = 'playwright-sidecar';
  }
  return args;
}

function renderOperatorPayload(runtimeText, op, args = {}) {
  assertReadOnlyOps([op]);
  if (!runtimeText.includes('@@OP@@') || !runtimeText.includes('@@ARGS@@')) {
    throw new Error('Advisor runtime template markers were not found');
  }
  return runtimeText
    .replace('@@OP@@', JSON.stringify(op))
    .replace('@@ARGS@@', JSON.stringify(args));
}

function buildDirectCdpEvaluateExpression(runtimeText, op, args = {}) {
  const payload = renderOperatorPayload(runtimeText, op, args);
  return [
    '(() => {',
    "  let copied = '';",
    '  const copy = (value) => { copied = String(value ?? \'\'); return copied; };',
    '  try {',
    `    const returned = Function('copy', ${JSON.stringify(payload)})(copy);`,
    "    return copied || String(returned ?? '');",
    '  } catch (error) {',
    "    const clean = (value, max = 320) => String(value ?? '').replace(/\\r?\\n+/g, ' ').replace(/\\s+/g, ' ').trim().slice(0, max);",
    "    return ['result=ERROR', 'op=' + clean(" + JSON.stringify(op) + ", 80), 'message=' + clean((error && error.message) || error, 280), 'url=' + clean((globalThis.location && location.href) || '', 240)].join('\\n');",
    '  }',
    '})()'
  ].join('\n');
}

function assertCdpMethodAllowed(method) {
  const name = String(method || '');
  if (!DIRECT_CDP_METHODS.includes(name)) {
    throw new Error(`Refusing unsupported CDP method: ${name}`);
  }
  if (FORBIDDEN_CDP_METHOD_PATTERNS.some((pattern) => pattern.test(name))) {
    throw new Error(`Refusing forbidden CDP method: ${name}`);
  }
}

function buildDirectCdpEvaluationRequests(runtimeText, ops, config = {}) {
  assertReadOnlyOps(ops);
  return ops.map((op) => {
    const args = buildArgsForOp(op, config);
    const expression = buildDirectCdpEvaluateExpression(runtimeText, op, args);
    const request = {
      op,
      method: 'Runtime.evaluate',
      params: {
        expression,
        awaitPromise: true,
        returnByValue: true,
        userGesture: false
      }
    };
    assertCdpMethodAllowed(request.method);
    return request;
  });
}

function buildDirectCdpPreflightRequest() {
  const expression = [
    'JSON.stringify({',
    '  href: String(location.href || \'\'),',
    '  title: String(document.title || \'\'),',
    '  readyState: String(document.readyState || \'\')',
    '})'
  ].join('\n');
  const request = {
    op: '__preflight__',
    method: 'Runtime.evaluate',
    params: {
      expression,
      awaitPromise: true,
      returnByValue: true,
      userGesture: false
    }
  };
  assertCdpMethodAllowed(request.method);
  return request;
}

function parseKeyValueLines(raw) {
  const parsed = {};
  for (const line of String(raw || '').replace(/\r/g, '').split('\n')) {
    if (!line.trim()) continue;
    const index = line.indexOf('=');
    if (index < 0) continue;
    const key = line.slice(0, index).trim();
    if (!key) continue;
    parsed[key] = line.slice(index + 1).trim();
  }
  return parsed;
}

function parseOpOutput(op, raw) {
  const text = String(raw || '').trim();
  if (!text) return { type: 'empty', value: null };
  if (op === 'advisor_state_snapshot' || op === 'scan_current_page') {
    try {
      return { type: 'json', value: JSON.parse(text) };
    } catch (error) {
      return { type: 'text', value: text, parseError: String(error && error.message || error) };
    }
  }
  return { type: 'keyValue', value: parseKeyValueLines(text) };
}

function summarizeOpResult(op, parsed) {
  if (!parsed || parsed.type === 'empty') return { result: 'EMPTY' };
  const value = parsed.value || {};
  if (op === 'advisor_state_snapshot' && parsed.type === 'json') {
    return {
      route: value.route || '',
      confidence: value.confidence ?? '',
      blockerCount: Array.isArray(value.blockers) ? value.blockers.length : 0,
      allowedNextActionCount: Array.isArray(value.allowedNextActions) ? value.allowedNextActions.length : 0,
      unsafe: value.unsafeReason ? '1' : '0'
    };
  }
  if (op === 'scan_current_page' && parsed.type === 'json') {
    return {
      url: value.url || '',
      heading: value.heading || '',
      fieldCount: Array.isArray(value.fields) ? value.fields.length : 0,
      buttonCount: Array.isArray(value.buttons) ? value.buttons.length : 0,
      alertCount: Array.isArray(value.alerts) ? value.alerts.length : 0
    };
  }
  if (parsed.type === 'keyValue') {
    return {
      result: value.result || '',
      routeFamily: value.routeFamily || '',
      activeModalType: value.activeModalType || '',
      activePanelType: value.activePanelType || '',
      blockerCode: value.blockerCode || '',
      nextRecommendedAction: value.nextRecommendedAction || '',
      nextRecommendedReadOnlyStatus: value.nextRecommendedReadOnlyStatus || ''
    };
  }
  return { result: 'UNPARSED', parseError: parsed.parseError || '' };
}

function resolveOutputPath(outputPath, cwd = REPO_ROOT) {
  return path.isAbsolute(outputPath) ? outputPath : path.resolve(cwd, outputPath);
}

function pathIsUnderLogs(outputPath, cwd = REPO_ROOT) {
  const resolved = resolveOutputPath(outputPath, cwd);
  const relative = path.relative(REPO_ROOT, resolved).replace(/\\/g, '/');
  return !(relative.startsWith('../') || relative === '..' || path.isAbsolute(relative)) && relative.startsWith('logs/');
}

function assertOutputPathSafe(outputPath, options = {}) {
  if (options.allowOutputOutsideLogs) return;
  if (!pathIsUnderLogs(outputPath, options.cwd || REPO_ROOT)) {
    throw new Error('Refusing to write scan output outside logs/. Use --allow-output-outside-logs only for sanitized artifacts.');
  }
}

function assertArchiveDirSafe(archiveDir, options = {}) {
  if (!pathIsUnderLogs(archiveDir, options.cwd || REPO_ROOT)) {
    throw new Error('Refusing to write scan archive outside logs/.');
  }
}

function writeJsonFile(outputPath, payload) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
}

function readJsonFileIfPresent(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    if (error && error.code === 'ENOENT') return fallback;
    return fallback;
  }
}

function routeFromResult(result) {
  if (!result || typeof result !== 'object') return 'UNKNOWN';
  const summary = result.summary || {};
  if (summary.route) return String(summary.route);
  if (summary.routeFamily) return String(summary.routeFamily);
  const parsed = result.parsed || {};
  const value = parsed.value || {};
  if (value.route) return String(value.route);
  if (value.routeFamily) return String(value.routeFamily);
  if (value.result) return String(value.result);
  return 'UNKNOWN';
}

function confidenceFromResult(result) {
  if (!result || typeof result !== 'object') return '';
  const summary = result.summary || {};
  if (summary.confidence !== undefined && summary.confidence !== null) return summary.confidence;
  const value = (result.parsed && result.parsed.value) || {};
  return value.confidence !== undefined && value.confidence !== null ? value.confidence : '';
}

function unsafeFromResult(result) {
  if (!result || typeof result !== 'object') return '';
  const summary = result.summary || {};
  if (summary.unsafe !== undefined && summary.unsafe !== null) return summary.unsafe;
  const value = (result.parsed && result.parsed.value) || {};
  if (value.unsafeReason !== undefined && value.unsafeReason !== null) return value.unsafeReason ? '1' : '0';
  return '';
}

function archiveFilename(sequence, result, config = {}) {
  const routeToken = sanitizeFilenameToken(routeFromResult(result).toUpperCase(), 'UNKNOWN').toUpperCase();
  const opToken = sanitizeFilenameToken(result && result.op ? result.op : 'op', 'op');
  const parts = [String(sequence).padStart(3, '0'), routeToken];
  parts.push(opToken);
  return `${parts.join('_')}.json`;
}

function buildInitialRunSummary(runId, createdAt) {
  return {
    schemaVersion: 'advisor-playwright-scan-run-summary/v1',
    runId,
    createdAt,
    updatedAt: createdAt,
    scanCount: 0,
    lastTarget: null,
    lastRoute: '',
    lastConfidence: '',
    lastUnsafe: '',
    countsByRoute: {},
    scanFiles: []
  };
}

function writeScanArchive(envelope, config) {
  const runId = sanitizeFilenameToken(config.runId || makeTimestampRunId(), 'run');
  const archiveDir = resolveOutputPath(config.archiveDir || DEFAULT_ARCHIVE_DIR, config.cwd);
  assertArchiveDirSafe(archiveDir, config);
  const runDir = path.join(archiveDir, 'runs', runId);
  const summaryPath = path.join(runDir, 'run_summary.json');
  const summary = readJsonFileIfPresent(summaryPath, buildInitialRunSummary(runId, envelope.capturedAt || new Date().toISOString()));
  if (!summary.schemaVersion) summary.schemaVersion = 'advisor-playwright-scan-run-summary/v1';
  if (!summary.runId) summary.runId = runId;
  if (!summary.createdAt) summary.createdAt = envelope.capturedAt || new Date().toISOString();
  summary.updatedAt = new Date().toISOString();
  if (!summary.countsByRoute || typeof summary.countsByRoute !== 'object') summary.countsByRoute = {};
  if (!Array.isArray(summary.scanFiles)) summary.scanFiles = [];

  const written = [];
  let sequence = Number(summary.scanCount || 0);
  for (const result of envelope.results || []) {
    sequence += 1;
    const filename = archiveFilename(sequence, result, config);
    const filePath = path.join(runDir, filename);
    const route = routeFromResult(result);
    const payload = {
      schemaVersion: 'advisor-playwright-scan-archive-entry/v1',
      runId,
      sequence,
      archivedAt: new Date().toISOString(),
      tool: envelope.tool,
      connection: envelope.connection,
      target: envelope.target,
      preflight: envelope.preflight || null,
      label: config.label || '',
      op: result.op,
      route,
      result
    };
    writeJsonFile(filePath, payload);
    const relative = path.relative(REPO_ROOT, filePath).replace(/\\/g, '/');
    written.push(relative);
    summary.scanFiles.push(relative);
    summary.countsByRoute[route] = Number(summary.countsByRoute[route] || 0) + 1;
    summary.lastRoute = route;
    summary.lastConfidence = confidenceFromResult(result);
    summary.lastUnsafe = unsafeFromResult(result);
  }

  summary.scanCount = Number(summary.scanCount || 0) + written.length;
  summary.lastTarget = envelope.target || null;
  writeJsonFile(summaryPath, summary);
  return {
    runId,
    runDir: path.relative(REPO_ROOT, runDir).replace(/\\/g, '/'),
    summaryPath: path.relative(REPO_ROOT, summaryPath).replace(/\\/g, '/'),
    scanFiles: written
  };
}

function loadPlaywright(options = {}) {
  const requireFn = options.requireFn || require;
  for (const packageName of ['playwright', 'playwright-core']) {
    try {
      return requireFn(packageName);
    } catch (error) {
      if (!error || error.code !== 'MODULE_NOT_FOUND') throw error;
    }
  }
  return null;
}

function selectScanBackend(playwright) {
  return playwright ? 'playwright-cdp' : 'direct-cdp';
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function withTimeout(promise, timeoutMs, label) {
  let timer = null;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function urlMatches(url, containsList) {
  const lowerUrl = String(url || '').toLowerCase();
  return containsList.some((needle) => lowerUrl.includes(String(needle || '').toLowerCase()));
}

async function selectTargetPage(browser, config) {
  const deadline = Date.now() + config.timeoutMs;
  while (Date.now() <= deadline) {
    const pages = browser.contexts().flatMap((context) => context.pages()).filter((page) => !page.isClosed());
    if (config.pageIndex != null) {
      if (pages[config.pageIndex]) return pages[config.pageIndex];
    } else {
      const match = pages.find((page) => urlMatches(page.url(), config.targetUrlContains));
      if (match) return match;
    }
    await delay(200);
  }
  throw new Error(`No matching browser page found for target URL token(s): ${config.targetUrlContains.join(', ')}`);
}

async function evaluateReadOnlyPayload(page, payload, timeoutMs, op) {
  return withTimeout(page.evaluate((source) => {
    let copied = '';
    const copy = (value) => {
      copied = String(value ?? '');
      return copied;
    };
    const returned = Function('copy', source)(copy);
    return copied || String(returned ?? '');
  }, payload), timeoutMs, `Advisor op ${op}`);
}

async function runScanWithPlaywright(config, playwright) {
  assertReadOnlyOps(config.ops);
  const browser = await playwright.chromium.connectOverCDP(config.cdpUrl, { timeout: config.timeoutMs });
  try {
    const page = await selectTargetPage(browser, config);
    const targetUrl = page.url();
    if (!config.allowNonAdvisor && !urlMatches(targetUrl, config.targetUrlContains)) {
      throw new Error(`Selected page does not match allowed Advisor target token(s): ${targetUrl}`);
    }

    const runtimeText = loadOperatorRuntime();
    const startedAt = new Date().toISOString();
    const pageTitle = await withTimeout(page.title(), config.timeoutMs, 'page title read');
    const results = [];

    for (const op of config.ops) {
      const args = buildArgsForOp(op, config);
      const payload = renderOperatorPayload(runtimeText, op, args);
      const opStarted = Date.now();
      const raw = await evaluateReadOnlyPayload(page, payload, config.cdpEvalTimeoutMs, op);
      const parsed = parseOpOutput(op, raw);
      results.push({
        op,
        readOnly: true,
        ok: String(raw || '').trim() !== '',
        elapsedMs: Date.now() - opStarted,
        summary: summarizeOpResult(op, parsed),
        parsed,
        raw
      });
    }

    const envelope = {
      schemaVersion: 'advisor-playwright-scan-sidecar/v1',
      tool: TOOL_NAME,
      capturedAt: startedAt,
      readOnly: true,
      mutationAllowed: false,
      connection: {
        kind: 'playwright-cdp',
        cdpUrl: config.cdpUrl
      },
      target: {
        url: targetUrl,
        title: pageTitle
      },
      ops: config.ops,
      outputPath: config.noWrite ? '' : config.outputPath,
      results
    };

    return envelope;
  } finally {
    if (browser && typeof browser.disconnect === 'function') {
      await browser.disconnect().catch(() => {});
    }
  }
}

function normalizeCdpBaseUrl(cdpUrl) {
  const parsed = new URL(cdpUrl);
  parsed.hash = '';
  parsed.search = '';
  return parsed;
}

function cdpHttpUrl(cdpUrl, endpoint) {
  const parsed = normalizeCdpBaseUrl(cdpUrl);
  parsed.pathname = endpoint;
  return parsed.toString();
}

async function fetchJsonWithTimeout(url, timeoutMs, options = {}) {
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  if (typeof fetchImpl !== 'function') {
    throw new Error('Direct CDP fallback requires a Node runtime with built-in fetch.');
  }
  const AbortControllerImpl = options.AbortControllerImpl || globalThis.AbortController;
  const controller = typeof AbortControllerImpl === 'function' ? new AbortControllerImpl() : null;
  const timer = controller ? setTimeout(() => controller.abort(), timeoutMs) : null;
  try {
    const response = await fetchImpl(url, controller ? { signal: controller.signal } : {});
    if (!response || !response.ok) {
      const status = response ? `${response.status} ${response.statusText || ''}`.trim() : 'no response';
      throw new Error(`HTTP ${status}`);
    }
    return await response.json();
  } finally {
    if (timer) clearTimeout(timer);
  }
}

async function fetchCdpTargets(cdpUrl, timeoutMs, options = {}) {
  const errors = [];
  for (const endpoint of ['/json', '/json/list']) {
    const url = cdpHttpUrl(cdpUrl, endpoint);
    try {
      const payload = await fetchJsonWithTimeout(url, timeoutMs, options);
      if (Array.isArray(payload)) return payload;
      if (payload && Array.isArray(payload.targets)) return payload.targets;
      errors.push(`${endpoint}: response was not a target array`);
    } catch (error) {
      errors.push(`${endpoint}: ${String(error && error.message || error)}`);
    }
  }
  throw new Error(`Unable to read CDP target list. ${errors.join(' | ')}`);
}

function selectCdpTarget(targets, config) {
  const pages = targets.filter((target) => {
    return target
      && target.type === 'page'
      && typeof target.webSocketDebuggerUrl === 'string'
      && target.webSocketDebuggerUrl;
  });
  if (config.pageIndex != null) {
    const target = pages[config.pageIndex];
    if (!target) throw new Error(`No CDP page target at index ${config.pageIndex}`);
    return target;
  }
  const target = pages.find((candidate) => {
    return config.allowNonAdvisor || urlMatches(candidate.url || '', config.targetUrlContains);
  });
  if (!target) {
    throw new Error(`No matching CDP page target found for token(s): ${config.targetUrlContains.join(', ')}`);
  }
  return target;
}

class DirectCdpClient {
  constructor(webSocketUrl, options = {}) {
    this.webSocketUrl = webSocketUrl;
    this.timeoutMs = options.timeoutMs || 5000;
    this.WebSocketImpl = options.WebSocketImpl || globalThis.WebSocket;
    this.nextId = 1;
    this.pending = new Map();
    this.socket = null;
  }

  connect() {
    if (typeof this.WebSocketImpl !== 'function') {
      return Promise.reject(new Error('Direct CDP fallback requires a Node runtime with built-in WebSocket.'));
    }
    return new Promise((resolve, reject) => {
      const socket = new this.WebSocketImpl(this.webSocketUrl);
      this.socket = socket;
      let opened = false;
      const timer = setTimeout(() => {
        reject(new Error(`CDP WebSocket connect timed out after ${this.timeoutMs}ms`));
        try { socket.close(); } catch {}
      }, this.timeoutMs);
      const cleanup = () => {
        clearTimeout(timer);
        socket.removeEventListener && socket.removeEventListener('open', onOpen);
        socket.removeEventListener && socket.removeEventListener('error', onError);
      };
      const onOpen = () => {
        opened = true;
        cleanup();
        resolve(this);
      };
      const onError = (event) => {
        if (!opened) {
          cleanup();
          reject(new Error(`CDP WebSocket error: ${event && event.message ? event.message : 'connect failed'}`));
        }
      };
      const onMessage = (event) => this.handleMessage(event);
      const onClose = () => this.rejectAllPending(new Error('CDP WebSocket closed'));
      this.attachSocketHandler(socket, 'open', onOpen);
      this.attachSocketHandler(socket, 'error', onError);
      this.attachSocketHandler(socket, 'message', onMessage);
      this.attachSocketHandler(socket, 'close', onClose);
    });
  }

  attachSocketHandler(socket, eventName, handler) {
    if (socket && typeof socket.addEventListener === 'function') {
      socket.addEventListener(eventName, handler);
    }
    const propertyName = `on${eventName}`;
    const previous = socket ? socket[propertyName] : null;
    socket[propertyName] = (event) => {
      if (typeof previous === 'function') {
        try { previous.call(socket, event); } catch {}
      }
      handler(event);
    };
  }

  async messageEventText(event) {
    const raw = event && typeof event === 'object' && 'data' in event ? event.data : event;
    if (typeof raw === 'string') return raw;
    if (raw == null) return '';
    if (typeof Buffer !== 'undefined' && Buffer.isBuffer && Buffer.isBuffer(raw)) {
      return raw.toString('utf8');
    }
    if (raw instanceof ArrayBuffer) {
      return Buffer.from(raw).toString('utf8');
    }
    if (ArrayBuffer.isView(raw)) {
      return Buffer.from(raw.buffer, raw.byteOffset, raw.byteLength).toString('utf8');
    }
    if (typeof raw.text === 'function') {
      return String(await raw.text());
    }
    if (typeof raw.arrayBuffer === 'function') {
      return Buffer.from(await raw.arrayBuffer()).toString('utf8');
    }
    return String(raw || '');
  }

  async handleMessage(event) {
    let text = '';
    try {
      text = await this.messageEventText(event);
    } catch {
      return;
    }
    let message = null;
    try {
      message = JSON.parse(text);
    } catch {
      return;
    }
    if (!message || !message.id || !this.pending.has(message.id)) return;
    const pending = this.pending.get(message.id);
    this.pending.delete(message.id);
    clearTimeout(pending.timer);
    if (message.error) {
      pending.reject(new Error(`CDP ${pending.method} failed: ${message.error.message || JSON.stringify(message.error)}`));
      return;
    }
    pending.resolve(message.result || {});
  }

  send(method, params = {}, options = {}) {
    assertCdpMethodAllowed(method);
    const openState = this.WebSocketImpl.OPEN ?? (this.socket && this.socket.OPEN) ?? 1;
    if (!this.socket || this.socket.readyState !== openState) {
      return Promise.reject(new Error('CDP WebSocket is not open.'));
    }
    const id = this.nextId++;
    const payload = JSON.stringify({ id, method, params });
    const timeoutMs = options.timeoutMs || this.timeoutMs;
    const timeoutLabel = options.timeoutLabel || `CDP ${method}`;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${timeoutLabel} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer, method });
      this.socket.send(payload);
    });
  }

  rejectAllPending(error) {
    for (const [id, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(error);
      this.pending.delete(id);
    }
  }

  close() {
    this.rejectAllPending(new Error('CDP client closed'));
    if (this.socket) {
      try { this.socket.close(); } catch {}
    }
  }
}

function readRuntimeEvaluateResult(response) {
  if (response.exceptionDetails) {
    const details = response.exceptionDetails;
    const message = details.text || (details.exception && details.exception.description) || 'Runtime.evaluate exception';
    throw new Error(message);
  }
  const result = response.result || {};
  if (Object.prototype.hasOwnProperty.call(result, 'value')) return String(result.value ?? '');
  if (Object.prototype.hasOwnProperty.call(result, 'unserializableValue')) return String(result.unserializableValue ?? '');
  if (result.description) return String(result.description);
  return '';
}

function parsePreflightValue(raw) {
  try {
    const parsed = JSON.parse(String(raw || ''));
    return {
      href: String(parsed.href || ''),
      title: String(parsed.title || ''),
      readyState: String(parsed.readyState || '')
    };
  } catch {
    return {
      href: '',
      title: '',
      readyState: '',
      raw: String(raw || '')
    };
  }
}

function buildDirectCdpTimeoutError(op, targetUrl, targetTitle, timeoutMs) {
  return new Error(
    `CDP Runtime.evaluate timed out for op=${op}; selectedTargetUrl=${targetUrl}; selectedTargetTitle=${targetTitle}; timeoutMs=${timeoutMs}. `
      + 'Preflight succeeded, so retry with a higher --cdp-eval-timeout-ms value.'
  );
}

async function runScanWithDirectCdp(config, options = {}) {
  assertReadOnlyOps(config.ops);
  const targets = await fetchCdpTargets(config.cdpUrl, config.timeoutMs, options);
  const target = selectCdpTarget(targets, config);
  const targetUrl = target.url || '';
  if (!config.allowNonAdvisor && !urlMatches(targetUrl, config.targetUrlContains)) {
    throw new Error(`Selected CDP target does not match allowed Advisor target token(s): ${targetUrl}`);
  }

  const runtimeText = options.runtimeText || loadOperatorRuntime();
  const requests = buildDirectCdpEvaluationRequests(runtimeText, config.ops, config);
  const client = options.client || new DirectCdpClient(target.webSocketDebuggerUrl, {
    timeoutMs: config.timeoutMs,
    WebSocketImpl: options.WebSocketImpl
  });
  if (!options.client) await client.connect();

  try {
    const startedAt = new Date().toISOString();
    const preflightRequest = buildDirectCdpPreflightRequest();
    let preflight = {};
    try {
      const preflightResponse = await client.send(preflightRequest.method, preflightRequest.params, {
        timeoutMs: config.cdpEvalTimeoutMs,
        timeoutLabel: 'CDP Runtime.evaluate preflight'
      });
      preflight = parsePreflightValue(readRuntimeEvaluateResult(preflightResponse));
    } catch (error) {
      throw new Error(
        `Direct CDP preflight failed for selectedTargetUrl=${targetUrl}; selectedTargetTitle=${target.title || ''}; `
          + `timeoutMs=${config.cdpEvalTimeoutMs}; reason=${String(error && error.message || error)}`
      );
    }

    const results = [];
    for (const request of requests) {
      const opStarted = Date.now();
      let response;
      try {
        response = await client.send(request.method, request.params, {
          timeoutMs: config.cdpEvalTimeoutMs,
          timeoutLabel: `CDP Runtime.evaluate op=${request.op}`
        });
        const raw = readRuntimeEvaluateResult(response);
        const parsed = parseOpOutput(request.op, raw);
        results.push({
          op: request.op,
          readOnly: true,
          ok: String(raw || '').trim() !== '',
          elapsedMs: Date.now() - opStarted,
          summary: summarizeOpResult(request.op, parsed),
          parsed,
          raw
        });
      } catch (error) {
        const message = String(error && error.message || error);
        if (message.includes('timed out')) {
          throw buildDirectCdpTimeoutError(request.op, targetUrl, target.title || '', config.cdpEvalTimeoutMs);
        }
        throw new Error(
          `Direct CDP Runtime.evaluate failed for op=${request.op}; selectedTargetUrl=${targetUrl}; `
            + `selectedTargetTitle=${target.title || ''}; reason=${message}`
        );
      }
    }

    return {
      schemaVersion: 'advisor-playwright-scan-sidecar/v1',
      tool: TOOL_NAME,
      capturedAt: startedAt,
      readOnly: true,
      mutationAllowed: false,
      connection: {
        kind: 'direct-cdp',
        cdpUrl: config.cdpUrl
      },
      target: {
        url: targetUrl,
        title: target.title || ''
      },
      preflight,
      ops: config.ops,
      outputPath: config.noWrite ? '' : config.outputPath,
      results
    };
  } finally {
    if (!options.client) client.close();
  }
}

async function runScan(config, options = {}) {
  assertReadOnlyOps(config.ops);
  if (!config.noWrite) {
    const resolved = resolveOutputPath(config.outputPath, config.cwd);
    assertOutputPathSafe(resolved, config);
    config.outputPath = resolved;
    config.archiveDir = resolveOutputPath(config.archiveDir || DEFAULT_ARCHIVE_DIR, config.cwd);
    assertArchiveDirSafe(config.archiveDir, config);
    config.runId = sanitizeFilenameToken(config.runId || makeTimestampRunId(), 'run');
  }

  const playwright = Object.prototype.hasOwnProperty.call(options, 'playwright')
    ? options.playwright
    : loadPlaywright(options);
  const backend = selectScanBackend(playwright);
  const envelope = backend === 'playwright-cdp'
    ? await runScanWithPlaywright(config, playwright)
    : await runScanWithDirectCdp(config, options);
  if (!config.noWrite) {
    envelope.archive = writeScanArchive(envelope, config);
    writeJsonFile(config.outputPath, envelope);
  }
  return envelope;
}

function formatHelp() {
  return [
    'Usage:',
    '  node tools/playwright_advisor_scan_sidecar.js --cdp-url http://127.0.0.1:9222',
    '',
    'Defaults:',
    '  target URL token: advisorpro.allstate.com',
    '  output: logs/playwright_advisor_scan_latest.json',
    '  archive: logs/playwright_advisor_scans/runs/<runId>/',
    '  ops: advisor_state_snapshot, advisor_active_modal_status, gather_rapport_snapshot, asc_drivers_vehicles_snapshot, scan_current_page',
    '  direct CDP evaluation timeout: 30000ms (override with --cdp-eval-timeout-ms)',
    '  generated run id: timestamp unless --run-id is supplied',
    '',
    'Archive controls:',
    '  --run-id <id>          stable run folder name for repeated manual validation scans',
    '  --label <text>        human-readable scan metadata; not used in filenames',
    '  --archive-dir <path>  archive root; must stay under logs/',
    '  --no-write            print the scan envelope to stdout and skip latest/archive writes',
    '',
    'Safety:',
    '  The CLI refuses any op not in its read-only allowlist.',
    '  It connects to an existing browser over CDP and does not launch, navigate, click, type, screenshot, or focus pages.',
    '  If playwright/playwright-core is unavailable, it uses direct CDP /json target discovery plus Runtime.evaluate.',
    '  Scan output is refused outside logs/ unless --allow-output-outside-logs is passed for sanitized artifacts.'
  ].join('\n');
}

async function main() {
  const config = parseArgv(process.argv.slice(2));
  if (config.help) {
    process.stdout.write(`${formatHelp()}\n`);
    return;
  }
  if (config.listOps) {
    process.stdout.write(`${READ_ONLY_OPS.join('\n')}\n`);
    return;
  }

  const envelope = await runScan(config);
  if (config.stdout) {
    process.stdout.write(`${JSON.stringify(envelope, null, 2)}\n`);
    return;
  }

  const summaries = envelope.results.map((result) => `${result.op}:${JSON.stringify(result.summary)}`).join(' ');
  process.stdout.write(`${TOOL_NAME}: OK\n`);
  process.stdout.write(`output=${envelope.outputPath}\n`);
  if (envelope.archive) {
    process.stdout.write(`archiveRunId=${envelope.archive.runId}\n`);
    process.stdout.write(`archiveSummary=${envelope.archive.summaryPath}\n`);
    process.stdout.write(`archiveFiles=${envelope.archive.scanFiles.join(',')}\n`);
  }
  process.stdout.write(`target=${envelope.target.url}\n`);
  process.stdout.write(`summary=${summaries}\n`);
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`${TOOL_NAME}: FAILED\n`);
    process.stderr.write(`${String(error && error.stack || error)}\n`);
    process.exit(1);
  });
}

module.exports = {
  READ_ONLY_OPS,
  DIRECT_CDP_METHODS,
  DEFAULT_BUNDLE_OPS,
  DEFAULT_ADVISOR_ARGS,
  OPERATOR_RUNTIME_PATH,
  DEFAULT_OUTPUT_PATH,
  DEFAULT_ARCHIVE_DIR,
  DirectCdpClient,
  assertCdpMethodAllowed,
  assertArchiveDirSafe,
  assertOutputPathSafe,
  assertReadOnlyOps,
  archiveFilename,
  buildDirectCdpEvaluateExpression,
  buildDirectCdpEvaluationRequests,
  buildDirectCdpPreflightRequest,
  buildArgsForOp,
  confidenceFromResult,
  cdpHttpUrl,
  fetchCdpTargets,
  formatHelp,
  loadOperatorRuntime,
  loadPlaywright,
  makeTimestampRunId,
  normalizeOps,
  parseArgv,
  parseKeyValueLines,
  parseOpOutput,
  readRuntimeEvaluateResult,
  renderOperatorPayload,
  resolveOutputPath,
  routeFromResult,
  runScan,
  runScanWithDirectCdp,
  runScanWithPlaywright,
  sanitizeFilenameToken,
  selectCdpTarget,
  selectScanBackend,
  summarizeOpResult,
  unsafeFromResult,
  writeScanArchive,
  urlMatches
};
