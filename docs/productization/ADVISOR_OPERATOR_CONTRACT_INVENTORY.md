# Advisor Operator Contract Inventory

Created: 2026-05-12
Branch: `hermes-state-snapshot-foundation`

This is a productization freeze inventory for Advisor Pro JavaScript ops that are called from AHK. It is documentation and test-guard source only; it does not authorize runtime behavior changes.

## Scope And Sources

Confirmed sources inspected:

- `docs/ADVISOR_JS_OPERATOR_CONTRACT.md`
- `docs/PROJECT_ARCHITECTURE_AUDIT.md`
- `ADVISOR_PRO_SCAN_WORKFLOW.md`
- `workflows/advisor_quote_workflow.ahk`
- `workflows/advisor/advisor_quote_transport.ahk`
- `workflows/advisor/advisor_quote_product_overview.ahk`
- `workflows/advisor/advisor_quote_rapport.ahk`
- `workflows/advisor/advisor_quote_rapport_vehicles.ahk`
- `workflows/advisor/advisor_quote_consumer_reports.ahk`
- `workflows/advisor/advisor_quote_entry.ahk`
- `workflows/advisor/advisor_quote_customer_summary.ahk`
- `assets/js/advisor_quote/src/operator.template.js`
- `assets/js/advisor_quote/build_operator.js`
- `tests/advisor_quote_ops_smoke.js`

Static search pattern used for this inventory:

- `AdvisorQuoteRunOp("...")`
- `AdvisorQuoteRunJsOp("...")`
- `AdvisorQuoteRunJsOpFullInjection("...")`
- `AdvisorQuoteWaitForCondition("...")` for `wait_condition` subconditions

Confirmed count: 62 unique top-level Advisor JS op names are called by AHK. The smoke guard `testAhkCalledAdvisorOperatorInventoryExistsInRuntime()` in `tests/advisor_quote_ops_smoke.js` asserts these 62 names still exist as `case` labels in generated runtime `assets/js/advisor_quote/ops_result.js`.

Post-classifier live recapture reference: `docs/productization/live_snapshot_evidence/2026-05-12/post_classifier_recapture/advisor_live_snapshot_recapture_findings_20260512.md`.

## Freeze Rules

- Preserve existing op names, route names, result strings, key/value field names, and JSON fields unless an AHK migration is made first.
- Do not edit `assets/js/advisor_quote/ops_result.js` by hand. Edit `assets/js/advisor_quote/src/operator.template.js` or snippets, then regenerate with `assets/js/advisor_quote/build_operator.js`.
- Route promotion in `advisor_state_snapshot` is read-only evidence. It does not authorize mutation by itself.
- Mutating ops remain gated by AHK route/status checks and post-action verification.

## AHK-Called Op Inventory

