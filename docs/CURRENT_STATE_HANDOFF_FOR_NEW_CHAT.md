# Current State Handoff For New Chat

Captured: 2026-05-06

This is a current-state handoff for the Advisor Pro automation project. It is based on the current repo, current docs, current Git state, and latest available local logs. It intentionally excludes live customer PII and does not include raw scan or log dumps.

## Branch And Git State

- Branch: `feature/advisor-resident-runner`
- Current tracked working tree status at refresh: clean.
- Untracked docs created by this handoff:
  - `docs/CONNECTORS_AND_BRIDGE_MAP.md`
  - `docs/CURRENT_STATE_HANDOFF_FOR_NEW_CHAT.md`
  - `docs/NEXT_PATCH_DECISION_TREE.md`
  - `docs/RESTRUCTURE_TARGETS_AUDIT.md`
- Latest commit: `215be48 fix: allow unique age-window spouse override in ASC`

Latest 10 commits:

```text
215be48 fix: allow unique age-window spouse override in ASC
67f93e9 feat: add ASC Drivers Vehicles ledger loop
146d3fb fix: add complete DB-resolved RAPPORT vehicles
6cebb53 feat: route Advisor blockers through snapshots
e74382f feat: add read-only Advisor page snapshots
89d2191 docs: consolidate Advisor project documentation
df57991 fix: use vehicle DB for RAPPORT card matching
2420dc9 feat: add tiny bridge for resident runner commands
7563d10 fix: repair resident runner toolchain validation
1b5c3e0 feat: add read-only resident runner polling
```

## Active Docs

- `AGENTS.md`: root safety and priority rules.
- `ADVISOR_PRO_SCAN_WORKFLOW.md`: scan-backed selectors, route anchors, and workflow rules.
- `docs/PROJECT_ARCHITECTURE_AUDIT.md`: consolidated implementation overview.
- `docs/ADVISOR_JS_OPERATOR_CONTRACT.md`: stable JS operator prompt path.
- `docs/ADVISOR_GATHER_DATA_VEHICLE_ADD_NOTES.md`: stable Gather Data vehicle prompt path.
- `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`: DB-backed Rapport vehicle contract.
- `docs/AHK_TOOLCHAIN_CHECKS.md`: bounded AutoHotkey validation contract.

Known doc/code tension: `ADVISOR_PRO_SCAN_WORKFLOW.md` still says unmatched Rapport vehicles should be skipped/deferred and Add Car or Truck should not open. Current code, `docs/PROJECT_ARCHITECTURE_AUDIT.md`, `docs/ADVISOR_GATHER_DATA_VEHICLE_ADD_NOTES.md`, and `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md` implement default `match-existing-then-add-complete`, which allows controlled DB-backed adds for complete DB-resolved vehicles after confirmed and potential-card checks fail safely.

## Runtime Layout

Primary bootstrap:

- `main.ahk`

Main Advisor workflow:

- `workflows/advisor_quote_workflow.ahk`

Domain layer:

- `domain/advisor_quote_db.ahk`
- `domain/advisor_vehicle_catalog.ahk`
- `domain/lead_parser.ahk`
- `domain/lead_normalizer.ahk`

Adapters and bridge surfaces:

- `adapters/browser_focus_adapter.ahk`
- `adapters/clipboard_adapter.ahk`
- `adapters/devtools_bridge.ahk`
- `adapters/crm_adapter.ahk`
- `adapters/quo_adapter.ahk`

Advisor JS operator:

- Source: `assets/js/advisor_quote/src/operator.template.js`
- Generated runtime: `assets/js/advisor_quote/ops_result.js`
- Builder: `assets/js/advisor_quote/build_operator.js`

Tests and fixtures:

- `tests/advisor_quote_ops_smoke.js`
- `tests/advisor_quote_helper_tests.ahk`
- `tests/fixtures/advisor_quote_operator/sanitized_dom_scenarios.json`

Logs:

- `logs/advisor_quote_trace.log`
- `logs/advisor_scan_latest.json`
- `logs/advisor_scans/advisor_scan_run_*.json`
- `logs/devtools_bridge_returns.log`
- `logs/run_state.json`

## Hotkeys And Entry Points

