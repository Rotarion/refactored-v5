# Codex Architecture Continuation Audit

Repository root: `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor`

Audit date: 2026-05-12

This report is a current-state map for continuing development safely. It is intentionally descriptive. It does not propose a rewrite, does not rename contracts, and does not treat generated/runtime artifacts as editable source.

## 1. Executive summary

This repository is an AutoHotkey v2 automation system with supporting JavaScript operator injection for Allstate Advisor Pro, plus adjacent CRM, scheduling, lead parsing, message, and batch workflows. The high-risk production surface is the Advisor Pro quote workflow: AHK orchestrates browser activation, state transitions, retries, scan capture, and domain policy; JavaScript reads and manipulates Advisor Pro DOM state through a generated DevTools/operator payload.

The project is not at a greenfield stage. It is in a stabilization and migration stage around the Advisor Pro quote workflow. The newest branch history points to active work on read-only state snapshots, route classification hardening, Select Product readiness, ASC inline participant save behavior, and RAPPORT vehicle gate behavior.

The most important active development area is the Advisor Pro AHK-to-JS contract and the state machine around:

- Customer Summary / prefill gate.
- Product Overview / Auto tile selection.
- RAPPORT Gather Data vehicle handling and Start Quoting handoff.
- ASCPRODUCT Consumer Reports and Drivers/Vehicles reconciliation.
- Read-only state snapshots and scan-backed route classification.

The current system already contains deliberately layered behavior. The safest continuation path is to document the current source of truth, add read-only fixtures and smoke tests for observed gaps, and migrate or isolate one transaction at a time only after the existing contract is protected.

## 2. Current branch and repo state

Commands used for this audit were read-only unless noted.

- `git status --short`: clean at audit time.
- `git status --short --branch`: `## hermes-state-snapshot-foundation...origin/hermes-state-snapshot-foundation`.
- `git branch --show-current`: `hermes-state-snapshot-foundation`.
- `git log --oneline -10`:
  - `87c1bbe fix: use one vehicle as RAPPORT gate`
  - `c1a4909 fix: separate ASC inline save from page continuation`
  - `436c99b fix: detect Select Product current address select`
  - `e32e77f fix: harden Select Product readiness detection`
  - `c23531d chore: add read-only advisor state snapshot observer`
  - `1d1c926 fix: classify Advisor start pages safely in state snapshot`
  - `768a5af fix: initialize console bridge for snapshot debug hotkey`
  - `295b94c chore: add read-only Advisor Pro snapshot debug hotkey`
  - `1bb8734 feat: add read-only Advisor Pro state snapshot`
  - `43bd205 fix: allow Select Product continue when core fields are ready`

The latest commit, `87c1bbe`, changed Advisor JS operator output/source, RAPPORT vehicle handling, smoke tests, and Advisor workflow defaults. That strongly suggests the current branch's most recent business change is the shift to using one confirmed/added vehicle as a RAPPORT gate while leaving remaining reconciliation to later flow.

Generated or runtime artifacts that should not be edited directly:

- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\assets\js\advisor_quote\ops_result.js`
  - Generated runtime operator payload.
  - Source is `assets\js\advisor_quote\src\operator.template.js` plus included snippets.
  - Rebuild/check with `assets\js\advisor_quote\build_operator.js`.
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\data\vehicle_db_runtime_index.tsv`
  - Tracked runtime lookup index used by AHK vehicle catalog logic.
  - Derived from `data\vehicle_db_compact.json` by `tools\build_vehicle_runtime_index.js`.
  - Do not hand-edit unless explicitly treating it as a generated artifact update.
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\data\vehicle_db_compact.json`
  - Currently appears to be a Git LFS pointer, not the full 312 MB JSON object.
  - Rebuilding the runtime vehicle index requires the actual LFS object to be present.
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\logs\...`
  - Logs and scan bundles are ignored/untracked in this repo state.
  - They may contain customer data or live Advisor page text. Summarize before sharing.

Relevant local instruction files:

- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\AGENTS.md`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\docs\AHK_TOOLCHAIN_CHECKS.md`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\docs\PROJECT_ARCHITECTURE_AUDIT.md`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\ADVISOR_PRO_SCAN_WORKFLOW.md`

Important absent or consolidated files:

- `ADVISOR_JS_OPERATOR_REFACTOR_PLAN.md` was not found. The closest current file is `docs\ADVISOR_JS_MODULARIZATION_PLAN.md`.
- `ADVISOR_EARLY_FLOW_PATCH_NOTES.md` was not found.
- `ADVISOR_PREFILL_PRODUCT_GATHER_FLOW_SOURCE_MAP.md` was not found.
- `ADVISOR_ROUTE_CLASSIFIER_AUDIT.md` was not found.
- `ADVISOR_SCAN_LOGGING_CONTRACT.md` was not found.
- `ADVISOR_DUPLICATE_RESOLUTION_NOTES.md` was not found.
- `docs\PROJECT_ARCHITECTURE_AUDIT.md` states that older one-off audits, patch notes, source maps, and discovery reports were consolidated into that architecture audit.

## 3. System architecture map

### AHK orchestration layer

Primary bootstrap:

- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\main.ahk`

`main.ahk` initializes globals and includes domain modules, adapters, workflow modules, and hotkeys. It also defines Advisor workflow flags such as:

- `advisorRapportGateVehicleEnabled := true`
- `advisorRapportAllowProvisionalSameFamilyGate := true`
- trace and log root paths.

Advisor workflow orchestration:

- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor_quote_workflow.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_entry.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_customer_summary.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_product_overview.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_consumer_reports.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_rapport.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_rapport_vehicles.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_transport.ahk`
- `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor\workflows\advisor\advisor_quote_metrics.ahk`

AHK owns sequencing, retry policy, trace logging, scan bundle capture, clipboard-based DevTools bridge execution, and policy around which JS operations are allowed.

### Hotkey layer

Hotkeys are split by domain:

- `hotkeys\lead_hotkeys.ahk`
- `hotkeys\schedule_hotkeys.ahk`
- `hotkeys\crm_hotkeys.ahk`
- `hotkeys\debug_hotkeys.ahk`

Advisor quote entry is `^!-` / `Ctrl+Alt+-` in `hotkeys\lead_hotkeys.ahk`.

Read-only Advisor scanner is `^!s` in `hotkeys\debug_hotkeys.ahk`.

Read-only Advisor state snapshot debug hotkey is `^!+s` in `hotkeys\debug_hotkeys.ahk`.

### JavaScript operator layer

Generated runtime:

- `assets\js\advisor_quote\ops_result.js`

Source template and snippets:

- `assets\js\advisor_quote\src\operator.template.js`
- `assets\js\advisor_quote\src\core\*.js`
- `assets\js\advisor_quote\src\matchers\*.js`
- `assets\js\advisor_quote\src\resident\command_bus.js`

Build script:

- `assets\js\advisor_quote\build_operator.js`

The JS operator layer reads and mutates Advisor Pro DOM state under explicit operation names. AHK passes an operation name and JSON args by replacing `@@OP@@` and `@@ARGS@@` in the generated JS payload, then reads the returned clipboard string.

Important contract fact: JS does not load the vehicle DB directly. AHK resolves vehicle database candidates and passes bounded labels/aliases/keys into JS.

### Advisor Pro route/state detection

There are two related route systems:

- Fast operator state detection through JS op `detect_state` and AHK wrapper `AdvisorQuoteDetectState`.
- Rich read-only snapshot detection through JS op `advisor_state_snapshot` and AHK snapshot observer/debug wrappers.

JS route/state names observed in source include:

- `ADVISOR_HOME`
- `BEGIN_QUOTING_SEARCH`
- `BEGIN_QUOTING_FORM`
- `DUPLICATE`
- `CUSTOMER_SUMMARY_OVERVIEW`
- `PRODUCT_OVERVIEW`
- `RAPPORT`
- `SELECT_PRODUCT`
- `ASC_PRODUCT`
- `INCIDENTS`
- `GATEWAY`
- `ADVISOR_OTHER`
- `NO_CONTEXT`

Read-only snapshot routes include finer-grained ASCPRODUCT states such as:

- `CONSUMER_REPORTS`
- `ASC_DRIVERS_VEHICLES`
- `COVERAGES`
- `PURCHASE`
- `UNKNOWN_UNSAFE`

### Lead parsing/normalization

Primary lead parsing and profile generation:

- `domain\lead_parser.ahk`
- `domain\lead_normalizer.ahk`
- `domain\batch_rules.ahk`

Advisor workflow entry uses `BuildAdvisorQuoteLeadProfile(raw)` to build the person, address, residence, vehicle, and normalized field shape used by the quote workflow.

### Scan/logging infrastructure

Scan and trace files are runtime diagnostics, not source:

- `logs\advisor_quote_trace.log`
- `logs\advisor_scan_latest.json`
- `logs\advisor_scans\...`
- `logs\advisor_state_snapshot_latest.json`
- `logs\advisor_state_snapshots\...`
- `logs\advisor_quote_metrics.jsonl`
- `logs\run_state.json`

The scan-backed selector and route documentation source is:

- `ADVISOR_PRO_SCAN_WORKFLOW.md`

Runtime scan/snapshot functions are mainly in:

- `workflows\advisor_quote_workflow.ahk`

### Test/smoke-test layer

Node-based JS operator smoke tests:

- `tests\advisor_quote_ops_smoke.js`
- `tests\fixtures\advisor_quote_operator\sanitized_dom_scenarios.json`

AHK helper tests:

- `tests\advisor_quote_helper_tests.ahk`
- `tests\parser_fixtures.ahk`
- `tests\message_tests.ahk`
- `tests\pricing_tests.ahk`
- `tests\date_tests.ahk`
- `tests\workflow_dryrun_tests.ahk`

AHK tests and toolchain checks must go through the documented bounded wrapper/checker, not raw AutoHotkey commands.

### Docs/specification layer

Current authoritative or near-authoritative documentation:

- `AGENTS.md`: local safety and instruction priority.
- `ADVISOR_PRO_SCAN_WORKFLOW.md`: scan-backed Advisor selector/route workflow source.
- `docs\PROJECT_ARCHITECTURE_AUDIT.md`: consolidated architecture map and historical cleanup.
- `docs\ADVISOR_JS_OPERATOR_CONTRACT.md`: stable JS operator contract and generated-file rules.
- `docs\ADVISOR_JS_MODULARIZATION_PLAN.md`: mechanical modularization plan.
- `docs\ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`: vehicle DB matching and RAPPORT add policy.
- `docs\ADVISOR_GATHER_DATA_VEHICLE_ADD_NOTES.md`: current gather vehicle behavior notes.
- `docs\CONNECTORS_AND_BRIDGE_MAP.md`: bridges, logs, local-only boundaries.
- `docs\NEXT_PATCH_DECISION_TREE.md`: trace-first patch triage flow.

