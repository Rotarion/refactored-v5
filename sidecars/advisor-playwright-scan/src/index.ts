import fs from 'node:fs';
import path from 'node:path';
import { chromium, type BrowserContext, type Page } from 'playwright';

type ReadOnlyOp =
  | 'advisor_state_snapshot'
  | 'advisor_active_modal_status'
  | 'gather_rapport_snapshot'
  | 'asc_drivers_vehicles_snapshot'
  | 'scan_current_page';

type ParsedOutput =
  | { type: 'empty'; value: null }
  | { type: 'json'; value: unknown }
  | { type: 'keyValue'; value: Record<string, string> }
  | { type: 'text'; value: string; parseError?: string };

type SidecarConfig = {
  initialUrl: string;
  profileDir: string;
  outputPath: string;
  targetUrlContains: string[];
  ops: ReadOnlyOp[];
  timeoutMs: number;
  label: string;
  reason: string;
  stdout: boolean;
  noWrite: boolean;
  allowOutputOutsideLogs: boolean;
  help: boolean;
  listOps: boolean;
};

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const OPERATOR_RUNTIME_PATH = path.join(REPO_ROOT, 'assets', 'js', 'advisor_quote', 'ops_result.js');
const DEFAULT_PROFILE_DIR = path.join(REPO_ROOT, 'logs', 'playwright-edge-advisor-profile');
const DEFAULT_OUTPUT_PATH = path.join(REPO_ROOT, 'logs', 'playwright_ts_advisor_scan_latest.json');
const DEFAULT_INITIAL_URL = 'https://advisorpro.allstate.com/';
const TOOL_NAME = 'advisor-playwright-scan-sidecar';

export const READ_ONLY_OPS: readonly ReadOnlyOp[] = [
  'advisor_state_snapshot',
  'advisor_active_modal_status',
  'gather_rapport_snapshot',
  'asc_drivers_vehicles_snapshot',
  'scan_current_page'
] as const;

const DEFAULT_BUNDLE_OPS: readonly ReadOnlyOp[] = [
  'advisor_state_snapshot',
  'advisor_active_modal_status',
  'gather_rapport_snapshot',
  'asc_drivers_vehicles_snapshot',
  'scan_current_page'
] as const;

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

function readOption(argv: string[], index: number): { value: string; nextIndex: number } {
  const token = argv[index];
  const equalIndex = token.indexOf('=');
  if (equalIndex >= 0) return { value: token.slice(equalIndex + 1), nextIndex: index };
  if (index + 1 >= argv.length || argv[index + 1].startsWith('--')) {
    throw new Error(`Missing value for ${token}`);
  }
  return { value: argv[index + 1], nextIndex: index + 1 };
}

function splitList(value: string): string[] {
  return value.split(',').map((item) => item.trim()).filter(Boolean);
}

function isReadOnlyOp(value: string): value is ReadOnlyOp {
  return (READ_ONLY_OPS as readonly string[]).includes(value);
}

function assertReadOnlyOps(ops: string[]): asserts ops is ReadOnlyOp[] {
  const refused = ops.filter((op) => !isReadOnlyOp(op));
  if (refused.length) {
    throw new Error(`Refusing non-read-only Advisor op(s): ${refused.join(', ')}`);
  }
}

function normalizeOps(values: string[]): ReadOnlyOp[] {
  const unique = Array.from(new Set(values.map((value) => value.trim()).filter(Boolean)));
  assertReadOnlyOps(unique);
  return unique;
}