- Advisor quote workflow: `Ctrl+Alt+-` / AHK `^!-`
- Advisor entry function: `RunAdvisorQuoteWorkflowFromClipboard()`
- Stop: `Esc`
- Exit app: `F1`
- Config UI: `Ctrl+Alt+1`
- Batch stable: `Ctrl+Alt+B`
- Batch fast: `Ctrl+Alt+N`
- CRM attempted contact: `Ctrl+Alt+K`
- CRM quote call: `Ctrl+Alt+J`
- CRM latest batch OK attempted contact: `Ctrl+Alt+H`

## Current Advisor Workflow States

The current workflow sequence is:

```text
EDGE_ACTIVATION
ENTRY_SEARCH
ENTRY_CREATE_FORM
DUPLICATE
CUSTOMER_SUMMARY_OVERVIEW
PRODUCT_OVERVIEW
RAPPORT
SELECT_PRODUCT
CONSUMER_REPORTS
DRIVERS_VEHICLES
INCIDENTS
QUOTE_LANDING
DONE
```

Each state is run through `AdvisorQuoteRunStateWithRetries()`. Each attempt writes an entry scan, logs status, calls one handler, and only retries when the result is marked retryable.

## Implemented Behavior By State

### Customer Summary

- Detects `/apps/customer-summary/{id}/overview`.
- Requires `START HERE (Pre-fill included)` plus Customer Summary evidence.
- Clicks the scoped `START HERE (Pre-fill included)` target.
- Waits for Product Overview.
- Fails with `CUSTOMER_SUMMARY_START_HERE_NOT_FOUND`, `CUSTOMER_SUMMARY_START_HERE_CLICK_FAILED`, or `CUSTOMER_SUMMARY_TO_PRODUCT_OVERVIEW_TIMEOUT` when the bridge cannot safely advance.

### Product Overview

- Handles the newer Product Overview grid, not the old Select Product form.
- Reads `product_overview_tile_status` for the `Auto` tile.
- If Auto is already selected, skips the click and logs an idempotent path.
- If not selected, clicks the scoped Auto tile and verifies selected evidence.
- Clicks `Save & Continue to Gather Data`.
- Sets local flags that later gate Start Quoting fallback/recovery.

### RAPPORT

- Waits for Gather Data / Rapport.
- Fills defaults: email when present, age first licensed `16`, residence ownership/type.
- Uses `gather_rapport_snapshot` before vehicle work.
- Routes active Gather Edit Vehicle panels through the edit handler.
- Current gap: active stale Gather add rows are detected by snapshot but `AdvisorQuoteResolveGatherSnapshotBlockers()` only handles `GATHER_EDIT_VEHICLE`; stale add rows currently fail as `RAPPORT_ACTIVE_BLOCKER_UNHANDLED`.
- Classifies lead vehicles as complete/actionable, partial year/make, VIN-deferred, ignored missing-year, or blocking.
- Uses DB-backed matching before any controlled add.
- Fails if no vehicle is safely satisfied and Advisor still needs a vehicle.

### Start Quoting

- Start Quoting is handled inside the RAPPORT state.
- Reads `gather_start_quoting_status`.
- Ensures Auto is selected and rating state is `FL`.
- If `Create Quotes & Order Reports` is enabled, clicks it and waits for Consumer Reports, Drivers/Vehicles, Incidents, or quote landing.
- If Create Quotes is disabled but scoped Start Quoting Add Product is present, it can run the scoped handoff only after Product Overview Auto was verified.
- Product Tile recovery exists from Rapport via the Select Product subnav when Auto is missing after a previously verified Product Overview path.
- Broad sidebar Add Product fallback is refused when the Product Overview Auto gate is not satisfied.

### Consumer Reports Route-Forward

- Detects `/apps/ASCPRODUCT/{id}/` dynamically.
- If already on ASCPRODUCT and Drivers/Vehicles is detected, routes directly into `AdvisorQuoteHandleDriversVehicles()` and returns `CONSUMER_REPORTS_ROUTED_TO_DRIVERS_VEHICLES`.
- If already on Incidents or Quote Landing, treats the stage as satisfied.
- If still on Consumer Reports consent, clicks Yes.
- Fails with `ASC_PRODUCT_SUBSTATE_UNKNOWN` when ASCPRODUCT is detected but not classifiable as Consumer Reports, Drivers/Vehicles, Incidents, or quote landing.

### ASCPRODUCT Drivers/Vehicles

- Uses `asc_drivers_vehicles_snapshot` as the first read on each ledger loop iteration.
- If an active modal/panel exists, avoids row reads and routes the blocker first.
- Reads participant detail, driver rows, and vehicle rows only when no active blocker is present.
- Builds an AHK ledger and chooses one next action.
- Handles:
  - active ASC remove-driver modal
  - active ASC inline participant panel
  - active ASC vehicle modal
  - primary driver add
  - spouse policy resolution
  - spouse driver add when selected
  - extra driver removal
  - expected vehicle membership row add
  - save gate