| Op | AHK caller file/function | Purpose | Kind | Expected result shape and high-risk contract |
|---|---|---|---|---|
| `address_verification_status` | `workflows/advisor/advisor_quote_entry.ahk` / `AdvisorQuoteGetAddressVerificationStatus()` | Read address-standardization modal/options before choosing. | Read-only | Key/value status. High-risk fields include `result`, entered/suggestion evidence, safe-match/ambiguity fields. |
| `advisor_active_modal_status` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteGetActiveModalStatus()` | Detect currently active Advisor modal/panel across routes. | Read-only | Key/value status with `activeModalType`, `activePanelType`, save/cancel fields, modal title, evidence, missing. Blockers include `GATHER_EDIT_VEHICLE`, `ASC_INLINE_PARTICIPANT_PANEL`, `ASC_REMOVE_DRIVER_MODAL`, `ASC_VEHICLE_MODAL`. |
| `advisor_state_snapshot` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteCaptureStateSnapshotRaw()` | Read-only route/status snapshot for debug hotkey and observer. | Read-only JSON | JSON with `route`, `confidence`, `anchors`, `blockers`, `product`, `selectProduct`, `ascDriversVehicles`, `prefillGate`, `rapport`, `iframe`, `allowedNextActions`, `unsafeReason`. Stable routes include `ENTRY_CREATE_FORM`, `CUSTOMER_SUMMARY_PREFILL_GATE`, `PRODUCT_OVERVIEW`, `RAPPORT`, `SELECT_PRODUCT`, `CONSUMER_REPORTS`, `ASC_DRIVERS_VEHICLES`, `COVERAGES`, `PURCHASE`, `ADVISOR_OTHER`, `UNKNOWN_UNSAFE`. |
| `any_vehicle_already_added` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteAnyVehicleAlreadyAdded()` | Check if any vehicle card appears added. | Read-only | Scalar `1`/`0`; used as a broad safety observation only. |
| `asc_driver_rows_status` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteGetAscDriverRowsStatus()` | Read ASC driver row ledger inputs. | Read-only | Key/value status with driver counts, unresolved/added/removed counts, summaries, save evidence, missing. |
| `asc_drivers_vehicles_snapshot` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteGetAscDriversVehiclesSnapshot()` | Route-level ASC Drivers/Vehicles snapshot and blocker reader. | Read-only | Key/value status with `result`, `routeFamily`, `ascProductRouteId`, `activeModalType`, `activePanelType`, `saveGate`, row counts, `blockerCode`, `blockers`, `nextRecommendedAction`, `nextRecommendedReadOnlyStatus`. |
| `asc_participant_detail_status` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteGetAscParticipantDetailStatus()` | Inspect inline participant panel fields/readiness. | Read-only | Key/value status with route id, save button state, marital/spouse/gender/default field evidence, missing fields. |
| `asc_reconcile_driver_rows` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteRunAscDriverReconcile()` | Add expected ASC drivers or remove extras according to AHK ledger policy. | Mutating | Key/value result. High-risk fields include `result`, `method`, `primaryAction`, `spouseAction`, `removedDrivers`, `unresolvedDrivers`, click counts, `failedFields`, evidence. |
| `asc_reconcile_vehicle_rows` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteRunAscVehicleReconcile()` | Add lead-matching ASC vehicle rows to quote. | Mutating | Key/value result with action/match detail, unresolved rows, click counts, failed fields. Must not remove extra vehicles. |
| `asc_resolve_participant_marital_and_spouse` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteResolveAscParticipantMaritalAndSpouse()` | Apply bounded marital/spouse selection policy in participant panel. | Mutating | Key/value result with spouse/marital method fields. High-risk statuses include exact spouse selection, unique age-window override, ambiguity/fail-safe. |
| `asc_vehicle_rows_status` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteGetAscVehicleRowsStatus()` | Read ASC vehicle row ledger inputs. | Read-only | Key/value status with vehicle counts, unresolved/added/removed counts, summaries, save evidence, missing. |
| `cancel_stale_add_vehicle_row` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteCancelStaleAddVehicleRow()` | Cancel stale Gather add row only when AHK has proved safe. | Mutating | Key/value result with `result`, cancel evidence, row safety fields. Unsafe rows must not be closed. |
| `click_by_id` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteClickById()` | Generic scoped click by id. | Mutating | Scalar `OK`, `NO_BUTTON`, `DISABLED`, `CLICK_FAILED`-style result. High risk because it can click arbitrary AHK-passed ids. |
| `click_by_text` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteClickByText()` | Generic scoped click by visible text/tag selector. | Mutating | Scalar click result. High risk because text matching must remain bounded by caller context. |
| `click_create_quotes_order_reports` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteClickCreateQuotesOrderReports()` | Click Rapport Start Quoting/Create Quotes button. | Mutating | Scalar `OK`, `NO_BUTTON`, `DISABLED`, `CLICK_FAILED`. Must be gated by Start Quoting status. |
| `click_customer_summary_start_here` | `workflows/advisor/advisor_quote_customer_summary.ahk` / `AdvisorQuoteClickCustomerSummaryStartHere()` | Click Customer Summary `START HERE`. | Mutating | Key/value status with result/click target/evidence. Must not run after the flow is already beyond Customer Summary. |
| `click_gather_add_row_add_button` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteClickGatherAddRowAddButton()` | Commit scoped Gather add-row after safe completion. | Mutating | Key/value result. High-risk fields include add button presence/enabled, clicked, row safety evidence. |
| `click_product_overview_subnav_from_rapport` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteClickProductOverviewSubnavFromRapport()` | Navigate back to Product Overview from Rapport recovery path. | Mutating | Key/value result with click/navigation evidence. |
| `click_product_overview_tile` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteHandleProductOverview()` | Select Auto tile on Product Overview grid. | Mutating | Scalar/key result such as `OK`, `NO_TILE`, `AMBIGUOUS`, `CLICK_FAILED`. Must remain scoped to Auto tile evidence. |
| `click_select_product_continue` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteHandleSelectProduct()` | Continue from Select Product fallback form. | Mutating | Key/value result with readiness/missing fields and `clicked`. Must require `READY`. |
| `click_start_quoting_add_product` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteClickStartQuotingScopedAddProduct()`, `AdvisorQuoteOpenSelectProductFallbackFromGatherData()` | Click scoped Add Product fallback from Start Quoting. | Mutating | Scalar `OK`, `NO_BUTTON`, `AUTO_NOT_SELECTED`, `DISABLED`, `CLICK_FAILED`. Must be gated by Start Quoting Auto selection. |
| `confirm_potential_vehicle` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteConfirmPotentialVehicle()` | Confirm one safely matched potential/public-record vehicle. | Mutating | Key/value result with `result`, `matches`, card text, score, match policy, VIN evidence, candidate scope, confirm click flag. Ambiguity must fail safe. |
| `customer_summary_overview_status` | `workflows/advisor/advisor_quote_customer_summary.ahk` / `AdvisorQuoteGetCustomerSummaryOverviewStatus()` | Read Customer Summary Overview / START HERE readiness. | Read-only | Key/value status with `result`, `runtimeState`, confidence, URL/overview/startHere/anchor match fields, evidence, missing. |
| `detect_state` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteDetectState()` | Fast route/state classifier used by the AHK state machine. | Read-only | Scalar route state. Stable states include `CUSTOMER_SUMMARY_OVERVIEW`, `DUPLICATE`, `RAPPORT`, `PRODUCT_OVERVIEW`, `SELECT_PRODUCT`, `INCIDENTS`, `ASC_PRODUCT`, `BEGIN_QUOTING_SEARCH`, `BEGIN_QUOTING_FORM`, `ADVISOR_HOME`, `ADVISOR_OTHER`, `GATEWAY`, `NO_CONTEXT`. |
| `driver_is_already_added` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteDriverIsAlreadyAdded()` | Check a driver slug/card is already added. | Read-only | Scalar `1`/`0`; slug contract is AHK-generated. |
| `ensure_auto_start_quoting_state` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteEnsureAutoStartQuotingState()` | Ensure Rapport Start Quoting Auto/rating-state/create-quote readiness. | Mutating | Key/value result with `autoApplied`, rating-state fields, Start Quoting status fields, missing. |
| `ensure_select_product_defaults` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteHandleSelectProduct()` | Apply Select Product fallback defaults. | Mutating | Key/value result with product/rating/effective date/current address/current insured/own-rent methods and missing fields. |
| `ensure_start_quoting_auto_checkbox` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteEnsureStartQuotingAutoCheckbox()` | Ensure Start Quoting Auto checkbox is checked. | Mutating | Key/value result with `autoPresent`, before/after checked state, clicked/direct-set flags. |
| `fill_gather_defaults` | `workflows/advisor/advisor_quote_rapport.ahk` / `AdvisorQuoteFillGatherDefaults()` | Fill Rapport people/property defaults. | Mutating | Key/value result with age/email/ownership/home type fields, method, failed fields, alerts. |
| `fill_participant_modal` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteFillParticipantModal()` | Fill ASC inline participant details. | Mutating | Key/value result with default field set flags, spouse/gender policy result, `failedFields`. |
| `fill_vehicle_modal` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteFillVehicleModal()` | Fill ASC vehicle add/details modal defaults. | Mutating | Key/value result with garaging/recent purchase/ownership clicked flags, detected year, failed fields. |
| `find_vehicle_add_button` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteFindVehicleAddButton()` | Locate one matching ASC vehicle add button. | Read-only | Scalar button id, empty, or `AMBIGUOUS`. Must not loosen vehicle matching. |
| `focus_prospect_first_input` | `workflows/advisor/advisor_quote_entry.ahk` / `AdvisorQuoteFocusProspectFirstInput()` | Focus first prospect input before native AHK field fill. | UI action | Scalar result. No data mutation, but it changes browser focus. |
| `gather_confirmed_vehicles_status` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteGetGatherConfirmedVehiclesStatus*()` | Compare expected vehicles with confirmed Gather cards. | Read-only | Key/value result with confirmed/missing/unresolved vehicle evidence. High-risk status excludes deferred vehicles after one-safe gate. |
| `gather_defaults_status` | `workflows/advisor/advisor_quote_rapport.ahk` / `AdvisorQuoteGetGatherDefaultsStatus()` | Verify Rapport defaults are filled. | Read-only | Key/value result with age/email/ownership/home type values and alerts. |
| `gather_rapport_snapshot` | `workflows/advisor/advisor_quote_rapport.ahk` / `AdvisorQuoteGetGatherRapportSnapshot()` | Read Gather/Rapport route, cards, panels, stale rows, save gate. | Read-only | Key/value status with `result`, `routeFamily`, `activeModalType`, `activePanelType`, `saveGate`, vehicle counts, stale row, `blockerCode`, `nextRecommendedReadOnlyStatus`, evidence, missing. |
| `gather_stale_add_vehicle_row_status` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteGetGatherStaleAddVehicleRowStatus()` | Inspect stale Gather add row safety/actionability. | Read-only | Key/value result with row present/safety, empty/incomplete/ambiguous evidence, duplicate confirmed evidence, dropdown option counts. |
| `gather_start_quoting_status` | `workflows/advisor/advisor_quote_rapport.ahk` / `AdvisorQuoteGetGatherStartQuotingStatus()` | Read Start Quoting block state. | Read-only | Key/value status with Auto selected/present, rating-state, create quote/add product button present/enabled, evidence, missing. |
| `gather_vehicle_add_status` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteGetGatherVehicleAddStatus()` | Read controlled Gather add-row state for a target vehicle. | Read-only | Key/value status with row/index, year/make/model/submodel values and option counts, add button state, duplicate-row evidence, missing. |
| `gather_vehicle_edit_status` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteGetGatherVehicleEditStatus()` | Read Gather edit vehicle panel readiness. | Read-only | Key/value result with year/make/model/submodel/VIN fields, required completeness, update button state, option counts. |
| `gather_vehicle_row_status` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteGetGatherVehicleRowStatus()` | Read a specific Gather add row. | Read-only | Key/value row status with cascade field values, disabled states, option summaries/counts, add button readiness. |
| `handle_address_verification` | `workflows/advisor/advisor_quote_entry.ahk` / `AdvisorQuoteResolveAddressVerification()` | Select safe address-verification option and continue. | Mutating | Key/value result with selected option, clicked, method, ambiguity/failure fields. |
| `handle_duplicate_prospect` | `workflows/advisor/advisor_quote_customer_summary.ahk` / `AdvisorQuoteHandleDuplicateProspect()` | Resolve duplicate/existing prospect page. | Mutating | Key/value result with method, candidate/row counts, selected row, continue clicked. Ambiguous duplicate selection must fail safe. |
| `handle_incidents` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteHandleIncidentsIfPresent()` | Select configured incident reason and continue. | Mutating | Scalar/key result; high-risk selector is configured incident reason text and continue button. |
| `handle_vehicle_edit_modal` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteHandleVehicleEditModal()` | Complete/update Gather edit vehicle modal. | Mutating | Key/value result with selected submodel, selection method, update button state/clicked, failed fields. |
| `list_driver_slugs` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteListDriverSlugs()` | Read driver action button slug candidates. | Read-only | Scalar `slug||slug`. Used by legacy driver resolution. |
| `modal_exists` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteModalExists()` | Check specific modal save button exists. | Read-only | Scalar `1`/`0`; caller passes save button id. |
| `prepare_vehicle_row` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuotePrepareVehicleRow()` | Open/prepare Gather add row and set year. | Mutating | Scalar row index or `-1`. Must remain bounded to requested year and usable row. |
| `product_overview_tile_status` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteGetProductOverviewTileStatus()` | Read Product Overview Auto tile status. | Read-only | Key/value status with present/selected/clickable/tile evidence. Mutating Product Overview actions must be gated by this evidence. |
| `prospect_form_status` | `workflows/advisor/advisor_quote_entry.ahk` / `AdvisorQuoteGetProspectFormStatus()` | Read create-new-prospect form readiness. | Read-only | Key/value status with required field presence/filled/mismatch and continue button state. |
| `resident_operator_bootstrap` | `workflows/advisor/advisor_quote_transport.ahk` / `AdvisorQuoteEnsureResidentOperator()` | Bootstrap browser resident operator command bus. | Transport/bootstrap | Key/value health/status with `result`, `version`, `buildHash`, op counts. Not a page mutation, but it mutates browser runtime globals. |
| `resident_runner_command` | `workflows/advisor/advisor_quote_transport.ahk` / `AdvisorQuoteRunnerCommand()` | Bridge commands to the resident read-only runner. | Transport | Key/value command result. Mutating commands are guarded/refused while read-only runner mode is active. |
| `scan_current_page` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteScanCurrentPage()` | Capture sanitized current-page scan JSON for diagnostics. | Read-only JSON | JSON with URL/title/headings/fields/buttons/radios/alerts/modal text samples. Output must stay out of git when raw/live. |
| `select_gather_add_row_first_valid_submodel` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteSelectGatherAddRowFirstValidSubModel()` | Narrow stale-row/edit-row submodel completion fallback. | Mutating | Key/value result with selected value/text/index, option count, applied flag. Must remain scoped to safe fallback policy. |
| `select_product_status` | `workflows/advisor/advisor_quote_product_overview.ahk` / `AdvisorQuoteGetSelectProductStatus()` | Read Select Product fallback form status. | Read-only | Key/value status with rating state, product, effective date, current address, currently insured, own/rent, continue enabled, missing fields. |
| `select_remove_reason` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteSelectRemoveReason()` | Select configured remove-driver reason in modal. | Mutating | Key/value diagnostics: `result`, `reasonCode`, `reasonSelected`, `clicked`, `method`, `failedFields`. AHK saves only after reason verifies selected. |
| `select_vehicle_dropdown_first_valid_nonplaceholder` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteSelectVehicleDropdownFirstValidNonPlaceholder()` | Select first valid option only in narrowly allowed dropdown contexts. | Mutating | Key/value result with selected value/text/index and applied flag. Broad model guessing remains forbidden. |
| `select_vehicle_dropdown_option` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteSelectVehicleDropdownOption*()` | Select bounded vehicle dropdown option. | Mutating | Scalar or key/value result. High-risk statuses include `NO_SELECT`, `NO_OPTION`, `AMBIGUOUS`, selected value/text/index, provisional gate fields. |
| `set_vehicle_year_and_wait_manufacturer` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteSetVehicleYearAndWaitManufacturer()` | Set Gather row year and wait for manufacturer dropdown readiness. | Mutating | Key/value status with year set/applied, manufacturer enabled/options, missing/failure fields. |
| `vehicle_already_listed` | `workflows/advisor/advisor_quote_rapport_vehicles.ahk` / `AdvisorQuoteVehicleAlreadyListed()` | Check whether a vehicle is already listed in Gather evidence. | Read-only | Scalar `1`/`0`; matching must remain bounded by year/make/model/VIN evidence. |
| `vehicle_marked_added` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteVehicleMarkedAdded()` | Check ASC/Gather vehicle appears added. | Read-only | Scalar `1`/`0`; AHK passes year/make/model. |
| `wait_condition` | `workflows/advisor_quote_workflow.ahk` / `AdvisorQuoteWaitForCondition()` | Poll read-only route/control conditions from AHK. | Read-only polling | Scalar `1`/`0` per poll. High-risk because subcondition names are a contract between AHK and JS. |

