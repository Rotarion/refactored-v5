# Advisor Operator Discovery Report

## 1. Executive summary

The Advisor Pro quote automation starts from `Ctrl+Alt+-` in `hotkeys/lead_hotkeys.ahk:82`, which calls `RunAdvisorQuoteWorkflowFromClipboard()` in `workflows/advisor_quote_workflow.ahk:1`. That entry reads the current clipboard, builds a normalized Advisor lead profile with `BuildAdvisorQuoteLeadProfile()` from `domain/lead_parser.ahk:464`, starts the run state, loads selector/default data from `GetAdvisorQuoteWorkflowDb()` in `domain/advisor_quote_db.ahk:1`, then runs a fixed AHK state machine in `RunAdvisorQuoteWorkflow()` at `workflows/advisor_quote_workflow.ahk:33`.

Most Advisor page reads/clicks/fills are delegated from AHK into the browser by `AdvisorQuoteRunOp()` / `AdvisorQuoteRunJsOp()` in `workflows/advisor_quote_workflow.ahk:2169` and `:2173`. The workflow loads `assets/js/advisor_quote/ops_result.js` with `LoadJsAsset("advisor_quote/ops_result.js", true)` at `workflows/advisor_quote_workflow.ahk:2208`, replaces `@@OP@@` and `@@ARGS@@` through `RenderJsTemplate()` in `adapters/devtools_bridge.ahk:178`, pastes the rendered script into Edge DevTools Console, sends Enter, and waits for the JS to copy a return value back to the clipboard in `AdvisorQuoteExecuteBridgeJs()` at `workflows/advisor_quote_workflow.ahk:2282`.

The current contract is tightly coupled to raw strings (`OK`, `1`, `0`, `NO_BUTTON`, etc.) and `key=value` line blocks parsed by `AdvisorQuoteParseKeyValueLines()` at `workflows/advisor_quote_workflow.ahk:898`. Any JS refactor must preserve the single injected `ops_result.js` runtime file, the `@@OP@@` / `@@ARGS@@` template contract, all return strings, and the timing/clipboard behavior unless those are deliberately changed in a later, separately validated task.

## 2. Runtime flow map

1. User/hotkey/entrypoint: `^!-::RunAdvisorQuoteWorkflowFromClipboard()` in `hotkeys/lead_hotkeys.ahk:82`.
2. AHK workflow file/function: `RunAdvisorQuoteWorkflowFromClipboard()` in `workflows/advisor_quote_workflow.ahk:1` reads `A_Clipboard`, calls `BuildAdvisorQuoteLeadProfile()` (`domain/lead_parser.ahk:464`), `BeginAutomationRun()` (`adapters/clipboard_adapter.ahk:1`), `AdvisorQuoteInitTrace()` (`workflows/advisor_quote_workflow.ahk:2427`), and `GetAdvisorQuoteWorkflowDb()` (`domain/advisor_quote_db.ahk:1`).
3. State machine: `RunAdvisorQuoteWorkflow()` at `workflows/advisor_quote_workflow.ahk:33` runs `EDGE_ACTIVATION`, `ENTRY_SEARCH`, `ENTRY_CREATE_FORM`, `DUPLICATE`, `CUSTOMER_SUMMARY_OVERVIEW`, `PRODUCT_OVERVIEW`, `RAPPORT`, `SELECT_PRODUCT`, `CONSUMER_REPORTS`, `DRIVERS_VEHICLES`, `INCIDENTS`, and `QUOTE_LANDING`.
4. Adapter/bridge call: page actions route through `AdvisorQuoteRunOp()` (`workflows/advisor_quote_workflow.ahk:2169`) and `AdvisorQuoteRunJsOp()` (`:2173`). Generic non-Advisor bridge helpers live in `adapters/devtools_bridge.ahk`, but Advisor uses its own persistent Edge console bridge in the workflow file.
5. JS file loaded/injected: `AdvisorQuoteRenderOpJs()` loads `assets/js/advisor_quote/ops_result.js` at `workflows/advisor_quote_workflow.ahk:2206`.
6. Op name selected: AHK passes a string such as `detect_state`, `wait_condition`, or `fill_gather_defaults` into `Map("OP", String(op), "ARGS", args)` at `workflows/advisor_quote_workflow.ahk:2207`. JS reads `const op = @@OP@@;` in `assets/js/advisor_quote/ops_result.js:2`.
7. Args passed: AHK Maps/Arrays are serialized by `JsLiteral()` in `adapters/devtools_bridge.ahk:138`; JS reads `const args = @@ARGS@@ || {};` in `assets/js/advisor_quote/ops_result.js:3`.
8. Browser action performed: JS switch cases in `assets/js/advisor_quote/ops_result.js:1066` read DOM state, click elements, set fields, or return JSON/status strings.
9. Return value copied/read: the injected JS is wrapped in `copy(String(...))` behavior in the asset, and AHK waits for clipboard content different from the submitted JS at `workflows/advisor_quote_workflow.ahk:2322-2331`.
10. AHK parses result: raw string checks happen inline (`= "OK"`, `= "1"`), while structured results go through `AdvisorQuoteParseKeyValueLines()` at `workflows/advisor_quote_workflow.ahk:898`.
11. Workflow decides next step: `AdvisorQuoteResultOk()` and `AdvisorQuoteResultValue()` at `workflows/advisor_quote_workflow.ahk:90` and `:94` control the state retry/fail path; wait loops use `AdvisorQuoteWaitForCondition()` at `workflows/advisor_quote_workflow.ahk:2405`.

## 3. Connector / adapter map

