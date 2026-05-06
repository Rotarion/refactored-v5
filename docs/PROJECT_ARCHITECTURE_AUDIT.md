# Project Architecture Audit

Consolidated: `2026-05-05`
Repository: `Final_V5.6_js_operator_refactor`
Scope: current implemented code and workflow impact only.

This document replaces the older one-off audits, migration plans, patch notes, source maps, risk logs, and discovery reports. Historical notes were merged here only when they still describe implemented behavior.

## Active Markdown Set

- `AGENTS.md`: repository rules and safety contract.
- `ADVISOR_PRO_SCAN_WORKFLOW.md`: scan-backed Advisor Pro selectors, text anchors, and workflow business rules.
- `docs/AHK_TOOLCHAIN_CHECKS.md`: required bounded AutoHotkey validation process.
- `docs/ADVISOR_GATHER_DATA_VEHICLE_ADD_NOTES.md`: stable Gather Data / Rapport vehicle prompt path, now a concise pointer to the DB-backed vehicle contract.
- `docs/ADVISOR_JS_OPERATOR_CONTRACT.md`: stable JS operator prompt path, now a concise pointer to the generated operator contract summary here.
- `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`: current DB-backed Rapport vehicle matching contract.
- `docs/PROJECT_ARCHITECTURE_AUDIT.md`: this current implementation overview.

## Entry Points

- Production bootstrap: `main.ahk`
- Advisor quote workflow hotkey: `Ctrl+Alt+-` / `^!-`
- Advisor quote entry function: `RunAdvisorQuoteWorkflowFromClipboard()`
- Emergency stop: `Esc`
- Exit: `F1`
- Configuration UI: `Ctrl+Alt+1`
- Batch lead workflows: `Ctrl+Alt+B` stable mode, `Ctrl+Alt+N` fast mode
- CRM/Blitz workflows: `Ctrl+Alt+K` attempted contact, `Ctrl+Alt+H` attempted contact for latest batch OK leads, `Ctrl+Alt+J` quote call

## Runtime Layout

```text
main.ahk
adapters/
  browser_focus_adapter.ahk
  clipboard_adapter.ahk
  crm_adapter.ahk
  devtools_bridge.ahk
  quo_adapter.ahk
  tag_selector_adapter.ahk
assets/js/
  advisor_quote/
    build_operator.js
    ops_result.js
    src/
  devtools_bridge/ops_result.js
  quo/ops_result.js
domain/
  advisor_quote_db.ahk
  advisor_vehicle_catalog.ahk
  batch_rules.ahk
  date_rules.ahk
  lead_normalizer.ahk
  lead_parser.ahk
  message_templates.ahk
  pricing_rules.ahk
hotkeys/
  crm_hotkeys.ahk
  debug_hotkeys.ahk
  lead_hotkeys.ahk
  schedule_hotkeys.ahk
tools/
  Invoke-AhkChecked.ps1
  Test-AhkToolchain.ps1
workflows/
  advisor_quote_workflow.ahk
  batch_run.ahk
  config_ui.ahk
  crm_activity.ahk
  message_schedule.ahk
  prospect_fill.ahk
  single_lead_create.ahk
```

Generated runtime artifacts belong under `logs/`. Advisor scan snapshots are written under `logs/advisor_scans/` with `logs/advisor_scan_latest.json` as the latest pointer.

## Include Order

`main.ahk` initializes settings and run state, then includes:

1. Domain modules for lead parsing, quote DB defaults, vehicle catalog matching, pricing/date/batch rules, and message templates.
2. Adapters for clipboard, browser focus, DevTools, Quo, CRM, and tag selector operations.
3. Workflows for lead creation, batch runs, message scheduling, prospect fill, Advisor quote, CRM activity, and config UI.
4. Hotkey modules.

Workflow impact: shared helpers and globals are available to hotkey workflows after startup. Changes to a domain or adapter module can affect multiple hotkeys, so workflow edits should remain narrow and independently verified.

## Advisor Quote Workflow

The implemented Advisor quote state sequence is:

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

