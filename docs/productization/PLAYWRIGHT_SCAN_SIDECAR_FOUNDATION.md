# Playwright Scan-Only Sidecar Foundation

Created: 2026-05-12
Branch base: `hermes-state-snapshot-foundation` at `c5ca1e1`

This sidecar is a productization-only read path. It does not change AutoHotkey workflow behavior, Advisor JavaScript operator behavior, hotkeys, generated runtime output, or live Advisor mutation policy.

## Scope

- CDP attach CLI: `tools/playwright_advisor_scan_sidecar.js`
- Dedicated Edge TypeScript sidecar: `sidecars/advisor-playwright-scan/src/index.ts`
- CDP contract test: `tests/playwright_scan_sidecar_contract_tests.js`
- TypeScript sidecar contract test: `tests/playwright_ts_sidecar_contract_tests.js`
- CDP output location: `logs/playwright_advisor_scan_latest.json`
- TypeScript sidecar output location: `logs/playwright_ts_advisor_scan_latest.json`

The CDP attach sidecar connects to an already-running Chromium/Edge instance and evaluates only allowlisted read-only Advisor ops from the existing generated operator runtime.

It prefers `playwright` / `playwright-core` when one of those modules is already available. If neither module is installed, it falls back to a zero-dependency direct CDP path using Node built-in `fetch` and `WebSocket`.

The TypeScript skeleton launches a dedicated Microsoft Edge persistent profile under `logs/playwright-edge-advisor-profile`, opens the initial Advisor URL through the browser launch command, then only waits for a matching Advisor page and performs the same read-only state reads.

Allowlisted ops:

- `advisor_state_snapshot`
- `advisor_active_modal_status`
- `gather_rapport_snapshot`
- `asc_drivers_vehicles_snapshot`
- `scan_current_page`

Mutating ops such as `click_by_id`, `click_by_text`, `fill_gather_defaults`, `confirm_potential_vehicle`, `fill_participant_modal`, and save/continue handlers are refused before payload rendering.

## Shared Safety Contract

- No click, type, save, confirm, remove, quote creation, screenshot, or focus action.
- No AHK workflow integration.
- No edits to `assets/js/advisor_quote/src/operator.template.js`.
- No hand edits to `assets/js/advisor_quote/ops_result.js`.
- Raw scan output stays under ignored `logs/` paths by default.

The sidecar reuses the frozen Advisor operator contract instead of adding a parallel route classifier.

CDP attach utility:

- No browser launch.
- No navigation.
- No npm, npx, corepack, package-lock, or node_modules requirement for the direct CDP fallback.
- Target discovery reads `http://127.0.0.1:9222/json` first, then `/json/list`.
- Browser evaluation uses only CDP `Runtime.evaluate`.
- Forbidden CDP action/navigation methods such as `Page.navigate`, `Input.*`, `Runtime.callFunctionOn`, screenshots, and screencasts are rejected by the method guard.

TypeScript dedicated-profile utility:

- Launches Edge with a dedicated persistent profile.
- Opens only the initial URL during browser launch.
- Does not call `page.goto` or any other Playwright navigation/action API after launch.

## Usage

For the CDP attach utility, start Edge/Chromium separately with a local remote debugging port, then run:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE .\tools\playwright_advisor_scan_sidecar.js --cdp-url http://127.0.0.1:9222
```

This works without Playwright installed when the bundled Node runtime provides built-in `fetch` and `WebSocket`.

The default target URL token is `advisorpro.allstate.com`. The default output is:

```text
logs/playwright_advisor_scan_latest.json
```

To run a smaller read-only bundle:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE .\tools\playwright_advisor_scan_sidecar.js --cdp-url http://127.0.0.1:9222 --op advisor_state_snapshot --op scan_current_page
```

To override the target URL token:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE .\tools\playwright_advisor_scan_sidecar.js --cdp-url http://127.0.0.1:9222 --target-url-token advisorpro.allstate.com
```

For the TypeScript dedicated Edge profile skeleton:

```powershell
cd .\sidecars\advisor-playwright-scan
npm install
npm run build
node .\dist\index.js --initial-url https://advisorpro.allstate.com/
```

## Validation

Contract-only validation, no live Advisor connection required:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE .\tests\playwright_scan_sidecar_contract_tests.js
& $NODE .\tests\playwright_ts_sidecar_contract_tests.js
```

Recommended no-runtime-drift checks for this phase:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE .\assets\js\advisor_quote\build_operator.js --check
& $NODE .\tests\advisor_quote_ops_smoke.js
```