| Adapter / connector | File | Main functions | Who calls it | External target | Failure modes | Relevant to JS refactor |
| --- | --- | --- | --- | --- | --- | --- |
| Browser focus | `adapters/browser_focus_adapter.ahk` | `FocusEdge()` `:1`, `FocusChrome()` `:10`, `FocusWorkBrowser()` `:19` | Advisor workflow, CRM, QUO, tag selector | Edge/Chrome window activation | Window not found; only process/window focus, not tab identity | High, because Advisor JS assumes Edge DevTools belongs to correct Advisor tab |
| Clipboard / run control | `adapters/clipboard_adapter.ahk` | `BeginAutomationRun()` `:1`, `StopRequested()` `:7`, `SafeSleep()` `:12`, `WaitForClip()` `:25`, `SetClip()` `:40`, paste helpers | All workflows and DevTools bridges | Windows clipboard and AHK Send | Clipboard timeout, StopFlag, clipboard overwritten | High, because op result transport is clipboard-backed |
| Advisor DevTools bridge | `workflows/advisor_quote_workflow.ahk` | `AdvisorQuoteEnsureConsoleBridge()` `:2214`, `AdvisorQuoteExecuteBridgeJs()` `:2282`, `AdvisorQuoteResetConsoleBridge()` `:2337` | Advisor op calls only | Edge DevTools Console | DevTools not focused, empty result, wrong tab, clipboard restore masking result | Critical |
| Generic DevTools bridge | `adapters/devtools_bridge.ahk` | `RunDevToolsJSInternal()` `:21`, `LoadJsAsset()` `:119`, `JsLiteral()` `:138`, `RenderJsTemplate()` `:178`, `RunDevToolsJsAssetWork()` `:199`, `RunDevToolsJsAssetEdge()` `:211` | CRM/Blitz, QUO, tag selector, and template utilities used by Advisor | Chrome/Edge DevTools Console | Clipboard timeout, missing JS asset, unresolved template token | Medium; Advisor reuses asset loading/template serialization, not generic execution |
| CRM / prospect fill / Blitz | `adapters/crm_adapter.ahk` | `FillNewProspectForm()` `:1`, `FillNationalGeneralForm()` `:67`, `CrmRunAttemptedContactAppointment()` `:148`, `CrmRunQuoteCallAppointment()` `:193`, Blitz helpers `:245-322` | Advisor prospect fill at `workflows/advisor_quote_workflow.ahk:880`; CRM workflows | Advisor/CRM form fields, Blitz iframe/pages | Tab order drift, clipboard failures, JS bridge failures, browser not found | Medium; `FillNewProspectForm()` is used inside Advisor create-prospect flow |
| QUO / OpenPhone-style composer | `adapters/quo_adapter.ahk` | `FocusSlateComposer()` `:1`, `EnsureParticipantInputReady()` `:13`, `QuoPrimeNewConversation()` `:70`, `QuoSelectLeadHolder()` `:108`, message schedulers `:143` and `:184` | Batch/single lead/message workflows | Browser chat composer | Unbounded `KeyWait` handoff at `:44-46` and `:63-65`; Enter send risk | Low for Advisor JS; important project-wide connector |
| Tag selector | `adapters/tag_selector_adapter.ahk` | `RunQuoTagSelector()` `:18`, `HandleQuoTagSelectorResult()` `:91`, `ApplyQuoTag()` `:116` | Batch/single lead/debug hotkeys | Browser tag UI and `assets/js/tag_selector.js` | Missing asset, blank selector result, browser focus lost, Enter send risk | Low for Advisor JS; shares generic DevTools pattern |
| Advisor selector/default DB | `domain/advisor_quote_db.ahk` | `GetAdvisorQuoteWorkflowDb()` `:1`, vehicle/address helpers `:95-353` | Advisor workflow and tests | Not an external app; source of selectors, URLs, text anchors, defaults | Stale selectors/text anchors; domain/config mixing | Critical input to JS op args |

## 4. Advisor Pro workflow map

Major execution order in `workflows/advisor_quote_workflow.ahk`:

| Order | Function | Role | JS ops called directly or through helpers |
| --- | --- | --- | --- |
| 1 | `RunAdvisorQuoteWorkflowFromClipboard()` `:1` | Clipboard parse, trace init, DB load | none |
| 2 | `RunAdvisorQuoteWorkflow()` `:33` | Fixed state sequence | none directly |
| 3 | `AdvisorQuoteStateEdgeActivation()` `:226` | Focus Edge, detect current Advisor state | `detect_state` via `AdvisorQuoteDetectState()` `:741` |
| 4 | `AdvisorQuoteStateEntrySearch()` `:239` | Click Quoting from Advisor home/gateway | `click_by_id`, `click_by_text`, `detect_state` |
| 5 | `AdvisorQuoteStateEntryCreateForm()` `:280` | Open/fill/submit Create New Prospect | `prospect_form_ready`, `focus_prospect_first_input`, `prospect_form_status`, `click_by_id`, `click_by_text`, `is_duplicate` |
| 6 | `AdvisorQuoteStateDuplicate()` `:378` | Resolve duplicate page | `handle_duplicate_prospect`, `duplicate_to_next` |
| 7 | `AdvisorQuoteStateCustomerSummaryOverview()` `:397` | Click `START HERE (Pre-fill included)` | `click_by_text`, `detect_state` |
| 8 | `AdvisorQuoteStateProductOverview()` `:430` | Select Auto tile and continue to Gather Data | `on_product_overview`, `click_product_overview_tile`, `click_by_text`, `gather_data` |
| 9 | `AdvisorQuoteStateRapport()` `:464` / `AdvisorQuoteHandleGatherData()` `:1038` | Fill Gather Data defaults, vehicles, Start Quoting | `gather_data`, `fill_gather_defaults`, `gather_defaults_status`, `vehicle_already_listed`, `confirm_potential_vehicle`, `prepare_vehicle_row`, `vehicle_select_enabled`, `select_vehicle_dropdown_option`, `vehicle_added_tile`, `gather_start_quoting_status`, `ensure_auto_start_quoting_state`, `click_create_quotes_order_reports`, `gather_start_quoting_transition`, `click_start_quoting_add_product` |
| 10 | `AdvisorQuoteStateSelectProduct()` `:482` / `AdvisorQuoteHandleSelectProduct()` `:1564` | Apply old Select Product form defaults | `on_select_product`, `set_select_product_defaults`, `select_product_status`, `click_by_id`, `click_by_text`, `select_product_to_consumer` |
| 11 | `AdvisorQuoteStateConsumerReports()` `:500` | Click Consumer Reports Yes | `consumer_reports_ready`, `click_by_id`, `click_by_text`, `drivers_or_incidents` |
| 12 | `AdvisorQuoteStateDriversVehicles()` `:513` / `AdvisorQuoteHandleDriversVehicles()` `:1776` | Add/remove drivers, add matching vehicles, fill modals | `drivers_or_incidents`, `list_driver_slugs`, `driver_is_already_added`, `vehicle_marked_added`, `find_vehicle_add_button`, `any_vehicle_already_added`, `modal_exists`, `fill_participant_modal`, `select_remove_reason`, `fill_vehicle_modal`, `add_asset_modal_closed`, `continue_enabled`, `after_driver_vehicle_continue` |
| 13 | `AdvisorQuoteStateIncidents()` `:526` | Select incident reason and continue | `is_incidents`, `handle_incidents`, `incidents_done` |
| 14 | `AdvisorQuoteStateQuoteLanding()` `:535` | Wait for quote landing | `quote_landing` |

