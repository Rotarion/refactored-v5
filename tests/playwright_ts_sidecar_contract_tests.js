const assert = require('assert');
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const sidecarRoot = path.join(repoRoot, 'sidecars', 'advisor-playwright-scan');
const srcPath = path.join(sidecarRoot, 'src', 'index.ts');
const readmePath = path.join(sidecarRoot, 'README.md');
const packagePath = path.join(sidecarRoot, 'package.json');
const tsconfigPath = path.join(sidecarRoot, 'tsconfig.json');

function read(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function extractArray(source, name) {
  const pattern = new RegExp(`(?:export\\s+)?const\\s+${name}:[^=]+=[\\s\\S]*?\\] as const;`);
  const match = source.match(pattern);
  assert.ok(match, `missing array ${name}`);
  return Array.from(match[0].matchAll(/'([^']+)'/g)).map((entry) => entry[1]);
}

function testPackageSkeletonExists() {
  const pkg = JSON.parse(read(packagePath));
  const tsconfig = JSON.parse(read(tsconfigPath));
  assert.strictEqual(pkg.name, 'advisor-playwright-scan-sidecar');
  assert.strictEqual(pkg.private, true);
  assert.ok(pkg.dependencies.playwright);
  assert.ok(pkg.devDependencies.typescript);
  assert.strictEqual(tsconfig.compilerOptions.strict, true);
  assert.strictEqual(tsconfig.compilerOptions.rootDir, 'src');
}

function testDedicatedEdgeLaunchContract() {
  const source = read(srcPath);
  assert.ok(source.includes('chromium.launchPersistentContext'), 'must use a persistent browser profile');
  assert.ok(source.includes("channel: 'msedge'"), 'must launch Microsoft Edge channel');
  assert.ok(source.includes('DEFAULT_PROFILE_DIR'), 'must define a dedicated profile dir');
  assert.ok(source.includes("'logs', 'playwright-edge-advisor-profile'"), 'profile must default under ignored logs/');
  assert.ok(source.includes('args: browserArgs'), 'initial URL should be opened by browser launch args');
  assert.ok(!source.includes('connectOverCDP'), 'TypeScript skeleton should launch its own Edge profile');
}

function testNoPlaywrightMutationOrNavigationCalls() {
  const source = read(srcPath);
  const forbidden = [
    '.goto(',
    '.click(',
    '.dblclick(',
    '.fill(',
    '.press(',
    '.type(',
    '.check(',
    '.uncheck(',
    '.selectOption(',
    '.setInputFiles(',
    '.dragTo(',
    '.screenshot(',
    '.bringToFront(',
    '.focus(',
    '.keyboard',
    '.mouse',
    'locator(',
    'getByRole(',
    'getByText(',
    'getByLabel('
  ];
  for (const token of forbidden) {
    assert.ok(!source.includes(token), `forbidden Playwright mutation/navigation token found: ${token}`);
  }
}

function testReadOnlyAllowlist() {
  const source = read(srcPath);
  const ops = extractArray(source, 'READ_ONLY_OPS');
  assert.deepStrictEqual(ops, [
    'advisor_state_snapshot',
    'advisor_active_modal_status',
    'gather_rapport_snapshot',
    'asc_drivers_vehicles_snapshot',
    'scan_current_page'
  ]);
  for (const mutatingOp of ['click_by_id', 'fill_gather_defaults', 'confirm_potential_vehicle', 'fill_participant_modal']) {
    assert.ok(!ops.includes(mutatingOp), `mutating op leaked into read-only allowlist: ${mutatingOp}`);
  }
  assert.ok(source.includes('Refusing non-read-only Advisor op'), 'must refuse non-read-only ops');
  assert.ok(source.includes('assertReadOnlyOps([op]);'), 'payload rendering must re-check the op allowlist');
}

function testDocsStateBoundary() {
  const readme = read(readmePath);
  assert.ok(readme.includes('Does not call `page.goto`'));
  assert.ok(readme.includes('Does not create quotes, save, confirm, remove, or continue.'));
  assert.ok(readme.includes('Evaluates only allowlisted read-only Advisor operator ops.'));
}

function run() {
  testPackageSkeletonExists();
  testDedicatedEdgeLaunchContract();
  testNoPlaywrightMutationOrNavigationCalls();
  testReadOnlyAllowlist();
  testDocsStateBoundary();
  process.stdout.write('playwright_ts_sidecar_contract_tests: PASS\n');
}

run();
