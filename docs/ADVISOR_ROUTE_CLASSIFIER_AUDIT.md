# Advisor Route Classifier Audit

Discovery date: 2026-04-27

Scope: current-source audit only. No runtime code, tests, config, hotkeys, adapters, CRM, QUO, pricing, messaging, or lead parsing were modified. Logs were inspected only as runtime evidence and no raw customer PII is reproduced here.

## 1. Executive summary

The current workflow does not have a single centralized route classifier. Route/state recognition is split across:

- JS `detect_state` in `assets/js/advisor_quote/src/operator.template.js:848`.
- JS `wait_condition` in `assets/js/advisor_quote/src/operator.template.js:1782`.
- AHK state handlers in `workflows/advisor_quote_workflow.ahk`, especially `AdvisorQuoteStateEntryCreateForm()` at line 289 and the later state functions.
- Domain URL/text/selector anchors in `domain/advisor_quote_db.ahk:2`, `:31`, `:61`, and `:69`.

The source is vulnerable to "expected one state, but browser is already ahead" failures. Some AHK handlers do accept ahead states, but only after `detect_state` has already returned a recognized runtime state. If the browser is physically on a known route but JS returns `ADVISOR_OTHER`, the AHK workflow often treats that as unexpected instead of asking for richer route evidence.

The current live failure fits this shape: the browser was on Customer Summary / Prefill Gate with customer-summary URL and visible START HERE / Quote History / Assets Details evidence, but the observed state was `ADVISOR_OTHER`. Once that happened in `ENTRY_CREATE_FORM`, the workflow failed rather than routing forward to `CUSTOMER_SUMMARY_OVERVIEW`.

Blunt diagnosis: the immediate weakness is not the ordered AHK state list. It is that route classification returns only a raw state string, and `ADVISOR_OTHER` has no diagnostic explanation or URL-family fallback.

## 2. Current route map from source