Some older handoff files appear stale relative to the current branch and should be treated as historical context unless refreshed.

## 4. Source-of-truth map

### Hotkeys

Authoritative files:

- `main.ahk`
- `hotkeys\lead_hotkeys.ahk`
- `hotkeys\schedule_hotkeys.ahk`
- `hotkeys\crm_hotkeys.ahk`
- `hotkeys\debug_hotkeys.ahk`

Important confirmed bindings:

- Advisor quote workflow: `^!-` / `Ctrl+Alt+-` in `hotkeys\lead_hotkeys.ahk`.
- Advisor scanner: `^!s` in `hotkeys\debug_hotkeys.ahk`.
- Advisor state snapshot debug: `^!+s` in `hotkeys\debug_hotkeys.ahk`.
- Reload: `^!r` in `hotkeys\schedule_hotkeys.ahk`.
- Emergency stop / exit: `Esc` and `F1` in `hotkeys\debug_hotkeys.ahk`.

### Message/scheduling behavior

Authoritative files:

- `workflows\message_schedule.ahk`
- `domain\message_templates.ahk`
- `domain\date_rules.ahk`
- `adapters\quo_adapter.ahk`

Confirmed detail: `adapters\quo_adapter.ahk` uses `^!{Enter}` for schedule UI activation in observed scheduling paths, then uses plain `Enter` later for field-level submit after date/time actions. This area is safety-sensitive because the user explicitly requires no plain Enter where `Ctrl+Alt+Enter` is required.

### Lead parsing

Authoritative files:

- `domain\lead_parser.ahk`
- `domain\lead_normalizer.ahk`
- `domain\batch_rules.ahk`

Key function:

- `BuildAdvisorQuoteLeadProfile(raw)`

Supported input shapes include structured form maps, labeled lead text, tabbed batch grid rows, batch CRM text, and raw fallback text.

### Product tile selection

Authoritative files:

- `workflows\advisor\advisor_quote_product_overview.ahk`
- `domain\advisor_quote_db.ahk`
- `assets\js\advisor_quote\src\operator.template.js`
- `assets\js\advisor_quote\ops_result.js` as generated runtime only.
- `ADVISOR_PRO_SCAN_WORKFLOW.md`

Important JS ops include:

- `product_overview_tile_status`
- `click_product_overview_tile`
- `ensure_product_overview_tile_selected`
- `click_product_overview_subnav_from_rapport`

### Prefill gate detection

Authoritative files:

- `workflows\advisor\advisor_quote_customer_summary.ahk`
- `assets\js\advisor_quote\src\operator.template.js`
- `ADVISOR_PRO_SCAN_WORKFLOW.md`

Important JS ops include:

- `customer_summary_overview_status`
- `click_customer_summary_start_here`

The root flow treats Customer Summary Overview as a distinct state before Product Overview.

### RAPPORT flow

Authoritative files:

- `workflows\advisor\advisor_quote_rapport.ahk`
- `workflows\advisor\advisor_quote_rapport_vehicles.ahk`
- `domain\advisor_quote_db.ahk`
- `domain\advisor_vehicle_catalog.ahk`
- `docs\ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`
- `docs\ADVISOR_GATHER_DATA_VEHICLE_ADD_NOTES.md`

Important JS ops include:

- `fill_gather_defaults`
- `gather_defaults_status`
- `gather_rapport_snapshot`
- `gather_confirmed_vehicles_status`
- `gather_vehicle_add_status`
- `gather_vehicle_row_status`
- `gather_stale_add_vehicle_row_status`
- `cancel_stale_add_vehicle_row`
- `select_gather_add_row_first_valid_submodel`
- `click_gather_add_row_add_button`
- `gather_vehicle_edit_status`
- `handle_vehicle_edit_modal`
- `gather_start_quoting_status`
- `ensure_start_quoting_auto_checkbox`
- `ensure_auto_start_quoting_state`
- `click_create_quotes_order_reports`
- `click_start_quoting_add_product`

Current branch behavior appears to allow one safe confirmed/added vehicle to satisfy the RAPPORT gate, based on latest commit and workflow code. Older docs that say unmatched vehicles must always be skipped/deferred are not the complete current policy; the vehicle DB redesign docs describe controlled DB-backed add behavior.

### Vehicle/driver confirmation

RAPPORT vehicle card/source confirmation:

- `workflows\advisor\advisor_quote_rapport_vehicles.ahk`
- `domain\advisor_vehicle_catalog.ahk`
- `assets\js\advisor_quote\src\matchers\vehicle.js`
- `docs\ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`

ASC Drivers/Vehicles reconciliation:

- `workflows\advisor_quote_workflow.ahk`
- `assets\js\advisor_quote\src\operator.template.js`

Important JS ops include:

- `asc_drivers_vehicles_snapshot`
- `asc_participant_detail_status`
- `asc_resolve_participant_marital_and_spouse`
- `asc_driver_rows_status`
- `asc_reconcile_driver_rows`
- `asc_vehicle_rows_status`
- `asc_reconcile_vehicle_rows`
- `select_remove_reason`
- `fill_participant_modal`
- `fill_vehicle_modal`