- Save is allowed only when the ledger says the main save button is present and enabled.
- Current committed defaults allow Single/unknown spouse override only when the override flag is enabled and a unique safe in-window Advisor-surfaced spouse candidate exists.

### Incidents

- Detects dynamic ASCPRODUCT Incidents page by route family and text/continue evidence.
- Uses configured reason text: `Accident caused by being hit by animal or road debris`.
- Clicks matching incident checkbox/label and continues.
- Skips when not on Incidents.

### Quote Landing

- Detects quote-ready ASCPRODUCT pages by quote/offer landing evidence.
- Treats first quote-ready page as success.
- Does not hard-code ASCPRODUCT route ids.

## Current Vehicle DB Behavior

- Runtime index: `data/vehicle_db_runtime_index.tsv`
- Compact source: `data/vehicle_db_compact.json`
- Builder: `tools/build_vehicle_runtime_index.js`
- AHK owner: `domain/advisor_vehicle_catalog.ahk`
- JS does not load the vehicle DB. AHK resolves DB evidence and passes bounded labels/aliases/keys into JS.

Resolver contract:

- `RESOLVED`: unique safe year/make/model group.
- `PARTIAL`: missing year or model.
- `UNKNOWN`: DB load/miss or unsupported coverage.
- `AMBIGUOUS`: broad or multiple DB model groups.

Safety behavior:

- Exact year remains required when lead year exists.
- Make matching uses DB make family and Advisor labels.
- Model matching uses strict normalized aliases/keys.
- VIN can strengthen evidence but does not override wrong year or model family.
- Non-overmatch guards include Prius/Prius Prime, Transit/Transit Connect, F150/F250, Silverado family splits, and CR-V/HR-V.

Rapport behavior in current code:

- Check confirmed cards first.
- Check potential/public-record cards next.
- If no safe existing card matches and the vehicle is complete and DB-resolved, attempt controlled DB-backed Add Car/Truck.
- Partial, unknown, ambiguous, duplicate, or unsafe candidates are deferred/fail safe.

## Current Snapshot Layer Behavior

Snapshot ops are read-only JS status readers:

- `advisor_active_modal_status`
- `gather_rapport_snapshot`
- `asc_drivers_vehicles_snapshot`

They return compact key/value blocks for route family, active modal/panel, save gate, counts, blocker code, recommended next read, evidence, and missing fields.

They must not click, type, save, confirm vehicles, remove drivers, create quotes, or navigate.

Current consumers:

- RAPPORT uses `gather_rapport_snapshot` before vehicle handling.
- Drivers/Vehicles uses `asc_drivers_vehicles_snapshot` on every ledger iteration.
- Active modal/panel status is embedded into both route-specific snapshots.

Known gap:

- Stale Gather add row is detectable as `GATHER_STALE_ADD_VEHICLE_ROW_OPEN`, but the AHK RAPPORT blocker resolver does not yet route or cancel it. Latest logs show this as the current live blocker.

## Current ASC Ledger Behavior

`AdvisorQuoteRunAscDriversVehiclesLedgerLoop()` runs up to 20 iterations and guards repeated same actions.

Ledger fields include:

- `routeFamily`
- `ascProductRouteId`
- `activeModalType`
- `activePanelType`
- `blockerCode`
- `primaryDriverStatus`
- `spousePolicy`
- `spouseStatus`
- `selectedSpouseName`
- current local spouse override fields
- driver/vehicle unresolved counts
- expected vehicle counts
- main save gate
- `nextAction`
- `reason`
- `evidence`

Current spouse behavior:

- `domain/advisor_quote_db.ahk` currently sets `ascSpouseOverrideSingleEnabled=true`.
- `ascSpouseAgeWindowYears=14`.
- `ascSpousePreferClosestAge=true`.
- For Single/unknown leads with override enabled, a unique in-window candidate can drive a spouse marital-panel resolution path.
- Ambiguous candidates fail safe.

## Resident Runner Status

Current flags in `workflows/advisor_quote_workflow.ahk`:

- `advisorQuoteResidentRunnerFeatureEnabled := false`
- `advisorQuoteResidentRunnerReadOnlyOnly := true`
- `advisorQuoteResidentRunnerUseTinyBridge := true`