| Human label | Runtime state | URL pattern | Required page anchors | JS detector | JS wait_condition | AHK handler | Confidence | Known live scan evidence |
|---|---|---|---|---|---|---|---|---|
| Advisor Home | `ADVISOR_HOME` | `apps/foundations/101/homepage` or Advisor home shell | Quoting button id/text | inline `detect_state` branch using `advisorQuotingButtonId` | none dedicated | `AdvisorQuoteStateEdgeActivation()`, `AdvisorQuoteStateEntrySearch()` | medium | Trace shows home -> Begin Quoting transition. |
| Begin Quoting Search | `BEGIN_QUOTING_SEARCH` | `apps/intel/102/start` | `searchCreateNewProspectId` | inline `detect_state` branch | none dedicated | `AdvisorQuoteStateEntrySearch()` / `AdvisorQuoteOpenCreateNewProspectFromSearchResult()` | high | Latest bundle shows Begin Quoting search scan with Create New Prospect. |
| Create New Prospect Form | `BEGIN_QUOTING_FORM` | `apps/intel/102/start` | `beginQuotingContinueId`, prospect input ids | inline `detect_state` branch | `prospect_form_ready` | `AdvisorQuoteStateEntryCreateForm()` | high | Trace shows form ready/fill/submit path. |
| Duplicate / existing profile | `DUPLICATE` | duplicate/intermediate page | duplicate heading text | `isDuplicatePage()` | `is_duplicate`, `duplicate_to_next` | `AdvisorQuoteStateDuplicate()` | medium | Optional; not always present. |
| Prefill Gate | `CUSTOMER_SUMMARY_OVERVIEW` | `/apps/customer-summary/<dynamicId>/overview` | START HERE plus Quote History or Assets Details | `isCustomerSummaryOverviewPage()` | `on_customer_summary_overview`, `is_customer_summary_overview`, accepted by `post_prospect_submit` and `duplicate_to_next` | `AdvisorQuoteStateCustomerSummaryOverview()` | medium-high in code, failed live | Latest bundle contains customer-summary URL with START HERE, Quote History, Assets Details. |
| Product Tile Grid | `PRODUCT_OVERVIEW` | `/apps/intel/102/overview` | Select Product, Auto, Save & Continue to Gather Data | `isProductOverviewPage()` | `on_product_overview`, `is_product_overview` | `AdvisorQuoteStateProductOverview()` | high | Latest scan evidence shows Auto and Save & Continue on overview. |
| Gather Data | `RAPPORT` | `/apps/intel/102/rapport` | rapport URL, or Gather Data text plus vehicle field/add markers | `isGatherDataPage()` | `gather_data`, `is_rapport` | `AdvisorQuoteStateRapport()` | high | Prior flow evidence and tests cover rapport. |
| Select Product Form fallback | `SELECT_PRODUCT` | `/apps/intel/102/selectProduct` | Product/rating/current insured controls | `isSelectProductFormPage()` | `to_select_product`, `on_select_product`, `is_select_product` | `AdvisorQuoteStateSelectProduct()` | high | Source treats as Add Product fallback/alternate path. |
| ASC Consumer Reports | `ASC_PRODUCT` family, later `CONSUMER_REPORTS` AHK state | `/apps/ASCPRODUCT/<dynamicId>/...` | Order consumer reports text or yes consent button | `isConsumerReportsPage()` and `isAscProductPage()` | `consumer_reports_ready`, `gather_start_quoting_transition`, `select_product_to_consumer` | `AdvisorQuoteStateConsumerReports()` | medium | Fixtures still use fixed sample ids, domain now uses generic `/ASCPRODUCT/`. |
| ASC Drivers and Vehicles | `ASC_PRODUCT` family, AHK state `DRIVERS_VEHICLES` | `/apps/ASCPRODUCT/<dynamicId>/...` | Drivers and vehicles text plus continue/add/remove anchors | `isDriversAndVehiclesPage()` and `isAscProductPage()` | `drivers_or_incidents`, `after_driver_vehicle_continue` | `AdvisorQuoteStateDriversVehicles()` | medium | Fixtures cover drivers/vehicles. |
| ASC Vehicle Modal | modal over ASC route | `/apps/ASCPRODUCT/<dynamicId>/...` | vehicle modal fields/buttons | no state detector; modal ops only | `modal_exists`, `add_asset_modal_closed` | `AdvisorQuoteHandleOpenModals()`, `AdvisorQuoteFillVehicleModal()` | low-medium | Fixture coverage, no top-level route. |
| ASC Driver/Participant Modal | modal over ASC route | `/apps/ASCPRODUCT/<dynamicId>/...` | participant save id and participant fields | no state detector; modal ops only | `modal_exists` | `AdvisorQuoteHandleOpenModals()`, `AdvisorQuoteFillParticipantModal()` | low-medium | Fixture coverage. |
| ASC Remove Driver Modal | modal over ASC route | `/apps/ASCPRODUCT/<dynamicId>/...` | remove participant save id, reason controls | no state detector; modal ops only | `modal_exists` | `AdvisorQuoteHandleOpenModals()`, `AdvisorQuoteSelectRemoveReason()` | low | Out of current early-flow scope. |
| ASC Insurance History / Prior Insurance | ASC route family | `/apps/ASCPRODUCT/<dynamicId>/...` | insurance-history/prior-insurance fields | not clearly modeled as state detector | none found dedicated | no dedicated route handler found in current early-flow audit | low | Out of current patch scope. |
| ASC Incidents | `INCIDENTS` | `/apps/ASCPRODUCT/<dynamicId>/...` | Incidents text plus continue button or animal/road debris text | `isIncidentsPage()` | `is_incidents`, `incidents_done`, `after_driver_vehicle_continue` | `AdvisorQuoteStateIncidents()` | medium | Fixture coverage. |
| Quote Landing | `QUOTE_LANDING` in AHK, `ASC_PRODUCT` family via JS unless direct wait | `/apps/ASCPRODUCT/<dynamicId>/...` | coverages / personalized quote / quote details / your quote | `isQuoteLandingPage()`; `detect_state` returns `ASC_PRODUCT` before `QUOTE_LANDING` is possible because no `QUOTE_LANDING` branch exists | `quote_landing`, `incidents_done` | `AdvisorQuoteStateQuoteLanding()` | medium-low | Wait condition detects it; `detect_state` does not return `QUOTE_LANDING`. |