Wait/retry loops:

- State retries: `AdvisorQuoteRunStateWithRetries()` at `workflows/advisor_quote_workflow.ahk:148`, up to `db["timeouts"]["maxRetries"]` from `domain/advisor_quote_db.ahk:58`.
- Observed state loop: `AdvisorQuoteWaitForObservedState()` at `workflows/advisor_quote_workflow.ahk:551`.
- Generic wait loop: `AdvisorQuoteWaitForCondition()` at `workflows/advisor_quote_workflow.ahk:2405`, with explicit `timeoutMs` and `pollMs`.
- Modal loop: `AdvisorQuoteHandleOpenModals()` at `workflows/advisor_quote_workflow.ahk:1923`, with explicit timeout and structured logs.

Scan/log creation:

- Trace log path is `advisorQuoteTraceFile := logsRoot "\advisor_quote_trace.log"` in `main.ahk:16`.
- Trace events append through `AdvisorQuoteAppendLog()` in `workflows/advisor_quote_workflow.ahk:2470`.
- Scans are created by `AdvisorQuoteScanCurrentPage()` at `workflows/advisor_quote_workflow.ahk:2491`, using the JS op `scan_current_page`.
- Latest scan is written to `logs/advisor_scan_latest.json`; archived scans use `logs/advisor_scan_<timestamp>_<label>_<reason>.json` in `AdvisorQuoteSaveScanSnapshot()` at `workflows/advisor_quote_workflow.ahk:2502`.

Page state is interpreted by `detect_state` in `assets/js/advisor_quote/ops_result.js:1067`, plus wait-condition predicates in `wait_condition` at `assets/js/advisor_quote/ops_result.js:1998`. AHK wraps these through `AdvisorQuoteDetectState()` at `workflows/advisor_quote_workflow.ahk:741`.

Quote/pricing data is not used by the Advisor JS operator. Pricing lives in `domain/pricing_rules.ahk` and batch/message tests; Advisor quote profile data comes from clipboard parsing in `BuildAdvisorQuoteLeadProfile()` (`domain/lead_parser.ahk:464`) and selector/default DB values in `domain/advisor_quote_db.ahk:1`.

Specific JS return-string dependencies include `OK`, `1`, `0`, `FAILED`, `PARTIAL`, `ERROR`, `AMBIGUOUS`, `NO_MATCH`, `NO_BUTTON`, `CLICK_FAILED`, `SELECT_EXISTING`, `CREATE_NEW`, `SELECTED_NO_CONTINUE`, and `FALLBACK_CONTINUE`; see sections 5 and 6.

## 5. JS operator contract inventory

Search terms used for callers: each op name, `AdvisorQuoteRunOp("`, `AdvisorQuoteWaitForCondition("`, `AdvisorQuoteRunJsOp`, `ops_result.js`, `@@OP@@`, `@@ARGS@@`.

