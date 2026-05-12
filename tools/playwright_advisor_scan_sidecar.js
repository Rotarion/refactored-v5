#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const OPERATOR_RUNTIME_PATH = path.join(REPO_ROOT, 'assets', 'js', 'advisor_quote', 'ops_result.js');
const DEFAULT_OUTPUT_PATH = path.join(REPO_ROOT, 'logs', 'playwright_advisor_scan_latest.json');
const TOOL_NAME = 'playwright_advisor_scan_sidecar';

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

function parseArgv(argv, options = {}) {
  const env = options.env || process.env;
  const cwd = options.cwd || REPO_ROOT;
  const config = {
    cdpUrl: env.PLAYWRIGHT_CDP_URL || 'http://127.0.0.1:9222',
    targetUrlContains: ['advisorpro.allstate.com'],
    ops: [],
    outputPath: DEFAULT_OUTPUT_PATH,
    label: 'PLAYWRIGHT_SIDECAR_SCAN',
    reason: 'scan-only-foundation',
    timeoutMs: 5000,
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

function assertOutputPathSafe(outputPath, options = {}) {
  if (options.allowOutputOutsideLogs) return;
  const resolved = resolveOutputPath(outputPath, options.cwd || REPO_ROOT);
  const relative = path.relative(REPO_ROOT, resolved).replace(/\\/g, '/');
  if (relative.startsWith('../') || relative === '..' || path.isAbsolute(relative) || !relative.startsWith('logs/')) {
    throw new Error('Refusing to write scan output outside logs/. Use --allow-output-outside-logs only for sanitized artifacts.');
  }
}

function writeJsonFile(outputPath, payload) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
}

function loadPlaywright() {
  for (const packageName of ['playwright', 'playwright-core']) {
    try {
      return require(packageName);
    } catch (error) {
      if (!error || error.code !== 'MODULE_NOT_FOUND') throw error;
    }
  }
  throw new Error('Playwright is not installed. Install playwright or playwright-core before running the live CDP sidecar.');
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

async function runScan(config) {
  assertReadOnlyOps(config.ops);
  if (!config.noWrite) {
    const resolved = resolveOutputPath(config.outputPath, config.cwd);
    assertOutputPathSafe(resolved, config);
    config.outputPath = resolved;
  }

  const playwright = loadPlaywright();
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
      const raw = await evaluateReadOnlyPayload(page, payload, config.timeoutMs, op);
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

    if (!config.noWrite) writeJsonFile(config.outputPath, envelope);
    return envelope;
  } finally {
    if (browser && typeof browser.disconnect === 'function') {
      await browser.disconnect().catch(() => {});
    }
  }
}

function formatHelp() {
  return [
    'Usage:',
    '  node tools/playwright_advisor_scan_sidecar.js --cdp-url http://127.0.0.1:9222',
    '',
    'Defaults:',
    '  target URL token: advisorpro.allstate.com',
    '  output: logs/playwright_advisor_scan_latest.json',
    '  ops: advisor_state_snapshot, advisor_active_modal_status, gather_rapport_snapshot, asc_drivers_vehicles_snapshot, scan_current_page',
    '',
    'Safety:',
    '  The CLI refuses any op not in its read-only allowlist.',
    '  It connects to an existing browser over CDP and does not launch, navigate, click, type, screenshot, or focus pages.',
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
  DEFAULT_BUNDLE_OPS,
  DEFAULT_ADVISOR_ARGS,
  OPERATOR_RUNTIME_PATH,
  DEFAULT_OUTPUT_PATH,
  assertOutputPathSafe,
  assertReadOnlyOps,
  buildArgsForOp,
  formatHelp,
  loadOperatorRuntime,
  normalizeOps,
  parseArgv,
  parseKeyValueLines,
  parseOpOutput,
  renderOperatorPayload,
  resolveOutputPath,
  summarizeOpResult,
  urlMatches
};