Each state is run by `AdvisorQuoteRunStateWithRetries()` with bounded retries from `GetAdvisorQuoteWorkflowDb()["timeouts"]["maxRetries"]`. Each attempt captures an entry scan, calls the state handler, logs the result, and only retries when the result is marked retryable.

Workflow impact:

- The flow can resume from later page states because handlers first detect the current Advisor route/state.
- Customer Summary Overview is now a first-class bridge after create/select prospect.
- Product Overview Grid selection is separate from the older Select Product form.
- Rapport owns lead email, age-first-licensed defaults, vehicle handling, edit-panel completion, confirmed-card reconciliation, and Start Quoting validation.
- Drivers and Vehicles only reconciles quote membership. It does not create lead vehicles.
- Incidents chooses the configured animal/road-debris reason and continues.

## Advisor Quote Data Model

`BuildAdvisorQuoteLeadProfile()` produces the profile consumed by the quote workflow. Vehicle handling uses:

- `AdvisorNormalizeVehicleDescriptor()` for year/make/model/trim/VIN extraction.
- `AdvisorBuildVehicleDisplayKey()` for normalized display keys.
- `AdvisorBuildResidenceProfile()` for property/renter defaults from address shape.
- `AdvisorVehicleDbResolveLeadVehicle()` for DB-backed model alias and make-label resolution.
- `AdvisorVehicleDbBuildJsVehicleArgs()` to pass bounded vehicle DB results into the JS operator.

Workflow impact: JS does not load the vehicle DB directly. AHK performs the bounded lookup and passes only needed make labels, aliases, normalized model keys, and strict matching flags into the browser-side operator.

## Vehicle Catalog

The implemented catalog layer is `domain/advisor_vehicle_catalog.ahk`.

- Runtime DB path: `data/vehicle_db_runtime_index.tsv`
- Compact source data path: `data/vehicle_db_compact.json`
- Builder: `tools/build_vehicle_runtime_index.js`
- Fallback make-label logic remains for known families such as Toyota trucks, Ford trucks/vans, Chevrolet trucks/vans, Dodge/Ram, and Mercedes-Benz.

Workflow impact:

- Rapport confirmed-card matching can accept Advisor labels such as `TOY. TRUCKS` for compatible lead vehicles.
- Exact normalized model matching prevents overmatching pairs such as Prius/Prius Prime, Transit/Transit Connect, F150/F250, and CR-V/HR-V.
- Default Rapport vehicle mode is `match-existing-then-add-complete`: confirmed/potential Advisor evidence is preferred, then complete DB-resolved unmatched vehicles may use the controlled Add Car/Truck flow.
- `match-existing-only` remains supported for strict defer-only behavior. Partial, unknown, ambiguous, duplicate, or unsafe vehicle candidates are still deferred and excluded from missing expected reconciliation.
- Partial year/make vehicles are promoted only from unique VIN-bearing confirmed cards with visible model evidence.

## JavaScript Operator Contract

Runtime file: `assets/js/advisor_quote/ops_result.js`
Source template: `assets/js/advisor_quote/src/operator.template.js`
Build script: `assets/js/advisor_quote/build_operator.js`

The AHK bridge renders `@@OP@@` and `@@ARGS@@`, injects the generated single-file operator into DevTools, and receives either raw strings or key/value line blocks through `copy(String(...))`.

Current top-level Advisor operator groups:

- State and wait reads: `detect_state`, `wait_condition`, `scan_current_page`
- Prospect and duplicate handling: `focus_prospect_first_input`, `prospect_form_status`, `address_verification_status`, `handle_address_verification`, `handle_duplicate_prospect`
- Customer Summary/Product Overview: `customer_summary_overview_status`, `click_customer_summary_start_here`, `product_overview_tile_status`, `click_product_overview_tile`, `ensure_product_overview_tile_selected`, `click_product_overview_subnav_from_rapport`
- Read-only page snapshots: `advisor_active_modal_status`, `gather_rapport_snapshot`, `asc_drivers_vehicles_snapshot`
- Rapport defaults and vehicle handling: `fill_gather_defaults`, `gather_defaults_status`, `vehicle_already_listed`, `confirm_potential_vehicle`, `prepare_vehicle_row`, `gather_vehicle_row_status`, `set_vehicle_year_and_wait_manufacturer`, `select_vehicle_dropdown_option`, `gather_vehicle_add_status`, `gather_vehicle_edit_status`, `handle_vehicle_edit_modal`, `gather_confirmed_vehicles_status`, `gather_stale_add_vehicle_row_status`, `cancel_stale_add_vehicle_row`
- Start Quoting and Select Product: `gather_start_quoting_status`, `ensure_start_quoting_auto_checkbox`, `ensure_auto_start_quoting_state`, `click_create_quotes_order_reports`, `click_start_quoting_add_product`, `set_select_product_defaults`, `select_product_status`
- ASC Product: `consumer_reports_ready`, `asc_participant_detail_status`, `asc_resolve_participant_marital_and_spouse`, `asc_driver_rows_status`, `asc_reconcile_driver_rows`, `asc_vehicle_rows_status`, `asc_reconcile_vehicle_rows`, `fill_participant_modal`, `select_remove_reason`, `fill_vehicle_modal`, `handle_incidents`
- Generic helpers: `click_by_id`, `click_by_text`, modal and row status helpers
- Resident runner: `resident_runner_command`

Workflow impact:

- Snapshot ops are read-only route-specific status readers. They collect route family, active modal/panel, save gate, row/card counts, blocker codes, capped evidence, and missing fields without clicking, typing, saving, confirming, removing, creating quotes, or navigating.
- AHK wrappers `AdvisorQuoteGetActiveModalStatus()`, `AdvisorQuoteGetGatherRapportSnapshot()`, and `AdvisorQuoteGetAscDriversVehiclesSnapshot()` parse the snapshot key/value blocks and write trace events. The snapshots remain read-only; existing page action handlers still perform any clicks, fills, saves, removes, or updates.
- RAPPORT checks `gather_rapport_snapshot` before normal vehicle-loop work and routes an active Gather Edit Vehicle panel through the existing edit handler before continuing.
- Drivers/Vehicles is ledger-driven: each iteration reads `asc_drivers_vehicles_snapshot`, reads row/status details when no modal or panel blocks the page, builds an AHK ledger, chooses one action, verifies progress, and re-reads before choosing again.
- The Drivers/Vehicles ledger handles active ASC Remove Driver modals, inline participant panels, primary driver add, policy-driven spouse resolution, extra driver removal, ASC vehicle membership rows, and the final Save and Continue gate. Existing action ops still perform mutations; snapshots and ledger reads do not.
- Default ASC spouse policy is evidence-bound: exact spouse name still wins, Married can use a unique age-window Advisor-surfaced candidate, and Single/unknown can be overridden only when `ascSpouseOverrideSingleEnabled=true` and exactly one Advisor driver row within `ascSpouseAgeWindowYears` appears in the spouse dropdown. Ambiguity fails safe, same-last-name-only evidence is insufficient, and no external public-record lookup is used. The default remove-driver reason remains code `0006` / "This driver has their own car insurance".
- Page-level action handlers should check active modal/panel state before acting on the underlying page so open panels such as Gather Edit Vehicle, ASC inline participant details, and ASC Remove Driver are resolved before a lower-level handler chooses an action.
- Most high-risk browser mutations return key/value diagnostics so AHK can decide whether to continue, retry, or fail with an actionable scan path.
- `select_remove_reason` returns key/value diagnostics including `result`, `reasonCode`, `reasonSelected`, `clicked`, `method`, and `failedFields`; AHK clicks the remove modal save button only after the configured reason verifies selected.
- Several waits succeed from absence, especially modal-closed waits; callers must pair them with route/state evidence when risk is high.
- Argument names are part of the contract and should not be casually renamed: `wantedText`, `fieldName`, `index`, `incidentContinueId`, `ageFirstLicensed`, and `propertyOwnership` are used by AHK callers and smoke fixtures.