| Op name | Category | Expected args | Return format | Success values | Failure values | AHK caller | Backward-compat risk | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `detect_state` | state | `urls`, `texts`, `selectors` | raw string | page-state names | `NO_CONTEXT`, empty via bridge | `AdvisorQuoteDetectState()` `workflows/advisor_quote_workflow.ahk:741` | high | Drives state machine routing |
| `click_product_overview_tile` | click | `urls`, `texts`, `selectors`, `productText` | raw string | `OK` | `NOT_OVERVIEW`, `NO_TILE`, `CLICK_FAILED` | `AdvisorQuoteHandleProductOverview()` `:1743` | high | Product overview grid bridge |
| `focus_prospect_first_input` | click/focus | none | `1`/`0` | `1` | `0` | `AdvisorQuoteFocusProspectFirstInput()` `:886` | medium | Fallback clicks text `First Name` |
| `prospect_form_status` | read | `selectors` | key=value block | `ready=1`, `submitPresent=1`, `submitEnabled=1` | empty fields/errors | `AdvisorQuoteGetProspectFormStatus()` `:893` | high | AHK validates every create-prospect field |
| `handle_duplicate_prospect` | matcher/click | first/last/street/zip/dob/phone/email | key=value block with `result=` | `SELECT_EXISTING`, `CREATE_NEW`, `SELECTED_NO_CONTINUE`, `FALLBACK_CONTINUE` | `FAILED`, `AMBIGUOUS_DUPLICATE`, `ERROR`, empty | `AdvisorQuoteHandleDuplicateProspect()` `:998` | high | Selecting/creating wrong prospect is operationally risky |
| `fill_gather_defaults` | fill | `emailValue`, `ageValue`, `ownershipValue`, `homeTypeValue` | key=value block | `result=OK`, accepted `PARTIAL` by AHK | `FAILED`, `ERROR`, empty | `AdvisorQuoteFillGatherDefaults()` `:1158` | high | AHK rejects `FAILED`, `ERROR`, empty only, then verifies status |
| `gather_defaults_status` | read/status | none | key=value block | values matching expected defaults | empty/mismatched values | `AdvisorQuoteGetGatherDefaultsStatus()` `:1198` | high | Readback validation after fill |
| `vehicle_already_listed` | matcher/read | year/make/model/trimHint/vin | `1`/`0` | `1` | `0` | `AdvisorQuoteVehicleAlreadyListed()` `:1401` | medium | Prevents duplicate vehicle creation |
| `confirm_potential_vehicle` | matcher/click | year/make/model/trimHint/vin | key=value block | `result=CONFIRMED` | `NO_MATCH`, `AMBIGUOUS`, `CLICK_FAILED` | `AdvisorQuoteConfirmPotentialVehicle()` `:1406` | high | Ambiguous match intentionally fails closed |
| `prepare_vehicle_row` | fill | `year` | raw index string or `-1` | non-negative integer | `-1`, non-numeric | `AdvisorQuotePrepareVehicleRow()` `:1493` | high | Starts progressive vehicle dropdown chain |
| `wait_vehicle_select_enabled` | wait/read | `index`, `fieldName`, `minOptions` | `1`/`0` | `1` | `0` | UNKNOWN; search found no AHK caller | low | Similar logic is used through `wait_condition` name `vehicle_select_enabled` |
| `select_vehicle_dropdown_option` | fill | `index`, `fieldName`, `wantedText`, `allowFirstNonEmpty` | raw string | `OK` | `NO_SELECT`, `NO_OPTION` | `AdvisorQuoteSelectVehicleDropdownOption()` `:1511` | high | Trim fallback uses first non-empty option |
| `gather_start_quoting_status` | read/status | `selectors` | key=value block | readback values | empty/mismatched values | `AdvisorQuoteGetGatherStartQuotingStatus()` `:1256` | high | Required before launching quote |
| `ensure_auto_start_quoting_state` | fill/status | `ratingState`, `selectors` | key=value block | `result=OK` | `result=FAILED`, `ERROR` | `AdvisorQuoteEnsureAutoStartQuotingState()` `:1522` | high | Sets Auto and rating state in Start Quoting block |
| `click_create_quotes_order_reports` | click | `selectors` | raw string | `OK` | `NO_BUTTON`, `DISABLED`, `CLICK_FAILED` | `AdvisorQuoteClickCreateQuotesOrderReports()` `:1530` | high | Main launch into Consumer Reports |
| `click_start_quoting_add_product` | click | `selectors` | raw string | `OK` | `NO_BUTTON`, `DISABLED`, `CLICK_FAILED` | `AdvisorQuoteOpenSelectProductFallbackFromGatherData()` `:1534` | medium | Fallback to old Select Product path |
| `set_select_product_defaults` | fill/status | product/rating/current insured/own-rent ids and texts | key=value block | `result=OK` or `PARTIAL` accepted by first AHK gate | `FAILED`, `ERROR`, empty | `AdvisorQuoteHandleSelectProduct()` `:1564` | high | AHK separately validates status |
| `select_product_status` | read/status | `texts`, `selectors`, product/rating ids | key=value block | values matching `AUTO`, `FL`, button enabled | empty/mismatched values | `AdvisorQuoteGetSelectProductStatus()` `:1638` | high | Readback and transition validation |
| `list_driver_slugs` | read | none | raw `||` list | non-empty list or empty accepted | empty | `AdvisorQuoteListDriverSlugs()` `:1837` | medium | Empty list means no driver action |
| `driver_is_already_added` | read | `slug` | `1`/`0` | `1` | `0` | `AdvisorQuoteDriverIsAlreadyAdded()` `:1859` | medium | Controls add-vs-modal handling |
| `vehicle_marked_added` | read/matcher | year/make/model | `1`/`0` | `1` | `0` | `AdvisorQuoteVehicleMarkedAdded()` `:1901` | medium | Drivers/Vehicles vehicle matching |
| `find_vehicle_add_button` | matcher | year/make/model/trimHint/vin | raw button id | button id | empty, `AMBIGUOUS` | `AdvisorQuoteFindVehicleAddButton()` `:1910` | high | Wrong id could add wrong vehicle |
| `any_vehicle_already_added` | read | none | `1`/`0` | `1` | `0` | `AdvisorQuoteAnyVehicleAlreadyAdded()` `:1919` | medium | Fallback success if at least one added |
| `modal_exists` | read/modal | `saveButtonId` | `1`/`0` | `1` | `0` | `AdvisorQuoteModalExists()` `:2033` | medium | Modal loop control |
| `fill_participant_modal` | fill/modal | age/email/military/violations/defensive/property/gender/spouse args | key=value block | `result=OK` | `FAILED`, `PARTIAL`, `ERROR` | `AdvisorQuoteFillParticipantModal()` `:2037` | high | AHK requires exactly `OK` |
| `select_remove_reason` | click/modal | `reasonCode` | raw string | `OK` | `NO_REASON` | `AdvisorQuoteSelectRemoveReason()` `:2084` | medium | Used before remove participant save |
| `fill_vehicle_modal` | fill/modal | `threshold` | key=value block | `result=OK` | `FAILED`, `ERROR` | `AdvisorQuoteFillVehicleModal()` `:2089` | high | Sets finance/garaging/recent purchase |
| `handle_incidents` | fill/click | `reasonText`, `incidentContinueId` | raw string | `OK` | `NO_REASON`, `NO_CONTINUE` | `AdvisorQuoteHandleIncidentsIfPresent()` `:2113` | high | Incident reason is business-specific |
| `click_by_id` | generic click | `id` | raw string | `OK` | `NO` | `AdvisorQuoteClickById()` `:2532` | high | Generic primitive used broadly |
| `click_by_text` | generic click | `text`, `tagSelector` | raw string | `OK` | `NO` | `AdvisorQuoteClickByText()` `:2546` | high | Generic primitive used broadly |
| `scan_current_page` | scan/read | `label`, `reason` | JSON string | JSON payload | empty/`result=ERROR` through catch | `AdvisorQuoteScanCurrentPage()` `:2491` | low | Diagnostic evidence only, but very useful |
| `wait_condition` | wait/read | `name` plus condition-specific args | `1`/`0` | `1` | `0` | `AdvisorQuoteWaitForCondition()` `:2405` | high | Inner names listed in section 8 |

## 6. Return-value dependency map