### Route classification

Authoritative files:

- `assets\js\advisor_quote\src\operator.template.js`
- `workflows\advisor_quote_workflow.ahk`
- `ADVISOR_PRO_SCAN_WORKFLOW.md`

Primary JS functions/ops:

- `detectAdvisorRuntimeState(...)`
- `detect_state`
- `advisor_state_snapshot`

AHK wrappers and observers live in `workflows\advisor_quote_workflow.ahk`.

### Scan bundle generation

Authoritative files:

- `workflows\advisor_quote_workflow.ahk`
- `ADVISOR_PRO_SCAN_WORKFLOW.md`
- `docs\CONNECTORS_AND_BRIDGE_MAP.md`

Primary outputs:

- `logs\advisor_scan_latest.json`
- `logs\advisor_scans\...`
- `logs\advisor_state_snapshot_latest.json`
- `logs\advisor_state_snapshots\...`

### Smoke tests

Authoritative files:

- `tests\advisor_quote_ops_smoke.js`
- `tests\fixtures\advisor_quote_operator\sanitized_dom_scenarios.json`
- `tests\advisor_quote_helper_tests.ahk`

The Node smoke test is the main fast guard for generated JS operator behavior. The AHK helper tests guard parser, policy, and ledger logic but must be run only through the safe AHK checker path.

## 5. AHK-to-JS contract

The AHK-to-JS contract is central and should be treated as frozen unless an explicit migration proves compatibility.

Confirmed contract shape:

- Runtime JS payload: `assets\js\advisor_quote\ops_result.js`.
- Source JS payload: `assets\js\advisor_quote\src\operator.template.js`.
- Build script: `assets\js\advisor_quote\build_operator.js`.
- AHK renders operation and args into generated JS using tokens:
  - `@@OP@@`
  - `@@ARGS@@`
- JS returns text to AHK via `copy(String(...))`.
- AHK parses either scalar strings like `OK`, `1`, `0`, or newline key/value output such as `result=OK`.
- Many AHK decisions depend on exact field names, status strings, and route names.

Contract fields and strings that must not be casually changed:

- Generic result fields:
  - `result`
  - `ok`
  - `status`
  - `reason`
  - `missing`
  - `evidence`
  - `url`
  - `routeFamily`
  - `detectedState`
  - `blockerCode`
  - `nextRecommendedAction`
  - `nextRecommendedReadOnlyStatus`
- Snapshot fields:
  - `activeModalType`
  - `activePanelType`
  - `saveGate`
  - `modalTitle`
  - `mainSavePresent`
  - `mainSaveEnabled`
  - `confirmedVehicleCount`
  - `potentialVehicleCount`
  - `staleAddRowPresent`
  - `createQuotesEnabled`
  - `iframe`
  - `allowedNextActions`
  - `unsafeReason`
- Common result values:
  - `OK`
  - `FAILED`
  - `PARTIAL`
  - `READY`
  - `OPEN`
  - `NOT_FOUND`
  - `NOT_RAPPORT`
  - `NO_CONTEXT`
- Important route/state names:
  - `ADVISOR_HOME`
  - `BEGIN_QUOTING_SEARCH`
  - `BEGIN_QUOTING_FORM`
  - `DUPLICATE`
  - `CUSTOMER_SUMMARY_OVERVIEW`
  - `PRODUCT_OVERVIEW`
  - `SELECT_PRODUCT`
  - `RAPPORT`
  - `ASC_PRODUCT`
  - `CONSUMER_REPORTS`
  - `ASC_DRIVERS_VEHICLES`
  - `INCIDENTS`
  - `COVERAGES`
  - `PURCHASE`
  - `UNKNOWN_UNSAFE`

Resident command bus contract:

- Source: `assets\js\advisor_quote\src\resident\command_bus.js`.
- Read-only status ops are allowlisted.
- Wait conditions are allowlisted.
- Mutation requests are refused unless explicitly enabled; current branch defaults keep mutation disabled.
- Important return fields include:
  - `blockedReason`
  - `op`
  - `waitConditionName`
  - `requestId`
  - `version`
  - `buildHash`
  - `elapsedMs`
  - `mutatingRequestRefused`

Vehicle DB contract:

- JS must not load the vehicle DB.
- AHK resolves vehicle candidates through `domain\advisor_vehicle_catalog.ahk`.
- AHK passes bounded JS args such as allowed make labels, model aliases, normalized model keys, and strict match flags.
- Resolver statuses include:
  - `RESOLVED`
  - `PARTIAL`
  - `UNKNOWN`
  - `AMBIGUOUS`

Generated operator rule:

- Do not patch `ops_result.js` manually.
- Patch source template/snippets.
- Run build drift check and smoke tests after intentional JS changes.

## 6. Current Advisor Pro state machine

The current AHK sequence in `RunAdvisorQuoteWorkflow()` is:

1. `EDGE_ACTIVATION`
2. `ENTRY_SEARCH`
3. `ENTRY_CREATE_FORM`
4. `DUPLICATE`
5. `CUSTOMER_SUMMARY_OVERVIEW`
6. `PRODUCT_OVERVIEW`
7. `RAPPORT`
8. `SELECT_PRODUCT`
9. `CONSUMER_REPORTS`
10. `DRIVERS_VEHICLES`
11. `INCIDENTS`
12. `QUOTE_LANDING`
13. `DONE`