function parseArgv(argv: string[]): SidecarConfig {
  const config: SidecarConfig = {
    initialUrl: DEFAULT_INITIAL_URL,
    profileDir: DEFAULT_PROFILE_DIR,
    outputPath: DEFAULT_OUTPUT_PATH,
    targetUrlContains: ['advisorpro.allstate.com'],
    ops: [...DEFAULT_BUNDLE_OPS],
    timeoutMs: 60000,
    label: 'PLAYWRIGHT_TS_SIDECAR_SCAN',
    reason: 'dedicated-edge-profile-scan-only',
    stdout: false,
    noWrite: false,
    allowOutputOutsideLogs: false,
    help: false,
    listOps: false
  };

  const requestedOps: string[] = [];
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
    if (token === '--stdout') {
      config.stdout = true;
      continue;
    }
    if (token === '--no-write') {
      config.noWrite = true;
      config.stdout = true;
      continue;
    }
    if (token === '--allow-output-outside-logs') {
      config.allowOutputOutsideLogs = true;
      continue;
    }
    if (token.startsWith('--initial-url')) {
      const option = readOption(argv, i);
      config.initialUrl = option.value;
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--profile-dir')) {
      const option = readOption(argv, i);
      config.profileDir = path.resolve(REPO_ROOT, option.value);
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--output')) {
      const option = readOption(argv, i);
      config.outputPath = path.resolve(REPO_ROOT, option.value);
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
      requestedOps.push(...splitList(option.value));
      i = option.nextIndex;
      continue;
    }
    if (token.startsWith('--timeout-ms')) {
      const option = readOption(argv, i);
      config.timeoutMs = Number(option.value);
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
    throw new Error(`Unknown argument: ${token}`);
  }

  if (requestedOps.length) config.ops = normalizeOps(requestedOps);
  if (!Number.isFinite(config.timeoutMs) || config.timeoutMs < 1000) {
    throw new Error('--timeout-ms must be a number >= 1000');
  }
  return config;
}

function relativeToRepo(filePath: string): string {
  return path.relative(REPO_ROOT, filePath).replace(/\\/g, '/');
}

function assertOutputPathSafe(filePath: string, allowOutputOutsideLogs: boolean): void {
  if (allowOutputOutsideLogs) return;
  const relative = relativeToRepo(filePath);
  if (relative.startsWith('../') || relative === '..' || path.isAbsolute(relative) || !relative.startsWith('logs/')) {
    throw new Error('Refusing to write scan output outside logs/.');
  }
}

function loadOperatorRuntime(): string {
  const runtime = fs.readFileSync(OPERATOR_RUNTIME_PATH, 'utf8');
  for (const marker of ['@@OP@@', '@@ARGS@@', 'copy(String(']) {
    if (!runtime.includes(marker)) throw new Error(`Advisor operator runtime is missing marker: ${marker}`);
  }
  return runtime;
}

function buildArgsForOp(op: ReadOnlyOp, config: SidecarConfig): Record<string, unknown> {
  const args = JSON.parse(JSON.stringify(DEFAULT_ADVISOR_ARGS)) as Record<string, unknown>;
  if (op === 'advisor_state_snapshot') args.source = 'playwright-ts-sidecar';
  if (op === 'scan_current_page') {
    args.label = config.label;
    args.reason = config.reason;
  }
  return args;
}

function renderAdvisorOperatorPayload(runtime: string, op: ReadOnlyOp, args: Record<string, unknown>): string {
  assertReadOnlyOps([op]);
  return runtime
    .replace('@@OP@@', JSON.stringify(op))
    .replace('@@ARGS@@', JSON.stringify(args));
}

function parseKeyValueLines(raw: string): Record<string, string> {
  const parsed: Record<string, string> = {};
  for (const line of raw.replace(/\r/g, '').split('\n')) {
    const index = line.indexOf('=');
    if (index < 0) continue;
    const key = line.slice(0, index).trim();
    if (!key) continue;
    parsed[key] = line.slice(index + 1).trim();
  }
  return parsed;
}

function parseOutput(op: ReadOnlyOp, raw: string): ParsedOutput {
  const text = raw.trim();
  if (!text) return { type: 'empty', value: null };
  if (op === 'advisor_state_snapshot' || op === 'scan_current_page') {
    try {
      return { type: 'json', value: JSON.parse(text) };
    } catch (error) {
      return { type: 'text', value: text, parseError: String(error instanceof Error ? error.message : error) };
    }
  }
  return { type: 'keyValue', value: parseKeyValueLines(text) };
}