Implemented runner commands:

- bootstrap
- status
- stop
- reset
- getEvents
- bounded read-only polling

Production still uses per-op DevTools injection unless the feature flag is explicitly changed. Mutating commands are refused while the read-only guard is active.

## DevTools Bridge Behavior

Advisor quote workflow uses a local console bridge inside `workflows/advisor_quote_workflow.ahk`:

- focuses Edge
- opens/reuses DevTools with `Ctrl+Shift+J`
- pastes rendered JS
- submits with Enter after paste/focus checks
- expects JS to return through `copy(String(...))`
- restores clipboard from `ClipboardAll()`
- invalidates the bridge on empty result

Shared adapter bridge in `adapters/devtools_bridge.ahk` is used by CRM/Quo/devtools assets:

- focuses Edge or work browser by mode
- opens DevTools without sending Esc
- logs structured results to `logs/devtools_bridge_returns.log`
- redacts email, phone, SSN, and long ids in bridge result previews

Latest bridge-log summary was sanitized only. The recent `devtools_bridge_returns.log` tail is mostly CRM/Blitz/Quo, not Advisor quote ops.

## Latest Logs Summary

No raw log or scan payload is included here.

- `logs/run_state.json`: running is false, stop flag is false, last action is `advisor-quote-step-gather-data`, updated `2026-05-06 11:42:44`.
- `logs/advisor_scan_latest.json`: latest scan captured `2026-05-06T15:42:52.556Z`, route is `/apps/intel/102/rapport`, title is Advisor Pro, with 9 headings, 19 fields, 40 buttons, 0 radios, and no dialogs. It contains live customer-visible page text and was summarized only.
- `logs/advisor_quote_trace.log`: latest failure is RAPPORT. Snapshot detected `GATHER_STALE_ADD_VEHICLE_ROW_OPEN`; current AHK blocker resolver treats that as unhandled and fails `RAPPORT_ACTIVE_BLOCKER_UNHANDLED`.
- Earlier same-session failure: RAPPORT hit `NO_SAFE_RAPPORT_VEHICLE_MATCH` after DB-backed add attempts could not safely satisfy any lead vehicle.
- Earlier ASCPRODUCT failure: inline participant panel fill failed because the military radio control was not found/matched.
- `logs/devtools_bridge_returns.log`: recent bridge summary had many OK returns, CRM/Blitz status payloads classified as error-looking key/value payloads, several stale clipboard/copy-result failures, and one stopped-before-console-prep event. Raw entries contain live CRM lead data and must not be staged or pasted.

## Validation Commands

Documentation-only changes do not require running the AutoHotkey checker, but these are the expected validation commands after runtime changes:

```powershell
node .\assets\js\advisor_quote\build_operator.js --check
node .\assets\js\advisor_quote\build_operator.js
node .\assets\js\advisor_quote\build_operator.js --check
node .\tests\advisor_quote_ops_smoke.js
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

AHK validation must use `tools\Test-AhkToolchain.ps1`. Do not run raw AutoHotkey interpreter/compiler checks.

## Implemented Versus Only Discussed

Implemented now:

- Customer Summary START HERE bridge.
- Product Overview grid Auto tile selection and verification.
- DB-backed Rapport vehicle matching and controlled complete-vehicle add path.
- Gather Edit Vehicle update handling.
- Read-only snapshot ops.
- ASC Drivers/Vehicles ledger loop.
- ASC remove-driver reason verification before save.
- Resident runner skeleton, tiny bridge, and read-only polling, disabled by default.
- DevTools bridge logging and clipboard restoration.

Only discussed or not fully wired:

- Resident runner as a production replacement for per-op injection.
- Mutating resident runner commands.
- Stale Gather add-row routing/cancel inside the RAPPORT snapshot blocker gate.
- Full migration away from legacy Drivers/Vehicles helpers.
- Full extraction of business policy out of JS DOM executor code.
- Live-proofed handling for every Advisor layout variation.

## Pending Live Validation Needs

Next live validation should focus on:

1. RAPPORT stale Gather add-row handling after a failed or partial DB-backed add.
2. RAPPORT controlled add with submodel-required rows where model/submodel choices are ambiguous.
3. ASC inline participant panel where military/required radio controls are absent or hidden.
4. ASC spouse override behavior under the committed default, especially Single/unknown leads with one unique in-window Advisor-surfaced spouse candidate.
5. Start Quoting scoped Add Product handoff after Create Quotes stays disabled.