## 3. Current JS state detection audit

JS source: `assets/js/advisor_quote/src/operator.template.js`.

`detect_state` branch order at `operator.template.js:848-874`:

1. `CUSTOMER_SUMMARY_OVERVIEW`
2. `DUPLICATE`
3. `RAPPORT`
4. `PRODUCT_OVERVIEW`
5. `SELECT_PRODUCT`
6. `INCIDENTS`
7. `ASC_PRODUCT`
8. `BEGIN_QUOTING_SEARCH`
9. `BEGIN_QUOTING_FORM`
10. `ADVISOR_HOME`
11. `GATEWAY`
12. `NO_CONTEXT`
13. `ADVISOR_OTHER`

Detector details:

| Detector | URL conditions | Text/control conditions | Args dependencies | Safe fallback anchors | Known weakness |
|---|---|---|---|---|---|
| `isCustomerSummaryOverviewPage()` `operator.template.js:66` | `urls.customerSummaryContains` and `/overview` | START HERE and either Quote History or Assets Details | `urls`, `texts` | Defaults to literal START HERE, Quote History, Assets Details if args missing | Too all-or-nothing. A customer-summary URL with delayed/missing text returns false and collapses to `ADVISOR_OTHER`. |
| `isProductOverviewPage()` `:79` | `urls.productOverviewContains` | Select Product + Auto + Save & Continue; excludes create-form submit id | `urls`, `texts`, `selectors` | Literal default text anchors | Hardcoded intel 102 URL; Product Overview fails if label text changes. |
| `isSelectProductFormPage()` `:92` | `urls.selectProductContains` | Select Product heading plus product/rating/continue controls | `urls`, `texts`, `selectors` | URL alone can classify | Text fallback depends on stable control ids. |
| `isConsumerReportsPage()` `:105` | generic `/ASCPRODUCT/` via `ascProductContains` | order consumer reports text or consent yes id | `urls`, optional yes id | Consent button id | ASC sub-state only; no route diagnostics. |
| `isDriversAndVehiclesPage()` `:115` | generic `/ASCPRODUCT/` | Drivers and vehicles text plus continue/add/remove anchors | `urls` | add/remove/continue button selectors in DOM query | May miss pages where heading text differs. |
| `isIncidentsPage()` `:122` | generic `/ASCPRODUCT/` | Incidents heading plus continue id or animal/road debris text | `urls`, `texts` | incident continue id and fallback text | Specific incident text anchor may be brittle. |
| `isQuoteLandingPage()` `:139` | generic `/ASCPRODUCT/` | quote landing text; excludes consumer/drivers/incidents | `urls` | coverages / personalized quote / quote details / your quote | `detect_state` has no `QUOTE_LANDING` return branch; waits use it. |
| `isAscProductPage()` `:149` | generic `/ASCPRODUCT/` | one of consumer/drivers/incidents/quote landing anchors | `urls` | sub-detectors | ASC route with an unmodeled subpage returns false, then likely `ADVISOR_OTHER`. |
| `isGatherDataPage()` `:161` | `rapportContains` | or Gather Data text plus add car/vehicle fields, excluding Product Overview | `urls` | vehicle field marker | URL alone makes it broad; acceptable for current route. |

Specific answers:

- Why could `/apps/customer-summary/<id>/overview` return `ADVISOR_OTHER`? If `isCustomerSummaryOverviewPage()` returns false, none of the later detectors match the customer-summary route, and the final Advisor URL fallback returns `ADVISOR_OTHER`. False can happen if URL/text args are missing, the URL is observed before route/hash settles, body text is observed before START HERE/Quote History/Assets Details render, the page is observed from the wrong browser context/frame, or one of the required anchors changed.
- Is `customerSummaryContains` missing, stale, too strict, or not passed? In current source it is not missing and looks generic: `domain/advisor_quote_db.ahk:63` is `/apps/customer-summary/`. `AdvisorQuoteDetectState()` passes `urls`, `texts`, and `selectors` at `workflows/advisor_quote_workflow.ahk:755-761`. The anchor is not obviously stale.
- Does `isCustomerSummaryOverviewPage()` require exact text that may differ from the live page? It uses substring matching on lowercased body text. It requires the configured START HERE text and one of Quote History / Assets Details. Case and repeated whitespace are not the likely problem; missing/delayed/rendered-inaccessible text is.
- Is `detect_state` called with the same args as `scan_current_page`? No. `detect_state` is called with URL/text/selector args from AHK. `scan_current_page` is called with label/reason and reads the page independently; it does not prove `detect_state` saw identical args or identical DOM timing.
- Could bodyText/lowercase normalization cause `START HERE (Pre-fill included)` mismatch? Unlikely. `bodyText()` lowercases `document.body.innerText`; `includesText()` lowercases the expected string and performs substring matching.

Important current-source conclusion: if the latest scan payload and `detect_state` saw the same DOM at the same time, `isCustomerSummaryOverviewPage()` should have returned true. The live `ADVISOR_OTHER` therefore points to timing/context/anchor brittleness and the lack of a diagnostic route status, not a clearly wrong static URL anchor.

## 4. Current JS wait_condition audit

JS source: `operator.template.js:1782-1864`.

| Condition | Positive evidence | Accepts forward/ahead states | Negative evidence | Risk |
|---|---|---:|---:|---|
| `post_prospect_submit` | rapport URL, selectProduct URL, customer summary detector, product overview detector, duplicate detector | yes | no | medium |
| `prospect_form_ready` | all configured prospect required ids visible | no | no | medium |
| `duplicate_to_next` | customer summary, gather data, select product URL/form, product overview | yes | no | medium |
| `on_customer_summary_overview` | `isCustomerSummaryOverviewPage()` | no | no | medium-high |
| `on_product_overview` | `isProductOverviewPage()` | no | no | medium |
| `gather_data` | `isGatherDataPage()` | no | no | low-medium |
| `gather_start_quoting_transition` | consumer reports, drivers/vehicles, incidents, quote landing | yes | no | medium |
| `on_select_product` | `isSelectProductFormPage()` | no | no | low-medium |
| `select_product_to_consumer` | consumer reports, drivers/vehicles, incidents, quote landing | yes | no | medium |
| `consumer_reports_ready` | consumer reports detector | no | no | medium |
| `drivers_or_incidents` | drivers/vehicles or incidents | yes | no | medium |
| `after_driver_vehicle_continue` | incidents or quote landing | yes | no | medium |
| `add_asset_modal_closed` | absence of add asset save id | yes by absence | yes | high |
| `continue_enabled` | specific button exists and is enabled | no | no | low |
| `incidents_done` | quote landing detector | yes | no | medium |
| `quote_landing` | quote landing detector | no | no | medium |
| `is_customer_summary_overview` | customer summary detector | no | no | medium-high |
| `is_product_overview` | product overview detector | no | no | medium |
| `is_rapport` | gather data detector | no | no | low-medium |
| `is_select_product` | select product detector | no | no | low-medium |
| `is_asc` | ASC route-family detector | no | no | medium-high |
| `is_incidents` | incidents detector | no | no | medium |

Specific answers:

- `post_prospect_submit` does accept `CUSTOMER_SUMMARY_OVERVIEW` now via `isCustomerSummaryOverviewPage(args)`.
- `duplicate_to_next` accepts `CUSTOMER_SUMMARY_OVERVIEW`.
- `on_customer_summary_overview` uses the same detector as `detect_state`.
- Wait conditions are mostly aligned with the early route map, but ASC family handling is thin and `add_asset_modal_closed` succeeds from negative evidence only.

## 5. Current AHK workflow routing audit

AHK source: `workflows/advisor_quote_workflow.ahk`.

Current ordered state list in `RunAdvisorQuoteWorkflow()` at `workflows/advisor_quote_workflow.ahk:42-95`:

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

Key handlers:

- `AdvisorQuoteStateEntrySearch()` at `:248` accepts already-forward states through `INCIDENTS` at `:251`.
- `AdvisorQuoteStateEntryCreateForm()` at `:289` accepts `CUSTOMER_SUMMARY_OVERVIEW`, `PRODUCT_OVERVIEW`, `RAPPORT`, `SELECT_PRODUCT`, `ASC_PRODUCT`, `INCIDENTS`, and `DUPLICATE` as already satisfied at `:293-304`. It fails if the observed state is `ADVISOR_OTHER` at `:307-308`.
- `AdvisorQuoteStateDuplicate()` at `:387` safely skips when current state is not `DUPLICATE` at `:389-391`.
- `AdvisorQuoteStateCustomerSummaryOverview()` at `:406` skips if already at product/gather/select/ASC/incidents/quote at `:411-413`, but fails if current state is not `CUSTOMER_SUMMARY_OVERVIEW` at `:414-415`.
- `AdvisorQuoteStateProductOverview()` at `:439` skips if already at later states at `:444-446`, then requires `PRODUCT_OVERVIEW`.
- `AdvisorQuoteStateRapport()` at `:473` skips if already at select/ASC/incidents at `:475-477`, then handles Gather Data.
- `AdvisorQuoteStateSelectProduct()` at `:491` treats Select Product as fallback/alternate path and requires defaults before Continue.
- `AdvisorQuoteWaitForObservedState()` at `:560` polls raw `AdvisorQuoteDetectState()`.
- `AdvisorQuoteDetectState()` at `:755` calls JS `detect_state` with `urls`, `texts`, `selectors`.
- `AdvisorQuoteWaitForCondition()` at `:2508` polls JS `wait_condition`.
- Product Tile Auto flags are globals at `:7-8`; they are reset in `AdvisorQuoteInitTrace()` at `:2531-2535`, set only after verified overview selection and Gather Data transition at `:1861-1863`, and used to block bad Add Product fallback around `:1163-1184`.

Specific answers:

- Which states are allowed as "already past" in Entry Create Form? `CUSTOMER_SUMMARY_OVERVIEW`, `PRODUCT_OVERVIEW`, `RAPPORT`, `SELECT_PRODUCT`, `ASC_PRODUCT`, `INCIDENTS`, `DUPLICATE`.
- If `ENTRY_CREATE_FORM` observes `CUSTOMER_SUMMARY_OVERVIEW`, does it skip forward? Yes, if `detect_state` returns exactly `CUSTOMER_SUMMARY_OVERVIEW`.
- If `ENTRY_CREATE_FORM` observes `ADVISOR_OTHER` but the URL is customer-summary, does it fail? Yes. There is no AHK route-family fallback; the handler expects `BEGIN_QUOTING_FORM` or one of the known raw states.
- Does Duplicate safely skip if current state is already `CUSTOMER_SUMMARY_OVERVIEW`, `PRODUCT_OVERVIEW`, `RAPPORT`, `SELECT_PRODUCT`, or `ASC_PRODUCT`? Yes, because any non-`DUPLICATE` state exits success. It does not care which non-duplicate state it is.
- Is there a central function that can convert URL+anchors into a route? Not in AHK. JS has `detect_state`, but it returns a raw string only and loses evidence.
- Where should one be added? Add it first in JS as a read-only route/status op, then have AHK call it from `AdvisorQuoteDetectState()` or a wrapper function only when raw state is `ADVISOR_OTHER`/`UNKNOWN` or when a state handler wants ahead-state evidence.

## 6. Domain anchor audit

Domain source: `domain/advisor_quote_db.ahk`.

Relevant selectors:

- `advisorQuotingButtonId`: `group2_Quoting_button` at line 3.
- `searchCreateNewProspectId`: `outOfLocationCreateNewProspectButton` at line 4.
- `beginQuotingContinueId`: `PrimaryApplicant-Continue-button` at line 5.
- `sidebarAddProductId`: `addProduct` at line 15.
- `quoteBlockAddProductId`: `quotesButton` at line 16.
- `createQuotesButtonId`: `consentModalTrigger` at line 17.
- Select Product ids at lines 18-20.
- ASC/modal ids at lines 21-27.

Defaults:

- `ratingState`: `FL` at line 32.
- `currentInsured`: `YES` at line 33.
- `ownOrRent`: `OWN` at line 34.

URL contains values at lines 61-66:

- `rapportContains`: `/rapport`
- `customerSummaryContains`: `/apps/customer-summary/`
- `productOverviewContains`: `/apps/intel/102/overview`
- `selectProductContains`: `/selectProduct`
- `ascProductContains`: `/ASCPRODUCT/`

Text anchors at lines 69-83:

- `duplicateHeading`: `This Prospect May Already Exist`
- `customerSummaryStartHereText`: `START HERE (Pre-fill included)`
- `customerSummaryQuoteHistoryText`: `Quote History`
- `customerSummaryAssetsDetailsText`: `Assets Details`
- `productOverviewHeading`: `Select Product`
- `productOverviewAutoTile`: `Auto`
- `productOverviewContinueText`: `Save & Continue to Gather Data`
- Select Product current-insured question and Yes answer.
- Drivers/Incidents/consumer headings.

Specific answers:

- `ascProductContains` is now `/ASCPRODUCT/`, not a fixed id.
- `customerSummaryContains` is generic enough for dynamic customer-summary ids.
- `productOverviewContains`, `rapportContains`, and `selectProductContains` match the mapped flow. `productOverviewContains` is still tied to intel 102, but that matches current live evidence.
- Customer Summary text anchors match the latest scan evidence: START HERE, Quote History, and Assets Details were visible.

## 7. Proposed route classifier design

Recommended minimal design: add a read-only JS `route_status` op that wraps the existing detector helpers and returns key=value diagnostics. Do not replace `detect_state` yet.

Conceptual return shape:

```text
route=PREFILL_GATE
runtimeState=CUSTOMER_SUMMARY_OVERVIEW
urlFamily=customer-summary-overview
confidence=high
evidence=url:/apps/customer-summary/|url:/overview|text:START HERE|text:Quote History|text:Assets Details
missing=
url=...
```

Design recommendations:

- The route classifier should live in JS first because JS has direct access to URL, DOM text, fields, buttons, and visibility.
- AHK should use it through a wrapper such as `AdvisorQuoteGetRouteStatus()` and `AdvisorQuoteDetectStateWithRouteFallback()`.
- Keep existing `detect_state` as-is for compatibility. Do not break existing raw state contract.
- `route_status` should return key=value diagnostics, not a raw state only.
- AHK should continue using the state machine, but when `detect_state` returns `ADVISOR_OTHER` or `UNKNOWN`, it should ask `route_status`. If `route_status.runtimeState` is high-confidence and is in the accepted forward-state list, route forward.
- For known state handlers, use route status only as a guard/fallback; do not replace every call at once.
- Add clear scan/log evidence whenever route is unknown: current URL family, present anchors, missing anchors, and raw detect_state.

Why not replace `detect_state` immediately? The AHK and tests already depend on raw state strings. A wrapper preserves compatibility while giving the next patches better evidence.

## 8. Recommended patch phases

| Phase | Scope | Likely files changed | JS changes | AHK changes | Tests needed | Live validation | Risk |
|---|---|---|---:|---:|---|---|---|
| Patch 1 | Customer Summary / Prefill Gate detection and post-submit routing | `operator.template.js`, generated `ops_result.js`, smoke tests, maybe `workflow_dryrun_tests.ahk`, docs | yes | likely | Customer-summary route_status/status fixture; ENTRY_CREATE_FORM ADVISOR_OTHER fallback if practical | Submit prospect -> Prefill Gate recognized and START HERE clicked | medium |
| Patch 2 | Product Tile Grid selected-state verification if still failing | `operator.template.js`, smoke tests, docs | yes | maybe logging only | selected marker coverage from live diagnostics | Auto selected and verified on `/intel/102/overview` | medium |
| Patch 3 | Central route guard / ahead-of-state skip logic | `workflows/advisor_quote_workflow.ahk`, JS route op if not already added, tests | maybe | yes | helper tests for accepted forward states and ADVISOR_OTHER fallback | Already-ahead states route forward cleanly | medium-high |
| Patch 4 | ASC route-family sub-state classifier | `operator.template.js`, tests, docs | yes | maybe | fixtures for consumer, drivers, incidents, quote landing, modals | ASC dynamic id routes classified by page evidence | high |
| Patch 5 | ASC downstream handling: drivers, vehicles, remove-driver, participant details, prior/no-prior insurance | workflow + JS ops + fixtures/tests | yes | yes | modal/driver/vehicle/prior insurance fixtures | Full live ASC flow | high |

