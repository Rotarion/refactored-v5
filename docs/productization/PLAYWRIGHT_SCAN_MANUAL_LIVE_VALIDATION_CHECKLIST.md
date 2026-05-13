# Playwright Scan Sidecar Manual Live Validation Checklist

Purpose: repeatable, sanitized manual validation for the Phase 2 scan-only CDP sidecar. This checklist is safe to commit because it contains no raw Advisor output, lead data, VINs, DOBs, addresses, phones, emails, screenshots, traces, or quote values.

## Hard Safety Boundary

Before every live validation run, confirm:

- [ ] The test scope is scan-only observation.
- [ ] No quoting is being implemented or exercised by the sidecar.
- [ ] No click/fill/press/type/goto/navigation-after-existing-page APIs are introduced.
- [ ] No AHK workflow behavior is changed.
- [ ] No Advisor JS operator behavior is changed.
- [ ] `assets/js/advisor_quote/ops_result.js` is not hand-edited.
- [ ] Raw live scan files remain under ignored `logs/` paths and are not staged.

## Browser Setup

- [ ] Start Edge/Chromium separately with a local remote debugging port, for example `http://127.0.0.1:9222`.
- [ ] Open Advisor Pro manually.
- [ ] Log in manually if needed.
- [ ] Navigate manually to the Advisor page under validation.
- [ ] Do not use the sidecar to create quotes, continue pages, save forms, or move the workflow forward.

## Recommended CDP Scan Command

Use an explicit run id so multiple page scans land in one archive folder:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
$RUN="manual-live-validation-YYYYMMDD-001"
& $NODE .\tools\playwright_advisor_scan_sidecar.js `
  --cdp-url http://127.0.0.1:9222 `
  --run-id $RUN `
  --label "manual live validation" `
  --op advisor_state_snapshot `
  --op advisor_active_modal_status `
  --op gather_rapport_snapshot `
  --op asc_drivers_vehicles_snapshot `
  --op scan_current_page
```

If the preflight succeeds but a full read-only operator times out, retry only with a larger evaluation timeout:

```powershell
& $NODE .\tools\playwright_advisor_scan_sidecar.js `
  --cdp-url http://127.0.0.1:9222 `
  --run-id $RUN `
  --label "manual live validation retry" `
  --cdp-eval-timeout-ms 60000 `
  --op advisor_state_snapshot
```

## Expected Local Artifacts

Do not commit these raw artifacts.

- [ ] Latest pointer: `logs/playwright_advisor_scan_latest.json`
- [ ] Archive folder: `logs/playwright_advisor_scans/runs/<runId>/`
- [ ] Run summary: `logs/playwright_advisor_scans/runs/<runId>/run_summary.json`
- [ ] Numbered scan file names use route/op tokens only, for example `001_PRODUCT_OVERVIEW_advisor_state_snapshot.json`.
- [ ] CLI output includes `archiveRunId=`, `archiveSummary=`, and `archiveFiles=` when writes are enabled.

## Validation Notes To Record In A Sanitized Follow-Up Doc

Record only these sanitized fields in any committed findings document:

- Date of validation.
- Sidecar branch/commit.
- Node command shape, without raw customer/quote data.
- Run id.
- Page family or route token, such as `PRODUCT_OVERVIEW`, `RAPPORT`, `ASC_DRIVERS_VEHICLES`, `COVERAGES`, `UNKNOWN_UNSAFE`.
- Whether `run_summary.json` updated `scanCount`, `lastRoute`, `lastConfidence`, `lastUnsafe`, and `countsByRoute` as expected.
- Whether every CLI run printed the archive paths.
- Whether any op returned empty, parse-error, timeout, or unsafe evidence.
- Whether raw artifacts stayed ignored under `logs/`.

Do not record:

- Full URLs containing prospect/customer ids.
- Page titles if they contain customer/prospect text.
- Names, addresses, DOBs, phones, emails, VINs, raw lead details, quote premiums, screenshots, traces, or copied raw scan JSON.

## Pass Criteria For This Checkpoint

- [ ] Contract tests pass.
- [ ] `build_operator.js --check` passes; generated operator has no drift.
- [ ] Manual CDP run succeeds against at least one user-opened Advisor page without clicking/filling/typing/navigating.
- [ ] `run_summary.json` exists and has schema `advisor-playwright-scan-run-summary/v1`.
- [ ] Archive files are numbered and route/op named.
- [ ] CLI output gives enough archive path evidence to find the run later.
- [ ] `git status --short` shows no staged/raw `logs/` content.