### Advisor Home / Quoting

Entrypoint:

- `RunAdvisorQuoteWorkflowFromClipboard()` in `workflows\advisor_quote_workflow.ahk`.
- Hotkey `Ctrl+Alt+-` in `hotkeys\lead_hotkeys.ahk`.

The flow parses the clipboard lead first, initializes trace/run state, activates Edge/Advisor, and starts the entry search.

Anchoring strength: medium. The system has explicit activation and scan capture, but the root safety rules correctly warn not to assume the correct browser tab merely because Edge or Chrome is focused.

### Begin Quoting

Files:

- `workflows\advisor\advisor_quote_entry.ahk`
- `domain\advisor_quote_db.ahk`
- JS ops around `focus_prospect_first_input`, `prospect_form_status`, and route detection.

The route classifier distinguishes Advisor home/start pages from begin quote search/form states.

Anchoring strength: medium. These states rely on current Advisor page layout and browser context.

### Create New Prospect

Files:

- `workflows\advisor\advisor_quote_entry.ahk`
- `domain\lead_parser.ahk`
- `domain\lead_normalizer.ahk`

AHK owns lead profile creation and form fill policy. JS supports status reads and field operations.

Anchoring strength: medium. Lead parsing has tests and normalized fields, but live form behavior is inherently selector-sensitive.

### Duplicate/existing prospect resolution

Files:

- `workflows\advisor\advisor_quote_entry.ahk`
- `workflows\advisor\advisor_quote_customer_summary.ahk`
- JS op `handle_duplicate_prospect`.
- JS matcher source under `assets\js\advisor_quote\src\matchers\duplicate.js`.

The state machine has an explicit `DUPLICATE` step before Customer Summary.

Anchoring strength: medium-fragile. Duplicate pages are inherently risky because name/address matches can be ambiguous. Any change here should be backed by sanitized scenarios and trace evidence.

### Customer summary / prefill gate

Files:

- `workflows\advisor\advisor_quote_customer_summary.ahk`
- JS ops `customer_summary_overview_status` and `click_customer_summary_start_here`.

The root flow treats this as `CUSTOMER_SUMMARY_OVERVIEW`, with snapshot capture before and after nearby transitions.

Anchoring strength: strong relative to other states. There are explicit JS status operations and state names.

### Product tile grid

Files:

- `workflows\advisor\advisor_quote_product_overview.ahk`
- JS ops `product_overview_tile_status`, `click_product_overview_tile`, `ensure_product_overview_tile_selected`.

The product flow uses Auto tile selection and readiness checks before continuing. Recent commits harden readiness and current-address detection.

Anchoring strength: strong but selector-sensitive. The page is central, and current commits focus on this area. Avoid broad fallback clicks.

### Gather Data / RAPPORT

Files:

- `workflows\advisor\advisor_quote_rapport.ahk`
- `workflows\advisor\advisor_quote_rapport_vehicles.ahk`
- `domain\advisor_vehicle_catalog.ahk`
- `docs\ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`

The RAPPORT flow fills gather defaults, classifies vehicle rows, reads `gather_rapport_snapshot`, handles active edit/stale rows, and then gates Start Quoting.

Current branch behavior appears to use at least one confirmed/added safe vehicle as the RAPPORT gate. Complete DB-resolved lead vehicles can be added in controlled mode. Partial/unknown/ambiguous vehicles are deferred unless explicitly promoted by narrow policy.

Anchoring strength: medium. The logic is much more defensive than a raw click flow, but it is still the highest-risk part of the automation because Advisor page state can have stale rows, open panels, warnings, disabled Create Quotes buttons, and public-record potential vehicles.

### Select Product

Files:

- `workflows\advisor\advisor_quote_product_overview.ahk`
- JS ops `select_product_status`, `set_select_product_defaults`, `ensure_select_product_defaults`, `click_select_product_continue`.

Recent commits specifically harden Select Product readiness and current address select detection.

Anchoring strength: medium-strong. It has dedicated status ops and recent fixes, but it depends on dynamic form readiness.

### Consumer Reports

Files:

- `workflows\advisor\advisor_quote_consumer_reports.ahk`
- JS op coverage in `operator.template.js`.

State classification uses ASCPRODUCT route substate detection to separate Consumer Reports from Drivers/Vehicles and later pages.

Anchoring strength: medium. It is likely stable when route detection is correct, but it lives under the broad `ASC_PRODUCT` route family.

### Vehicle confirmation

RAPPORT vehicle confirmation:

- `workflows\advisor\advisor_quote_rapport_vehicles.ahk`
- JS ops such as `confirm_potential_vehicle`, `gather_confirmed_vehicles_status`, and vehicle row status/readiness ops.

ASC vehicle confirmation:

- `workflows\advisor_quote_workflow.ahk`
- JS ops `asc_vehicle_rows_status`, `asc_reconcile_vehicle_rows`, `fill_vehicle_modal`.

Anchoring strength: medium-fragile. The system has ledgers and snapshots, but stale panels, public-record candidates, and row identity are still production risks.

### Driver confirmation

Files:

- `workflows\advisor_quote_workflow.ahk`
- JS ops `asc_driver_rows_status`, `asc_reconcile_driver_rows`, `asc_participant_detail_status`, `fill_participant_modal`, `select_remove_reason`.

The ASC Drivers/Vehicles ledger has explicit modal/panel blocker handling and a same-action guard.

Anchoring strength: medium. Stronger than legacy click flows because it uses a ledger and blockers, but it is still dynamic DOM automation.

### Coverages / quote

Files:

- `workflows\advisor_quote_workflow.ahk`
- JS route/snapshot detection in `operator.template.js`.

The state snapshot recognizes `COVERAGES`, `PURCHASE`, and quote landing states. The main state machine ends after incident and quote landing handling.

Anchoring strength: medium. Less detail was visible in recent active changes than Product/RAPPORT/ASC Drivers/Vehicles.

### Fragile or unclear anchors

The following should be treated as fragile until backed by latest scan bundles and smoke fixtures:

- Ambiguous ASCPRODUCT substates.
- Open modal/panel detection when multiple UI layers are present.
- Iframe handling. Snapshot includes iframe information, but automation inside frames is still a risk.
- Product tile recovery from RAPPORT through Add Product or subnav paths.
- Stale Gather vehicle add rows.
- Public-record potential vehicle cards with VIN evidence.
- Duplicate prospect resolution.

## 7. Risk register

1. Generated operator drift
   - Risk: patching `ops_result.js` manually or forgetting to rebuild after source changes can desynchronize AHK runtime behavior from reviewed source.
   - Source: `assets\js\advisor_quote\ops_result.js`, `assets\js\advisor_quote\src\operator.template.js`, `assets\js\advisor_quote\build_operator.js`.
   - Severity: high.

2. AHK/JS contract breakage
   - Risk: renaming op names, status strings, key/value fields, or route names can silently break AHK decisions.
   - Source: `workflows\advisor\advisor_quote_transport.ahk`, `workflows\advisor_quote_workflow.ahk`, `assets\js\advisor_quote\src\operator.template.js`.
   - Severity: high.

3. Ambiguous route classification
   - Risk: broad `ASC_PRODUCT` detection can mask Consumer Reports, Drivers/Vehicles, Incidents, Coverages, or Quote Landing differences.
   - Source: JS route classifiers and AHK state retry logic.
   - Severity: high.

4. Stale DOM and open panel blockers
   - Risk: stale add rows, edit vehicle panels, inline participant panels, and remove driver modals can make the next click unsafe.
   - Source: RAPPORT snapshot/blocker logic and ASC ledger loop.
   - Severity: high.

5. Iframe issues
   - Risk: snapshot can report iframe hints, but operator execution in the top page may not see or safely mutate frame content.
   - Source: `advisor_state_snapshot`, scan output.
   - Severity: high if Advisor moves critical content into frames.

6. Fragile selectors and text matching
   - Risk: Advisor Pro UI labels/classes change, generic text clickers target the wrong element, or similarly named controls appear.
   - Source: `domain\advisor_quote_db.ahk`, `operator.template.js`, `ADVISOR_PRO_SCAN_WORKFLOW.md`.
   - Severity: high.

7. RAPPORT one-vehicle gate policy ambiguity
   - Risk: latest branch gates RAPPORT on one safe vehicle, but business expectation might still require every complete lead vehicle to be resolved before Start Quoting.
   - Source: latest commit `87c1bbe`, RAPPORT vehicle ledger functions.
   - Severity: high until policy is confirmed with production traces.

8. Vehicle DB rebuild dependency
   - Risk: `data\vehicle_db_compact.json` is a Git LFS pointer in this checkout. Rebuilding `vehicle_db_runtime_index.tsv` without the LFS object will fail or produce incorrect output.
   - Source: `data\vehicle_db_compact.json`, `tools\build_vehicle_runtime_index.js`.
   - Severity: medium-high.

9. Duplicate workflow/helper paths
   - Risk: legacy ASC/RAPPORT helpers remain alongside newer ledger/snapshot paths. Future patches could accidentally update the wrong path.
   - Source: large `workflows\advisor_quote_workflow.ahk` plus split modules.
   - Severity: medium-high.

10. Unsafe hotkey or Enter usage
   - Risk: production scheduling or messaging workflows can send plain Enter in the wrong context. Debug hotkeys also contain repeated Click/Enter behavior.
   - Source: `hotkeys\debug_hotkeys.ahk`, `adapters\quo_adapter.ahk`, DevTools bridge submit paths.
   - Severity: high for live UI contexts.

11. Offline tests do not prove live Advisor behavior
   - Risk: Node fake-DOM smoke tests validate contracts and sanitized scenarios, but not real browser timing, focus, iframes, or live Advisor DOM churn.
   - Source: `tests\advisor_quote_ops_smoke.js`.
   - Severity: medium.

12. Logs can contain sensitive production data
   - Risk: raw scan/log files may contain customer PII or page data and should not be committed or pasted wholesale.
   - Source: `logs\...`.
   - Severity: medium-high.

## 8. Test coverage and validation gates

No AutoHotkey validation was run during this audit. Status: skipped. Artifact path: none. Reason: the user requested an architecture audit first, and `AGENTS.md` forbids raw AHK checks. If AHK validation is needed, use only the documented bounded checker.

### JS operator build drift check

Command:

```powershell
node .\assets\js\advisor_quote\build_operator.js --check
```