## 9. Exact recommended next patch

Next single patch recommendation: add a read-only `route_status` or narrower `customer_summary_overview_status` JS op, then use it from AHK only as a fallback when `ENTRY_CREATE_FORM` sees `ADVISOR_OTHER`/`UNKNOWN` after submit.

Answers:

- Should the next patch fix `isCustomerSummaryOverviewPage`? Yes, but preferably by adding diagnostics around it rather than only loosening it. It should expose which of `url`, `START HERE`, `Quote History`, and `Assets Details` matched/missed.
- Should it add `customer_summary_overview_status`? This is the smallest safe patch. It would directly solve the observed failure and keep scope tight.
- Should it add a broader `route_status` op? This is slightly better architecturally and helps future ASC routing, but it is a larger contract. If time is tight, start with `customer_summary_overview_status` and then generalize.
- Should Entry Create Form be changed to route forward on URL-family evidence? Yes, but only with high-confidence route evidence, not URL alone. Customer-summary URL plus START HERE plus one summary anchor should be enough.
- Should `post_prospect_submit` be changed? It already accepts customer summary via the same detector. If the issue is detector brittleness/timing, a status op with diagnostics is more useful than changing the boolean wait alone.
- Should Duplicate skip-forward behavior be changed? Not first. It already skips any non-duplicate raw state. It may benefit later from route fallback if raw state is `ADVISOR_OTHER` on a known forward route, but `ENTRY_CREATE_FORM` is the immediate failure point.

Recommended next patch title:

`Patch B1: Add Customer Summary Route Status And ENTRY_CREATE_FORM Forward Fallback`

Minimal expected behavior:

1. JS adds `customer_summary_overview_status` or `route_status`.
2. It returns key=value fields such as `runtimeState`, `confidence`, `urlMatched`, `startHereMatched`, `quoteHistoryMatched`, `assetsDetailsMatched`, `evidence`, `missing`.
3. AHK keeps `detect_state` untouched.
4. `AdvisorQuoteStateEntryCreateForm()` calls route-status fallback only when raw observed state is `ADVISOR_OTHER`/`UNKNOWN` after submit or at retry entry.
5. If high-confidence route status says `CUSTOMER_SUMMARY_OVERVIEW`, AHK returns success for `ENTRY_CREATE_FORM` with observed state `CUSTOMER_SUMMARY_OVERVIEW`.
6. The subsequent `CUSTOMER_SUMMARY_OVERVIEW` handler clicks START HERE and waits for `PRODUCT_OVERVIEW`.

## 10. Open questions for Pablo

1. In live Customer Summary / Prefill Gate, are `Quote History` and `Assets Details` always present, or should START HERE plus customer-summary overview URL be considered enough for high confidence?
2. If Customer Summary is recognized by URL plus START HERE but neither Quote History nor Assets Details is visible yet, should AHK wait briefly for anchors or route forward with medium confidence?
3. Should the next patch add the narrow `customer_summary_overview_status` first, or go straight to broader `route_status`?

## Patch B1 Follow-Up

Patch B1 implemented the narrow path recommended above. It added `customer_summary_overview_status` as a read-only Customer Summary / Prefill Gate diagnostic op and used it from AHK only when raw `detect_state` returns `ADVISOR_OTHER`, `UNKNOWN`, `NO_CONTEXT`, or blank during `ENTRY_CREATE_FORM` and `CUSTOMER_SUMMARY_OVERVIEW`.

The broader `route_status` classifier remains future work. Patch B1 intentionally does not rename runtime states, patch Product Tile selected-state detection, add ASC route-family classification, or change downstream ASC/109 behavior.