function urlMatches(url: string, tokens: string[]): boolean {
  const lowerUrl = url.toLowerCase();
  return tokens.some((token) => lowerUrl.includes(token.toLowerCase()));
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function launchDedicatedEdgeProfile(config: SidecarConfig): Promise<BrowserContext> {
  fs.mkdirSync(config.profileDir, { recursive: true });
  const browserArgs = config.initialUrl ? [config.initialUrl] : [];
  return chromium.launchPersistentContext(config.profileDir, {
    channel: 'msedge',
    headless: false,
    viewport: null,
    acceptDownloads: false,
    args: browserArgs
  });
}

async function waitForAdvisorPage(context: BrowserContext, config: SidecarConfig): Promise<Page> {
  const deadline = Date.now() + config.timeoutMs;
  while (Date.now() <= deadline) {
    const page = context.pages().find((candidate) => urlMatches(candidate.url(), config.targetUrlContains));
    if (page) return page;
    await delay(250);
  }
  throw new Error(`Timed out waiting for Advisor page matching: ${config.targetUrlContains.join(', ')}`);
}

async function evaluateReadOnlyOp(page: Page, payload: string): Promise<string> {
  return page.evaluate((source) => {
    let copied = '';
    const copy = (value: unknown) => {
      copied = String(value ?? '');
      return copied;
    };
    const returned = Function('copy', source)(copy);
    return copied || String(returned ?? '');
  }, payload);
}

async function readAdvisorStateBundle(page: Page, config: SidecarConfig): Promise<unknown[]> {
  const runtime = loadOperatorRuntime();
  const results: unknown[] = [];
  for (const op of config.ops) {
    const startedAt = Date.now();
    const args = buildArgsForOp(op, config);
    const payload = renderAdvisorOperatorPayload(runtime, op, args);
    const raw = await evaluateReadOnlyOp(page, payload);
    results.push({
      op,
      readOnly: true,
      elapsedMs: Date.now() - startedAt,
      parsed: parseOutput(op, raw),
      raw
    });
  }
  return results;
}

function writeJson(filePath: string, value: unknown): void {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

async function run(config: SidecarConfig): Promise<unknown> {
  if (!config.noWrite) assertOutputPathSafe(config.outputPath, config.allowOutputOutsideLogs);

  const context = await launchDedicatedEdgeProfile(config);
  try {
    const page = await waitForAdvisorPage(context, config);
    const results = await readAdvisorStateBundle(page, config);
    const envelope = {
      schemaVersion: 'advisor-playwright-ts-scan-sidecar/v1',
      tool: TOOL_NAME,
      capturedAt: new Date().toISOString(),
      readOnly: true,
      mutationAllowed: false,
      launch: {
        channel: 'msedge',
        profileDir: config.profileDir,
        initialUrl: config.initialUrl
      },
      target: {
        url: page.url(),
        title: await page.title()
      },
      ops: config.ops,
      outputPath: config.noWrite ? '' : config.outputPath,
      results
    };
    if (!config.noWrite) writeJson(config.outputPath, envelope);
    return envelope;
  } finally {
    await context.close().catch(() => undefined);
  }
}

function helpText(): string {
  return [
    'Usage:',
    '  node dist/index.js --initial-url https://advisorpro.allstate.com/',
    '',
    'Defaults:',
    `  profile: ${relativeToRepo(DEFAULT_PROFILE_DIR)}`,
    `  output: ${relativeToRepo(DEFAULT_OUTPUT_PATH)}`,
    '  target URL token: advisorpro.allstate.com',
    `  ops: ${DEFAULT_BUNDLE_OPS.join(', ')}`,
    '',
    'Safety:',
    '  Launches a dedicated Edge persistent profile and then only waits for/read-scans Advisor state.',
    '  Refuses any op outside the read-only allowlist.',
    '  Does not call page.goto, click, fill, press, type, submit, screenshot, or focus APIs.'
  ].join('\n');
}

async function main(): Promise<void> {
  const config = parseArgv(process.argv.slice(2));
  if (config.help) {
    process.stdout.write(`${helpText()}\n`);
    return;
  }
  if (config.listOps) {
    process.stdout.write(`${READ_ONLY_OPS.join('\n')}\n`);
    return;
  }

  const result = await run(config);
  if (config.stdout || config.noWrite) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    return;
  }
  process.stdout.write(`${TOOL_NAME}: OK\n`);
  process.stdout.write(`output=${config.outputPath}\n`);
}

main().catch((error) => {
  process.stderr.write(`${TOOL_NAME}: FAILED\n`);
  process.stderr.write(`${String(error instanceof Error ? error.stack : error)}\n`);
  process.exit(1);
});