## Resident Runner

The resident runner exists but is disabled by default:

- `advisorQuoteResidentRunnerFeatureEnabled := false`
- `advisorQuoteResidentRunnerReadOnlyOnly := true`
- `advisorQuoteResidentRunnerUseTinyBridge := true`

Implemented commands include bootstrap/status/stop/reset/event reads and read-only polling. Mutating commands are refused when the read-only guard is active.

Workflow impact: production still uses the established per-op DevTools injection path unless the feature flag is explicitly enabled. The runner is an optimization path for bounded reads, not the default automation engine.

## DevTools Bridge

`adapters/devtools_bridge.ahk` focuses the browser, opens DevTools with `Ctrl+Shift+J`, prepares the console without sending `Esc`, saves/restores the clipboard, injects JS, submits with Enter only after focus/paste checks, and logs structured return diagnostics.

Important runtime behavior:

- `RunDevToolsJSGetResult()` retries once when an expected result is empty.
- Clipboard content is restored from `ClipboardAll()` after each bridge attempt when capture succeeds.
- Bridge return logs classify timeout, stale clipboard, empty result, error payload, stop-before-submit, and paste/submit state.

Workflow impact: browser-side operations are observable through bridge logs, and the bridge avoids the previous risk where internal `Esc` could trigger the global stop hotkey.

## CRM And Blitz Workflows

The CRM/Blitz path uses `assets/js/devtools_bridge/ops_result.js` through the same DevTools bridge.

Implemented browser ops include:

- `bridge_probe`
- `blitz_page_status`
- `focus_action_dropdown`
- `save_history_note`
- `add_new_appointment`
- `focus_date_time_field`
- `save_appointment`
- `get_blitz_current_lead_title`
- `click_blitz_next_lead`
- `open_blitz_lead_log_by_name`

Workflow impact: attempted-contact flows precheck the active Blitz page, log page status, and avoid running CRM actions unless the page is ready for the targeted action.

## Toolchain Safety

Do not run raw AutoHotkey interpreter/compiler diagnostics. Use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

The checker discovers local AutoHotkey candidates, selects a recommended interpreter, validates or guarded-loads smoke/main scripts through `tools/Invoke-AhkChecked.ps1`, and writes JSON artifacts under `logs/toolchain_checks/`.

Workflow impact: business-logic or workflow patches should not proceed until the bounded checker gives a structured result. Documentation-only changes do not require running the checker.

## Validation Surface

- JS operator smoke: `node .\tests\advisor_quote_ops_smoke.js`
- Snapshot smoke coverage checks active modal detection, Rapport snapshots, ASC Drivers/Vehicles snapshots, and fixture click counters proving these ops do not mutate the DOM.
- AHK helper tests: `tests/advisor_quote_helper_tests.ahk`
- Toolchain validation: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1`

Current known residual risk:

- Offline JS smoke fixtures validate string contracts and many DOM shapes but do not prove every live Advisor Pro layout.
- Click/fill/mutation ops remain live-layout sensitive.
- Advisor route ids under `/apps/ASCPRODUCT/{id}/` are dynamic and must not be hard-coded.
- Product Overview, Rapport Start Quoting, vehicle edit panels, spouse selection, and ASC reconciliation are the highest-impact live areas.

## Documentation Policy

Keep docs current-state focused:

- Put workflow selectors and user-confirmed business rules in `ADVISOR_PRO_SCAN_WORKFLOW.md`.
- Put architecture, module ownership, runtime contracts, and workflow impact here.
- Keep `docs/ADVISOR_JS_OPERATOR_CONTRACT.md` and `docs/ADVISOR_GATHER_DATA_VEHICLE_ADD_NOTES.md` as stable stub paths for prompts and audits.
- Put detailed DB-backed Rapport vehicle matching behavior in `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`.
- Put AutoHotkey diagnostic rules only in `docs/AHK_TOOLCHAIN_CHECKS.md` and `AGENTS.md`.
- Do not add patch-note markdowns for routine fixes. Merge durable behavior into one of the active docs instead.