| Return value | JS op(s) that can return it | AHK consumer | Behavior |
| --- | --- | --- | --- |
| `OK` | `click_product_overview_tile`, `select_vehicle_dropdown_option`, `ensure_auto_start_quoting_state` as `result=OK`, `click_create_quotes_order_reports`, `click_start_quoting_add_product`, `set_select_product_defaults` as `result=OK`, `fill_participant_modal` as `result=OK`, `select_remove_reason`, `fill_vehicle_modal` as `result=OK`, `handle_incidents`, `click_by_id`, `click_by_text` | Many wrappers: `AdvisorQuoteClickById()` `:2532`, `AdvisorQuoteSelectVehicleDropdownOption()` `:1511`, modal handlers `:2037`, `:2084`, `:2089` | Usually success; some `key=value` `OK` values are then validated by readback status |
| `1` | focus/wait/read ops: `focus_prospect_first_input`, `vehicle_already_listed`, `wait_vehicle_select_enabled`, driver/vehicle/modal flags, `wait_condition` | `AdvisorQuoteWaitForCondition()` `:2405`, status helpers `:1401`, `:1859`, `:1901`, `:1919`, `:2033` | Boolean true |
| `0` | same boolean ops as above | same consumers | Boolean false; wait loops continue until timeout |
| `FAILED` | `handle_duplicate_prospect`, `fill_gather_defaults`, `ensure_auto_start_quoting_state`, `set_select_product_defaults`, `fill_participant_modal`, `fill_vehicle_modal`, helper `resultFromChecks()` | duplicate/gather/select/modal consumers at `:998`, `:1158`, `:1564`, `:2037`, `:2089` | Usually hard failure for that state; `PARTIAL` is sometimes tolerated, `FAILED` is not |
| `PARTIAL` | `fill_gather_defaults`, `set_select_product_defaults`, `fill_participant_modal` through `resultFromChecks()` | `AdvisorQuoteFillGatherDefaults()` `:1158`, `AdvisorQuoteHandleSelectProduct()` `:1564`, `AdvisorQuoteFillParticipantModal()` `:2037` | Gather/select first gate accepts non-FAILED then validates status; participant modal rejects anything other than `OK` |
| `ERROR` | catch block in `ops_result.js:2087`, returns `result=ERROR` | parsed by AHK where key=value expected; duplicate/gather/select handlers explicitly reject `ERROR` | Treat as failure with op/message/stack/url details in status map |
| `AMBIGUOUS` | `confirm_potential_vehicle`, `find_vehicle_add_button` | `AdvisorQuoteConfirmPotentialVehicle()` `:1406`, `AdvisorQuoteFindVehicleAddButton()` `:1910` | Potential vehicle ambiguity fails the Gather Data state; add-button ambiguity logs and skips that vehicle |
| `NO_MATCH` | `confirm_potential_vehicle` | `AdvisorQuoteConfirmPotentialVehicle()` `:1406` | Not a fatal result by itself; workflow falls back to adding a new vehicle row |
| `NO_BUTTON` | `click_create_quotes_order_reports`, `click_start_quoting_add_product` | `AdvisorQuoteHandleGatherData()` `:1116`, `AdvisorQuoteOpenSelectProductFallbackFromGatherData()` `:1534` | Produces specific failure reason and scan |
| `CLICK_FAILED` | `click_product_overview_tile`, `confirm_potential_vehicle`, `click_create_quotes_order_reports`, `click_start_quoting_add_product` | product overview `:1743`, vehicle confirm `:1406`, gather start quote `:1116`, fallback `:1538` | Treated as failed click; usually state failure |
| `SELECT_EXISTING` | `handle_duplicate_prospect` | `AdvisorQuoteHandleDuplicateProspect()` `:998` | Accepted; AHK waits for `duplicate_to_next` |
| `CREATE_NEW` | `handle_duplicate_prospect` | `AdvisorQuoteHandleDuplicateProspect()` `:998` | Accepted; AHK waits for `duplicate_to_next` |
| `SELECTED_NO_CONTINUE` | `handle_duplicate_prospect` | `AdvisorQuoteHandleDuplicateProspect()` `:998` | Not rejected immediately; likely times out unless page advances some other way |
| `FALLBACK_CONTINUE` | `handle_duplicate_prospect` | `AdvisorQuoteHandleDuplicateProspect()` `:998` | Accepted; AHK waits for `duplicate_to_next` |

Also observed: AHK checks `NO_ACTION` in `AdvisorQuoteHandleDuplicateProspect()` at `workflows/advisor_quote_workflow.ahk:1024`, but I did not find a JS return of `NO_ACTION` in `assets/js/advisor_quote/ops_result.js`. That appears to be a stale compatibility check.

## 7. Page-state detection map

State detection is implemented by helper predicates in `assets/js/advisor_quote/ops_result.js:249-356` and selected in `detect_state` at `assets/js/advisor_quote/ops_result.js:1067-1090`.

| State | JS function/op involved | URL/text/selectors used | AHK caller | Known fragility |
| --- | --- | --- | --- | --- |
| `CUSTOMER_SUMMARY_OVERVIEW` | `isCustomerSummaryOverviewPage()`, `detect_state` | URL contains `/apps/customer-summary/` and `/overview`; text has `START HERE (Pre-fill included)` plus `Quote History` or `Assets Details` | `AdvisorQuoteStateCustomerSummaryOverview()` `workflows/advisor_quote_workflow.ahk:397` | Text-dependent; start-here text may vary |
| `RAPPORT` | `isGatherDataPage()`, `detect_state` | URL contains `/rapport`, or body has `gather data` with vehicle field/add car marker | `AdvisorQuoteStateRapport()` `:464` | Gather text plus vehicle markers may be brittle |
| `PRODUCT_OVERVIEW` | `isProductOverviewPage()`, `detect_state` | URL `/apps/intel/102/overview`; text `Select Product`, `Auto`, `Save & Continue to Gather Data`; excludes create form | `AdvisorQuoteStateProductOverview()` `:430` | Text/tile layout dependent |
| `SELECT_PRODUCT` | `isSelectProductFormPage()`, `detect_state` | URL `/selectProduct` or Select Product text plus `SelectProduct.*` form controls | `AdvisorQuoteStateSelectProduct()` `:482` | Must distinguish old form from new product overview |
| `INCIDENTS` | `isIncidentsPage()`, `detect_state` | URL `/ASCPRODUCT/110/`; text `Incidents`; `CONTINUE_OFFER-btn` or animal/debris text | `AdvisorQuoteStateIncidents()` `:526` | Body text may include incident terms elsewhere |
| `ASC_PRODUCT` | `isAscProductPage()`, `detect_state` | URL `/ASCPRODUCT/110/`; any consumer reports, drivers/vehicles, incidents, or quote landing anchor | Consumer/driver/incidents states | Broad bucket by design; needs follow-up checks |
| `DUPLICATE` | `isDuplicatePage()`, `detect_state` | Body text `This Prospect May Already Exist` | `AdvisorQuoteStateDuplicate()` `:378` | Text-dependent; duplicate page can coexist with create form fields |
| `BEGIN_QUOTING_SEARCH` | `detect_state` | selector `outOfLocationCreateNewProspectButton` | `AdvisorQuoteStateEntryCreateForm()` `:280` | Depends on stable id |
| `BEGIN_QUOTING_FORM` | `detect_state` | selector `PrimaryApplicant-Continue-button` | `AdvisorQuoteStateEntryCreateForm()` `:280` | Depends on stable id |
| `ADVISOR_HOME` | `detect_state` | selector `group2_Quoting_button` | `AdvisorQuoteStateEntrySearch()` `:239` | Home UI selector dependent |
| `ADVISOR_OTHER` | `detect_state` | URL contains `advisorpro.allstate.com` | entry/edge activation | Broad; can misclassify an unsupported Advisor page |
| `GATEWAY` | `detect_state` | body contains `allstate advisor pro` | entry/edge activation | Very broad text evidence |
| `NO_CONTEXT` | `detect_state` fallback | none of the above | `AdvisorQuoteStateEdgeActivation()` `:226` | Correctly fails if Edge tab is not Advisor/Gateway |