## Wait Condition Subcontract

`wait_condition` is a single top-level op, but AHK also depends on these literal condition names:

- `add_asset_modal_closed`
- `after_driver_vehicle_continue`
- `consumer_reports_ready`
- `continue_enabled`
- `drivers_or_incidents`
- `duplicate_to_next`
- `gather_data`
- `gather_start_quoting_transition`
- `incidents_done`
- `is_asc`
- `is_duplicate`
- `is_incidents`
- `is_rapport`
- `is_select_product`
- `on_product_overview`
- `on_select_product`
- `post_prospect_submit`
- `prospect_form_ready`
- `quote_landing`
- `select_product_to_consumer`
- `to_select_product`
- `vehicle_select_enabled`

These names should be treated as frozen AHK-to-JS contract strings. If a condition is renamed, update AHK callers, tests, and this inventory together.

## Ignore/Artifact Guard

`.gitignore` now explicitly excludes:

- logs and trace files: `logs/`, `*.log`, `*.trace`, `*.trace.json`, `traces/`
- Advisor scan/snapshot outputs: `advisor_scan_latest.json`, `advisor_state_snapshot_latest.json`, `advisor_scans/`, `advisor_state_snapshots/`
- screenshots/images likely to contain customer data: `screenshots/`, `*.png`, `*.jpg`, `*.jpeg`, `*.webp`
- raw lead/customer extracts: `*_raw_*.json`, `lead_raw_*.json`, `leads_raw_*.json`, `contacts_raw_*.json`, `messages_raw_*.json`, `conversations_raw_*.json`
- support/run bundles: `run_bundles/`, `support_packages/`, `support_zips/`, `support_bundles/`, `*_support.zip`, `*_support_*.zip`, `*support_package*.zip`, `*support_bundle*.zip`, `*run_bundle*.zip`

Tracked sanitized evidence under `docs/productization/live_snapshot_evidence/` remains documentation evidence. Do not add raw live scans, screenshots, trace bundles, support zips, raw leads, raw VINs, DOBs, emails, phones, addresses, or quote data.

## Validation

Contract guard command:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE .\tests\advisor_quote_ops_smoke.js
```

Generated runtime drift check:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE assets/js/advisor_quote/build_operator.js --check
```