If `node` is not on `PATH`, the repository/prior setup references this runtime:

```powershell
C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe .\assets\js\advisor_quote\build_operator.js --check
```

What it proves:

- Generated `ops_result.js` matches `src\operator.template.js` and included snippets.
- It does not prove live Advisor behavior.

### JS operator smoke tests

Command:

```powershell
node .\tests\advisor_quote_ops_smoke.js
```

Bundled runtime fallback:

```powershell
C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe .\tests\advisor_quote_ops_smoke.js
```

What it proves:

- Generated JS operator behavior against fake DOM fixtures.
- Key result fields and status strings for many Advisor page scenarios.
- Read-only snapshot ops do not mutate in covered fake-DOM cases.
- RAPPORT, Select Product, Product Overview, ASC, stale row, resident runner, and route scenarios that are present in fixtures.

What it does not prove:

- Live Advisor timing.
- Browser focus.
- DevTools bridge focus/paste behavior.
- Real iframe execution.
- New production DOM variants not represented in fixtures.

### AHK toolchain check

Only safe command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

Expected artifact area:

```text
logs\toolchain_checks\<timestamp>\
```

What it proves:

- AutoHotkey interpreter/compiler discovery and guarded validation through timeout wrapper.
- Main script validation when supported.
- It avoids the unsafe `/ ?` command patterns called out in `AGENTS.md`.

Do not run:

- `AutoHotkeyUX.exe /?`
- `Ahk2Exe.exe /?`
- Raw AHK interpreter/compiler diagnostics without the wrapper.

### AHK helper tests

Relevant files:

- `tests\advisor_quote_helper_tests.ahk`
- `tests\parser_fixtures.ahk`
- `tests\message_tests.ahk`
- `tests\pricing_tests.ahk`
- `tests\date_tests.ahk`
- `tests\workflow_dryrun_tests.ahk`

These should be run only through the safe checker/wrapper path after confirming the checker supports the intended test target.

### Existing fixture coverage

Primary fixture file:

- `tests\fixtures\advisor_quote_operator\sanitized_dom_scenarios.json`

It includes sanitized DOM scenarios for Customer Summary, Product Overview, RAPPORT, Select Product, ASCPRODUCT Consumer Reports, Drivers/Vehicles, Incidents, Quote, stale rows, potential vehicles, and confirmed vehicles.

Coverage gap:

- The fixtures prove only the cases represented in sanitized JSON.
- Any new production failure should first become a sanitized fixture or scan-backed read-only assertion before mutating business logic.

## 9. Recommended continuation plan

### Phase 1: stabilize documentation and current-state map

- Treat this report plus `docs\PROJECT_ARCHITECTURE_AUDIT.md`, `docs\ADVISOR_JS_OPERATOR_CONTRACT.md`, and `ADVISOR_PRO_SCAN_WORKFLOW.md` as the current navigation set.
- Mark stale handoff docs as historical or update them to the current branch.
- Resolve doc/code tension around controlled vehicle add, stale row handling, and one-vehicle RAPPORT gate.

### Phase 2: improve read-only scan/state detection

- Prefer `advisor_state_snapshot`, `gather_rapport_snapshot`, and `asc_drivers_vehicles_snapshot` improvements before mutation changes.
- Add read-only fields for any production state that currently requires guessing.
- Preserve route/status names or add new fields in a backward-compatible way.

### Phase 3: add/repair tests and fixtures

- Add sanitized DOM fixtures for each newly observed production failure.
- Extend `tests\advisor_quote_ops_smoke.js` before changing mutation code.
- Add AHK helper tests for policy decisions such as gate behavior, stale row handling, and ledger next actions.

### Phase 4: migrate or isolate one transaction at a time

- Pick a single transaction boundary, for example stale Gather row cleanup or ASC inline participant save.
- Keep AHK-facing JS op names and result fields stable.
- Avoid moving multiple business flows in one patch.

### Phase 5: only then consider TypeScript/Playwright sidecar or productization layer

- Do not introduce a replacement operator or parallel workflow until current behavior is locked down by fixtures.
- A TypeScript/Playwright sidecar should be considered only as a separate productization layer after the AHK/JS contract is documented and guarded.
- It should not replace working AHK production behavior by default.

## 10. Immediate next patch candidates

1. Refresh docs that conflict with current branch behavior
   - Files likely involved:
     - `ADVISOR_PRO_SCAN_WORKFLOW.md`
     - `docs\PROJECT_ARCHITECTURE_AUDIT.md`
     - `docs\CURRENT_STATE_HANDOFF_FOR_NEW_CHAT.md`
     - `docs\RESTRUCTURE_TARGETS_AUDIT.md`
   - Reason: some docs still describe older branch state or older stale-row/unmatched-vehicle policy.
   - Risk level: low if documentation only.
   - Expected tests: none required beyond review; do not run AHK for docs-only changes.
   - Ordering: do this before behavior patches so future work uses the same map.

2. Add read-only fixture coverage for current RAPPORT gate and stale row behavior
   - Files likely involved:
     - `tests\advisor_quote_ops_smoke.js`
     - `tests\fixtures\advisor_quote_operator\sanitized_dom_scenarios.json`
     - possibly `tests\advisor_quote_helper_tests.ahk`
   - Reason: latest branch behavior around one-vehicle gate and stale row cleanup is high-risk and should be fixture-backed.
   - Risk level: medium.
   - Expected tests:
     - `node .\tests\advisor_quote_ops_smoke.js`
     - AHK checker only if AHK tests are changed.
   - Ordering: do after doc refresh and before changing RAPPORT mutation logic.