## 8. Wait-condition map

All wait names live inside `wait_condition` in `assets/js/advisor_quote/ops_result.js:1998-2081` and are polled by `AdvisorQuoteWaitForCondition()` in `workflows/advisor_quote_workflow.ahk:2405`.

| Name | Waits for | Positive condition | Old-page-disappeared condition | Caller | Risk |
| --- | --- | --- | --- | --- | --- |
| `post_prospect_submit` | create form submit transition | URL rapport/selectProduct, product overview, or duplicate page | No | legacy `AdvisorQuoteHandleProspect()` `:841` | medium |
| `prospect_form_ready` | create prospect fields visible | all required selector ids visible | No | `AdvisorQuoteWaitForProspectFormReady()` `:850` | medium |
| `duplicate_to_next` | duplicate action transition | customer summary, gather, select product, product overview/form | No | `AdvisorQuoteHandleDuplicateProspect()` `:1035` | high |
| `gather_data` | Gather Data/Rapport ready | `isGatherDataPage()` | No | `AdvisorQuoteHandleGatherData()` `:1045`; product overview transition `:1757` | medium |
| `on_customer_summary_overview` | customer summary page | `isCustomerSummaryOverviewPage()` | No direct AHK caller found | low |
| `on_product_overview` | product overview grid | `isProductOverviewPage()` | No | `AdvisorQuoteHandleProductOverview()` `:1732` | medium |
| `to_select_product` | old select-product form | `isSelectProductFormPage()` | No | fallback from Gather Data `:1556` | medium |
| `gather_start_quoting_transition` | launch into ASC quote path | consumer reports, drivers/vehicles, incidents, or quote landing | No | `AdvisorQuoteHandleGatherData()` `:1130` | medium |
| `vehicle_added_tile` | added vehicle visible | `isVehicleAlreadyListedMatch(args)` | No | `AdvisorQuoteAddVehicleInGatherData()` `:1490` | high |
| `vehicle_confirmed` | confirmed potential vehicle visible | `isVehicleAlreadyListedMatch(args)` | No | `AdvisorQuoteConfirmPotentialVehicle()` `:1431` | high |
| `vehicle_select_enabled` | dependent dropdown enabled | field exists, not disabled, option count >= min | No | `AdvisorQuoteWaitForVehicleSelectEnabled()` `:1502` | high |
| `on_select_product` | old select-product form ready | `isSelectProductFormPage()` | No | `AdvisorQuoteHandleSelectProduct()` `:1572` | medium |
| `select_product_to_consumer` | old form Continue transition | consumer reports, drivers/vehicles, incidents, or quote landing | No | `AdvisorQuoteHandleSelectProduct()` `:1625` | medium |
| `consumer_reports_ready` | consent page | `isConsumerReportsPage()` | No | `AdvisorQuoteHandleConsumerReports()` `:1766` | medium |
| `drivers_or_incidents` | driver/vehicle or incidents | `isDriversAndVehiclesPage()` or `isIncidentsPage()` | No | `AdvisorQuoteHandleDriversVehicles()` `:1778`, consumer reports `:1773` | medium |
| `after_driver_vehicle_continue` | post driver/vehicle transition | incidents or quote landing | No | `AdvisorQuoteHandleDriversVehicles()` `:1799` | medium |
| `add_asset_modal_closed` | vehicle add modal closed | `ADD_ASSET_SAVE-btn` no longer exists | Yes: succeeds from absence of old modal button | `AdvisorQuoteHandleOpenModals()` `:2006` | high |
| `continue_enabled` | button enabled | button exists and not disabled | No | `AdvisorQuoteWaitForContinueEnabled()` `:2109` | medium |
| `incidents_done` | incidents continue transition | quote landing | No | `AdvisorQuoteHandleIncidentsIfPresent()` `:2125` | medium |
| `quote_landing` | quote-ready first page | `isQuoteLandingPage()` | No | `AdvisorQuoteWaitForQuoteLanding()` `:2128` | medium |
| `is_duplicate` | duplicate currently visible | duplicate text present | No | `AdvisorQuoteIsDuplicatePage()` `:2140` | low |
| `is_customer_summary_overview` | customer summary currently visible | customer summary predicate | No direct AHK caller found | low |
| `is_rapport` | Gather Data currently visible | gather predicate | No | `AdvisorQuoteIsOnRapportPage()` `:2145` | low |
| `is_product_overview` | product overview currently visible | product overview predicate | No direct AHK caller found | low |
| `is_select_product` | select product currently visible | select product predicate | No | `AdvisorQuoteIsOnSelectProductPage()` `:2150` | low |
| `is_asc` | ASC path currently visible | ASC predicate | No | `AdvisorQuoteIsOnAscProductPage()` `:2159` | low |
| `is_incidents` | incidents currently visible | incidents predicate | No | `AdvisorQuoteIsIncidentsPage()` `:2164` | low |

Flagged negative-evidence wait: `add_asset_modal_closed` succeeds when the old save button disappears. That may mean success, but it can also mean the DOM was replaced, the modal crashed, or the wrong page is active.

## 9. Data model / args map

| Data/args | Source | Path into JS ops |
| --- | --- | --- |
| Selectors | Hardcoded in `GetAdvisorQuoteWorkflowDb()` at `domain/advisor_quote_db.ahk:2-29` | Passed as `db["selectors"]` to `detect_state`, status ops, click ops, form/wait ops |
| URL contains values | Hardcoded in `domain/advisor_quote_db.ahk:61-67` | Passed as `db["urls"]` to `detect_state` and waits |
| Text anchors | Hardcoded in `domain/advisor_quote_db.ahk:69-84`; scan-backed docs in `ADVISOR_PRO_SCAN_WORKFLOW.md` | Passed as `db["texts"]` to state/product/select/incident ops |
| Timeouts | Hardcoded in `domain/advisor_quote_db.ahk:52-59` | AHK-only loop control; not usually sent to JS |
| Rating state/current insured/own-rent | Hardcoded defaults in `domain/advisor_quote_db.ahk:31-35` | `ensure_auto_start_quoting_state`, `set_select_product_defaults` |
| Consumer reports consent | Hardcoded default `yes` in `domain/advisor_quote_db.ahk:35`; selector id `orderReportsConsent-yes-btn` | AHK clicks by id/text; JS only generic click |
| Age first licensed | Hardcoded default `16` in `domain/advisor_quote_db.ahk:36` | `fill_gather_defaults`, `fill_participant_modal` |
| Gather own/rent and home type | Defaults in `domain/advisor_quote_db.ahk:37-39`; home type inferred by `AdvisorQuoteInferGatherHomeType()` `workflows/advisor_quote_workflow.ahk:1330` | `fill_gather_defaults` |
| Vehicle year/make/model/trim/VIN | Parsed from clipboard by `BuildAdvisorQuoteLeadProfile()` in `domain/lead_parser.ahk:496-525` and normalized by `AdvisorNormalizeVehicleDescriptor()` in `domain/advisor_quote_db.ahk:127` | `vehicle_already_listed`, `confirm_potential_vehicle`, `prepare_vehicle_row`, `select_vehicle_dropdown_option`, `find_vehicle_add_button`, `vehicle_marked_added` |
| Customer/prospect data | Clipboard raw row via `BuildAdvisorQuoteLeadProfile()` `domain/lead_parser.ahk:464`; prospect fields map returned at `:556` | Native AHK `FillNewProspectForm()` for create form; duplicate JS receives identity args |
| Email | Parsed lead field `person["email"]` at `domain/lead_parser.ahk:528-536` | `fill_gather_defaults`, `fill_participant_modal` |
| DOB/phone/address | Parsed lead profile `person`/`address` at `domain/lead_parser.ahk:528-544` | Duplicate matcher and native prospect fill |
| Current insured | `db["defaults"]["currentInsured"]` | `set_select_product_defaults` |
| Own/rent | `db["defaults"]["ownOrRent"]`; participant property ownership resolved by residence in `AdvisorQuoteResolveParticipantPropertyOwnership()` `workflows/advisor_quote_workflow.ahk:2074` | `set_select_product_defaults`, `fill_participant_modal` |
| Modal field values | Defaults in `domain/advisor_quote_db.ahk:40-49`; person gender/email from parsed lead | `fill_participant_modal`, `select_remove_reason`, `fill_vehicle_modal`, `handle_incidents` |
| Config INI values | `main.ahk:64-150` reads settings/timings/pricing/form delays; `config_ui.ahk` can edit | Mostly AHK sleep/timing, pricing/message, agent config. Advisor JS op args are mostly DB/profile, not INI direct |
| User input | Clipboard content and live active Edge page | Clipboard is parsed; live page DOM supplies scan/status results |

## 10. Tests and validation

| Test | What it tests | How to run | Requires live browser/Advisor Pro | Safe offline | Expand before refactor |
| --- | --- | --- | --- | --- | --- |
| `tests/advisor_quote_ops_smoke.js` | Executes `assets/js/advisor_quote/ops_result.js` in Node VM with fake DOM. Covers click helper submit behavior, `fill_gather_defaults` `OK/PARTIAL/FAILED`, vehicle matching, duplicate weak-match rejection | `node tests/advisor_quote_ops_smoke.js` | No | Yes | Yes, strongly. Add contract tests for every op return shape before splitting JS |
| `tests/advisor_quote_helper_tests.ahk` | Lead/profile parsing, vehicle normalization, residence classification, duplicate candidate scoring, spouse selection helper | Through approved wrapper only, for example `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-AhkChecked.ps1 ...` or repo checker if included | No | Mostly, but AHK toolchain required | Yes, add more profile/vehicle fixtures |
| `tests/workflow_dryrun_tests.ahk` | Batch lead dry-run plan, not Advisor state machine | Approved AHK wrapper only | No | Yes | Low for Advisor JS; useful for connector regressions |
| `tests/pricing_tests.ahk` | Pricing tiers | Approved AHK wrapper only | No | Yes | No direct Advisor JS impact |
| `tests/message_tests.ahk` | Message template/pricing token expansion | Approved AHK wrapper only | No | Yes | No direct Advisor JS impact |
| `tests/parser_fixtures.ahk` | Lead parser fixtures | Approved AHK wrapper only | No | Yes | Indirectly useful because Advisor profile starts here |
| `tests/date_tests.ahk` | Business date math | Approved AHK wrapper only | No | Yes | No direct Advisor JS impact |

Approved validation commands and safety:

- Do not run `AutoHotkeyUX.exe /?`.
- Do not run `Ahk2Exe.exe /?`.
- Do not run raw AutoHotkey checks without timeout wrapper.
- Normal repo validation command from `AGENTS.md` and `docs/AHK_TOOLCHAIN_CHECKS.md`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

- `tools/Invoke-AhkChecked.ps1` captures stdout/stderr and kills the process tree on timeout (`tools/Invoke-AhkChecked.ps1:45-63`, `:128-158`).
- `tools/Test-AhkToolchain.ps1` discovers candidates, prefers v2 interpreter, creates guarded wrapper scripts, and writes JSON artifacts under `logs/toolchain_checks` (`tools/Test-AhkToolchain.ps1:7-14`, `:61-99`, `:140-177`, `:180-209`).

I did not run validation during this discovery task because the requested output is a static report and no source behavior was changed.

## 11. Logs and evidence inventory

Logs are runtime evidence only, not canonical source.

| Category | Stored at | Useful evidence | Use as fixture? | Stay in logs or copy to fixtures? |
| --- | --- | --- | --- | --- |
| Advisor Pro trace | `logs/advisor_quote_trace.log` | State attempts, JS action names, wait polls, transition failures, duplicate decisions. Recent evidence on 2026-04-27 shows `ENTRY_SEARCH -> ENTRY_CREATE_FORM -> DUPLICATE`, `handle_duplicate_prospect` returning `CREATE_NEW`, then timeout/manual stop on `duplicate_to_next` | Good for scenario design, not direct fixture | Keep in logs; extract sanitized snippets into tests/fixtures if needed |
| Advisor scan latest | `logs/advisor_scan_latest.json` | Live DOM snapshot of duplicate/create form page, including headings, body sample, fields, radios, buttons | Very useful after sanitization | Keep in logs; copy sanitized minimal fixture into tests/fixtures before refactor |
| Toolchain checks | `logs/toolchain_checks/<timestamp>/*.json` | Prior validation results. Current repo contains artifacts whose embedded paths still reference `Final_V5.5_refactored`, so treat carefully | No | Keep in logs; do not use as canonical current validation |
| Syntax/test validation JSON | `logs/validate_*result.json` | Prior AHK validation pass/timeout evidence, also referencing `Final_V5.5_refactored` paths | No | Keep in logs |
| Pricing/message smoke scripts and outputs | `logs/pricing_*`, `logs/message_*`, `logs/*result.json` | Prior generated smoke harnesses and outputs | No, unless sanitized and intentionally moved | Keep in logs |
| Batch outputs | `logs/batch_lead_log.csv`, `logs/latest_batch_ok_leads.txt` | Batch runtime evidence and CRM replay inputs | Not for Advisor JS | Keep in logs |
| Run state | `logs/run_state.json` | Current/last automation state | No | Keep in logs |