3. Run and record generated JS drift plus smoke validation
   - Files likely involved:
     - no source files unless drift is detected.
     - `assets\js\advisor_quote\ops_result.js` only if regenerated from source.
   - Reason: current branch changed both source and generated runtime in the latest commit. A fresh validation result should be captured before further JS edits.
   - Risk level: low for check-only, medium if regeneration is required.
   - Expected tests:
     - `node .\assets\js\advisor_quote\build_operator.js --check`
     - `node .\tests\advisor_quote_ops_smoke.js`
   - Ordering: do before any JS operator patch.

4. Audit Enter-sensitive scheduling/message paths
   - Files likely involved:
     - `adapters\quo_adapter.ahk`
     - `workflows\message_schedule.ahk`
     - `hotkeys\debug_hotkeys.ahk`
   - Reason: user safety rule specifically forbids plain Enter where `Ctrl+Alt+Enter` is required. Current schedule activation uses `^!{Enter}`, but plain Enter still appears in field submit/debug contexts.
   - Risk level: medium-high because it touches live UI automation.
   - Expected tests:
     - message/date parser tests if no live UI interaction is needed.
     - manual review of UI context checks before any behavioral edit.
   - Ordering: after doc refresh unless a live scheduling failure is the immediate issue.

5. Label or isolate legacy ASC/RAPPORT helper ownership
   - Files likely involved:
     - `workflows\advisor_quote_workflow.ahk`
     - `workflows\advisor\advisor_quote_rapport.ahk`
     - `workflows\advisor\advisor_quote_rapport_vehicles.ahk`
     - `docs\PROJECT_ARCHITECTURE_AUDIT.md`
   - Reason: newer ledger/snapshot flows coexist with legacy helpers. Future patches need an explicit ownership map to avoid editing dead or fallback paths accidentally.
   - Risk level: medium if comments/docs only, high if deleting or moving code.
   - Expected tests:
     - docs-only: review.
     - code comments only: build/check not required but smoke is prudent if touched files are parsed by AHK.
   - Ordering: after current validation, before any extraction/refactor.

## 11. Questions for the human / ChatGPT

These questions block safe development because they cannot be answered reliably from the repository alone:

1. Is `hermes-state-snapshot-foundation` the branch that should be treated as the production continuation branch, or should it first be compared/merged with `Hermes-branch` or `feature/advisor-resident-runner`?

2. Is the full Git LFS object for `data\vehicle_db_compact.json` available in the working environment? This matters before rebuilding `data\vehicle_db_runtime_index.tsv` or changing vehicle DB coverage.

3. Is the intended production policy now to proceed from RAPPORT after one safe confirmed/added vehicle and reconcile the remaining vehicles in ASC, or should every complete lead vehicle still be resolved in RAPPORT when possible?

4. Which latest sanitized trace/scan should be considered authoritative after commit `87c1bbe`? The next behavior patch should start from the latest failure code and snapshot, not from historical notes.

## 12. Files ChatGPT should inspect next

Paste these first for accurate continuation:

- `git status --short --branch`
- `git log --oneline -10`
- `docs\PROJECT_ARCHITECTURE_AUDIT.md`
- `ADVISOR_PRO_SCAN_WORKFLOW.md`
- `docs\ADVISOR_JS_OPERATOR_CONTRACT.md`
- `docs\ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`
- `domain\advisor_quote_db.ahk`
- `domain\advisor_vehicle_catalog.ahk`
- `workflows\advisor_quote_workflow.ahk`
- `workflows\advisor\advisor_quote_transport.ahk`
- `workflows\advisor\advisor_quote_product_overview.ahk`
- `workflows\advisor\advisor_quote_rapport.ahk`
- `workflows\advisor\advisor_quote_rapport_vehicles.ahk`
- `assets\js\advisor_quote\src\operator.template.js`
- `assets\js\advisor_quote\src\resident\command_bus.js`
- `tests\advisor_quote_ops_smoke.js`
- `tests\fixtures\advisor_quote_operator\sanitized_dom_scenarios.json`
- `tests\advisor_quote_helper_tests.ahk`

Paste summarized runtime evidence only, not raw PII-heavy logs:

- Tail summary of `logs\advisor_quote_trace.log`.
- Current failure code from `logs\run_state.json`, if present.
- Redacted/sanitized `logs\advisor_scan_latest.json`.
- Redacted/sanitized `logs\advisor_state_snapshot_latest.json`.
- Output of `node .\assets\js\advisor_quote\build_operator.js --check`.
- Output of `node .\tests\advisor_quote_ops_smoke.js`.
- If AHK checker is run, the exact command, pass/fail/skipped/timeout status, stdout summary, stderr summary, and artifact path from `logs\toolchain_checks\<timestamp>\`.

## Recommended next prompt

Review `CODEX_ARCHITECTURE_CONTINUATION_AUDIT.md`, then ask: "Using the continuation audit, refresh the stale Advisor documentation only. Do not change runtime behavior. Start with doc/code conflicts around RAPPORT vehicle gating, stale Gather rows, and generated JS ownership."