Evidence caution: `hotkeys/debug_hotkeys.ahk:127-129` displays a hardcoded scan path under `Final_V5.5_refactored`; current repo path is `Final_V5.6_js_operator_refactor`. This is not part of the JS operator contract but is a drift risk for user-facing diagnostics.

## 12. Refactor risk assessment

AHK contract risk: high. AHK dispatches by exact op string, serializes args through `@@OP@@`/`@@ARGS@@`, and parses exact raw strings/key names. A modular rewrite that changes any return string, key name, or empty-result behavior will break state routing.

JS build/bundling risk: high. The runtime asset is loaded directly from `assets/js/advisor_quote/ops_result.js` at `workflows/advisor_quote_workflow.ahk:2208`. There is no existing build step. If modules are introduced without generating that exact single file, live automation breaks.

Selector/page detection risk: high. State detection is heuristic and text/URL/selector-based. Product overview vs select product form and ASC subpages are especially sensitive.

Return parsing risk: high. AHK parses `key=value` lines with a simple split in `AdvisorQuoteParseKeyValueLines()` at `workflows/advisor_quote_workflow.ahk:898`. Newline handling, `=` in values, renamed keys, or JSON returns would require AHK edits.

Test coverage risk: high. `tests/advisor_quote_ops_smoke.js` covers only a small subset of ops. Many critical ops (`detect_state`, `set_select_product_defaults`, modal fills, wait conditions, scans) do not have offline contract coverage.

DevTools bridge/clipboard risk: high. The bridge depends on the active Edge DevTools console, clipboard mutation, `Send "{Enter}"`, and result copy timing. Refactoring JS can increase script size/timing and expose empty-result failures.

Operational/live-quote risk: high. Wrong duplicate resolution, wrong vehicle matching, wrong modal defaults, or wrong incident selection can affect real customers/quotes. Be blunt: splitting the JS now without first freezing contract tests is unsafe.

## 13. Recommended refactor boundary

- Should `ops_result.js` remain the injected runtime file? Yes. It must remain the only file AHK injects until a later AHK contract change is explicitly approved.
- Should modular source live under `assets/js/advisor_quote/src/`? Yes, but only as source. A generated/built `assets/js/advisor_quote/ops_result.js` must remain byte-level or contract-level compatible.
- Should a build script generate `assets/js/advisor_quote/ops_result.js`? Yes, eventually. First add tests that prove generated output preserves the current op contract.
- Which files should not be touched in the first refactor? `main.ahk`, `hotkeys/*.ahk`, `workflows/advisor_quote_workflow.ahk`, `adapters/*.ahk`, `domain/advisor_quote_db.ahk`, and all live config/log files should be left alone except for deliberate minimal test/build wiring later.
- Which files may need minimal supporting edits? `tests/advisor_quote_ops_smoke.js` should expand first. A future build script/package file may be needed. `docs/` can hold the frozen contract.
- Which ops should be extracted first? Pure helpers and read-only/status logic: normalization, visibility, `linesOut`, `lineResult`, `detect_state` predicates, `gather_defaults_status`, `select_product_status`, `scan_current_page` helpers.
- Which ops should be left alone until later? `handle_duplicate_prospect`, `confirm_potential_vehicle`, `find_vehicle_add_button`, `fill_participant_modal`, `fill_vehicle_modal`, `handle_incidents`, and generic click primitives should wait until contract tests and live smoke checklist exist.

## 14. Proposed phased plan, but no implementation

1. Freeze/document op contract: turn section 5 into an executable fixture inventory; assert every op return shape.
2. Add source module structure: create `assets/js/advisor_quote/src/` only after tests exist; keep runtime output path unchanged.
3. Extract pure helpers: safe/string/normalization/result formatting helpers first.
4. Extract DOM/click/field helpers: visibility, click, native value setters, select/radio helpers.
5. Extract state/wait helpers: page predicates and wait-condition predicate functions.
6. Extract read-only/status ops: `detect_state`, `*_status`, `list_driver_slugs`, boolean read ops.
7. Extract fill/click ops: defaults, select product, generic click ops.
8. Extract vehicle/duplicate matchers: only after dedicated ambiguous/no-match fixtures.
9. Add tests: expand Node fake DOM tests for every op and return string; add sanitized scan fixtures.
10. Generate final single `ops_result.js`: build modules into the current injected runtime file.
11. Validate with approved tools: run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1`; run Node smoke; run AHK tests only through `tools/Invoke-AhkChecked.ps1` or the checker.
12. Manual live smoke checklist: verify Edge tab identity, DevTools bridge result copy, detect state on each page, duplicate create/select path, Gather defaults, vehicle add/confirm, Start Quoting, Select Product fallback, Consumer Reports, Drivers/Vehicles modals, Incidents, Quote Landing.

## 15. Open questions for Pablo

1. Should `SELECTED_NO_CONTINUE` from duplicate resolution continue to be accepted, or should it become a failure if no Continue button was clicked?
2. Is the current `CREATE_NEW` behavior on duplicate pages always preferred when no strong duplicate match exists, including former customer rows?
3. Can we create sanitized fixtures from `logs/advisor_scan_latest.json` and past Advisor scans for automated tests?
4. Should the debug scan MsgBox path still reference `Final_V5.5_refactored`, or is that a stale path that should be corrected in a later non-discovery task?
5. Are there live Advisor pages where `quote_landing` does not include `coverages`, `personalized quote`, `quote details`, or `your quote`?
6. Should `wait_vehicle_select_enabled` remain as an unused top-level op for compatibility, or can it be deprecated after tests prove no external caller exists?
