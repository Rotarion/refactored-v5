# Advisor Prefill -> Product Tile Grid -> Gather Data Source Map

Discovery date: 2026-04-27

Scope: source extraction for the Advisor Pro early workflow from Begin Quoting through Prefill Gate, Product Tile Grid, Gather Data, Start Quoting, and Add Product fallback.

The original source-map pass was read-only. A later bounded early-flow patch updated workflow routing, Product Tile Grid verification, the ASC URL anchor, and JS status coverage; no adapters, config INI, hotkeys, CRM/QUO/messaging, lead parsing, or downstream ASC/109 driver/vehicle/insurance-history behavior were changed.

## 1. Live flow labels

Preferred human labels mapped to current runtime state names:

| Human label | Current runtime state | Notes |
|---|---|---|
| Prefill Gate | `CUSTOMER_SUMMARY_OVERVIEW` | Live URL shape: `#/apps/customer-summary/<dynamicId>/overview`. |
| Product Tile Grid | `PRODUCT_OVERVIEW` | Live URL shape seen in scan evidence: `#/apps/intel/102/overview`. |
| Gather Data | `RAPPORT` | Live URL shape seen in scan evidence: `#/apps/intel/102/rapport`. |

Do not rename runtime state names yet. The AHK workflow, JS operator tests, docs, and return contracts still depend on these exact strings.

## 2. Relevant files and functions

Primary workflow file: `workflows/advisor_quote_workflow.ahk`

| Function | Lines | Responsibility in this flow |
|---|---:|---|
| `RunAdvisorQuoteWorkflow()` | 40-90 | Ordered state runner for the full quote workflow. |
| `AdvisorQuoteStateEntrySearch()` | 246-285 | Opens Advisor Home / Quoting and routes toward Begin Quoting / Create New Prospect. |
| `AdvisorQuoteStateEntryCreateForm()` | 287-382 | Opens/submits Create New Prospect and accepts duplicate, prefill, product, gather, select, ASC, or incidents as forward progress. |
| `AdvisorQuoteStateDuplicate()` | 385-402 | Resolves duplicate/existing profile page if present. |
| `AdvisorQuoteStateCustomerSummaryOverview()` | 404-435 | Handles Prefill Gate by clicking `START HERE (Pre-fill included)`. |
| `AdvisorQuoteStateProductOverview()` | 437-469 | Calls Product Tile Grid handler and fails/retries on known failure codes. |
| `AdvisorQuoteStateRapport()` | 471-487 | Calls Gather Data handler. |
| `AdvisorQuoteWaitForObservedState()` | 558-569 | Polls `AdvisorQuoteDetectState()` until one of the accepted runtime states appears. |
| `AdvisorQuoteDetectState()` | 748-756 | Calls JS `detect_state`. |
| `AdvisorQuoteHandleDuplicateProspect()` | 1005-1042 | Calls JS `handle_duplicate_prospect` and waits for `duplicate_to_next`. |
| `AdvisorQuoteHandleGatherData()` | 1045-1163 | Fills Gather Data, handles vehicles, validates Start Quoting, clicks Create Quotes, or falls back to Add Product. |
| `AdvisorQuoteGetGatherStartQuotingStatus()` | 1263-1265 | Calls JS `gather_start_quoting_status`. |
| `AdvisorQuoteGatherStartQuotingStatusValid()` | 1299-1335 | Requires visible Start Quoting, Auto present/selected, rating state, Create Quotes present/enabled. |
| `AdvisorQuoteEnsureAutoStartQuotingState()` | 1529-1535 | Calls JS `ensure_auto_start_quoting_state`. |
| `AdvisorQuoteClickCreateQuotesOrderReports()` | 1537-1539 | Calls JS `click_create_quotes_order_reports`. |
| `AdvisorQuoteOpenSelectProductFallbackFromGatherData()` | 1541-1569 | Clicks Start Quoting Add Product and waits for Select Product. |
| `AdvisorQuoteHandleSelectProduct()` | 1571-1640 | Applies Select Product defaults and clicks Continue. |
| `AdvisorQuoteHandleProductOverview()` | current workflow source | Waits for Product Tile Grid, ensures Auto tile is selected idempotently, clicks Save & Continue only after selected-state verification, waits for Gather Data. |
| `AdvisorQuoteWaitForCondition()` | 2412-2432 | Polls JS `wait_condition`. |
| `AdvisorQuoteClickById()` | 2705-2717 | Generic AHK wrapper over JS `click_by_id`. |
| `AdvisorQuoteClickByText()` | 2719-2732 | Generic AHK wrapper over JS `click_by_text`. |

Domain/config source: `domain/advisor_quote_db.ahk`

JS operator source: `assets/js/advisor_quote/src/operator.template.js`; generated runtime is `assets/js/advisor_quote/ops_result.js`.

JS ops involved:

- `detect_state`
- `click_product_overview_tile`
- `wait_condition`
- `handle_duplicate_prospect`
- `gather_start_quoting_status`
- `ensure_auto_start_quoting_state`
- `click_create_quotes_order_reports`
- `click_start_quoting_add_product`
- `set_select_product_defaults`
- `select_product_status`
- generic `click_by_id` / `click_by_text`

## 3. Current state sequence

`RunAdvisorQuoteWorkflow()` runs states in this order (`workflows/advisor_quote_workflow.ahk:40-90`):

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

Findings:

- `CUSTOMER_SUMMARY_OVERVIEW` appears before `PRODUCT_OVERVIEW`.
- `PRODUCT_OVERVIEW` appears before `RAPPORT`.
- `SELECT_PRODUCT` appears after `RAPPORT`, as a fallback/alternate route after Gather Data or Product Overview.
- `DUPLICATE` appears after `ENTRY_CREATE_FORM` and before Prefill Gate.

Do not change this sequence in this discovery task.

## 4. Post-create routing

`AdvisorQuoteStateEntryCreateForm()` begins by detecting state (`workflows/advisor_quote_workflow.ahk:287-302`).

Accepted as already past/satisfied before fill/submit:

- `CUSTOMER_SUMMARY_OVERVIEW`
- `PRODUCT_OVERVIEW`
- `RAPPORT`
- `SELECT_PRODUCT`
- `ASC_PRODUCT`
- `INCIDENTS`
- `DUPLICATE`

When on `BEGIN_QUOTING_SEARCH`, it calls `AdvisorQuoteOpenCreateNewProspectFromSearchResult()` and again accepts the same forward states (`workflows/advisor_quote_workflow.ahk:294-302`).

When on `BEGIN_QUOTING_FORM`, it:

- waits for the prospect form to be ready (`AdvisorQuoteWaitForProspectFormReady()`, line 309),
- focuses/fills form fields (lines 314-319),
- checks for duplicate after first/second pass (lines 321-334),
- reads form status and validates required fields (lines 324-349),
- clicks the primary submit button via `AdvisorQuoteClickCreateProspectPrimaryButtonDetailed()` (line 352).

Submit target order is in `AdvisorQuoteClickCreateProspectPrimaryButtonDetailed()`:

```ahk
if AdvisorQuoteClickById(db["selectors"]["beginQuotingContinueId"], actionMs)
    return "id:" db["selectors"]["beginQuotingContinueId"]
if AdvisorQuoteClickByText("Create New Prospect", "button,a,input[type=button],input[type=submit]", actionMs)
    return "text:Create New Prospect"
if AdvisorQuoteClickByText("Continue", "button,a,input[type=button],input[type=submit]", actionMs)
    return "text:Continue"
```

Source: `workflows/advisor_quote_workflow.ahk:609-617`.

After submit, it waits for any of these observed states (`workflows/advisor_quote_workflow.ahk:359-369`):

- `DUPLICATE`
- `CUSTOMER_SUMMARY_OVERVIEW`
- `PRODUCT_OVERVIEW`
- `RAPPORT`
- `SELECT_PRODUCT`
- `ASC_PRODUCT`
- `INCIDENTS`

So current main routing does not assume duplicate must appear. It explicitly accepts Prefill Gate, Product Tile Grid, Gather Data, Select Product, ASC, or Incidents as forward progress.

Important caveat: older helper code around `AdvisorQuoteSubmitProspectForm()` uses JS wait condition `post_prospect_submit` (`workflows/advisor_quote_workflow.ahk:830-854`). That wait condition currently checks rapport URL, selectProduct URL, product overview, or duplicate. It does not directly check `CUSTOMER_SUMMARY_OVERVIEW`. I did not find that helper in the main `RunAdvisorQuoteWorkflow()` state path, but it is stale-looking and risky if reused.

Update: the bounded Customer Summary forwarding patch now treats `/apps/customer-summary/<dynamicId>/overview` with START HERE as an `ENTRY_CREATE_FORM` forward route. When this appears after Create New Prospect submission or while the create-form handler is retrying, the handler calls the scoped `click_customer_summary_start_here` op, waits for `PRODUCT_OVERVIEW` (`/apps/intel/102/overview`), and then leaves Auto tile selection to the existing Product Tile Grid handler. The sidebar Add Product path is still not used.

## 5. Duplicate handling

`AdvisorQuoteStateDuplicate()` detects current state with `AdvisorQuoteDetectState()` and exits successfully if the current state is not `DUPLICATE` (`workflows/advisor_quote_workflow.ahk:385-389`).

This means Duplicate safely skips when already on:

- `CUSTOMER_SUMMARY_OVERVIEW`
- `PRODUCT_OVERVIEW`
- `RAPPORT`
- `SELECT_PRODUCT`
- or any other non-`DUPLICATE` detected state

If state is `DUPLICATE`, it calls `AdvisorQuoteHandleDuplicateProspect()` (`workflows/advisor_quote_workflow.ahk:391`).

`AdvisorQuoteHandleDuplicateProspect()`:

- sends first/last/street/zip/DOB/phone/email to JS `handle_duplicate_prospect` (`workflows/advisor_quote_workflow.ahk:1005-1017`);
- parses key=value return lines;
- treats these as failure: `NO_ACTION`, `FAILED`, `AMBIGUOUS_DUPLICATE`, `ERROR`, empty (`workflows/advisor_quote_workflow.ahk:1031-1032`);
- treats any other result as action success and waits for JS wait condition `duplicate_to_next` (`workflows/advisor_quote_workflow.ahk:1034-1042`).

This means:

- `SELECT_EXISTING` routes forward if `duplicate_to_next` becomes true.
- `CREATE_NEW` routes forward if `duplicate_to_next` becomes true.
- `SELECTED_NO_CONTINUE` is treated as success by the result filter, then depends on `duplicate_to_next`.

`duplicate_to_next` returns `1` when JS sees:

- `CUSTOMER_SUMMARY_OVERVIEW`
- `RAPPORT`
- URL contains selectProduct
- `PRODUCT_OVERVIEW`
- `SELECT_PRODUCT`

Source: `assets/js/advisor_quote/src/operator.template.js:1717-1718`.

Risk: `SELECTED_NO_CONTINUE` can be considered a successful duplicate action by AHK, but if no page transition follows then `duplicate_to_next` times out and the state fails. That behavior is probably intentional, but should be tested against live duplicate variants.

## 6. Prefill Gate handler

`AdvisorQuoteStateCustomerSummaryOverview()` maps to the human label Prefill Gate.

Detection:

- AHK calls `AdvisorQuoteDetectState()`.
- JS `detect_state` returns `CUSTOMER_SUMMARY_OVERVIEW` when `isCustomerSummaryOverviewPage()` is true.
- `isCustomerSummaryOverviewPage()` requires:
  - URL contains configured `customerSummaryContains` (`/apps/customer-summary/`);
  - URL contains `/overview`;
  - body includes configured `customerSummaryStartHereText` (`START HERE (Pre-fill included)`);
  - body includes `Quote History` or `Assets Details`.

Source: `assets/js/advisor_quote/src/operator.template.js:66-77`.

If already on a later state, the handler exits successfully (`workflows/advisor_quote_workflow.ahk:409-411`):

- `PRODUCT_OVERVIEW`
- `RAPPORT`
- `SELECT_PRODUCT`
- `ASC_PRODUCT`
- `DRIVERS_VEHICLES`
- `INCIDENTS`
- `QUOTE_LANDING`

If current state is not `CUSTOMER_SUMMARY_OVERVIEW`, it fails (`workflows/advisor_quote_workflow.ahk:412-413`).

Click behavior:

- Logs action `click-start-here`.
- Calls `AdvisorQuoteClickByText(db["texts"]["customerSummaryStartHereText"], "button,a,[role=button]", actionMs)`.
- This reaches JS `click_by_text`, which finds the first visible `button,a,[role=button]` whose text includes the wanted text, then calls `clickEl()`.

Sources:

- AHK call: `workflows/advisor_quote_workflow.ahk:415-419`
- AHK click wrapper: `workflows/advisor_quote_workflow.ahk:2719-2732`
- JS `click_by_text`: `assets/js/advisor_quote/src/operator.template.js:1585-1591`

Wait after START HERE:

- Waits for observed state in `["PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"]`.
- It does not require `PRODUCT_OVERVIEW` specifically.
- It accepts direct Gather Data or Select Product as forward progress.

Source: `workflows/advisor_quote_workflow.ahk:421-431`.

Scan evidence, sanitized:

- Run bundle `logs/advisor_scans/advisor_scan_run_20260427-152931-787.json` contains customer-summary overview URL before `#/apps/intel/102/overview`.
- Standalone scan `logs/102 overview.json` structurally shows Product Tile Grid controls after Prefill Gate routing, including `START HERE (Pre-fill included)`, `Add Product`, and `Save & Continue to Gather Data`. Customer-specific heading/text values are intentionally not reproduced here.

Risks:

- The click is text-based and uses substring matching, not exact matching.
- The scan evidence showed multiple `START HERE (Pre-fill included)` visible button texts. The current code clicks the first visible match; it does not disambiguate by section/container.
- The handler waits for Product Overview or later, so accidental navigation to Select Product/ASC could still be treated as successful forward progress.
- It should not click Add Product directly from this handler because it searches for START HERE text, but a malformed DOM/duplicate text could still produce a wrong first match.

Update: START HERE routing now uses `click_customer_summary_start_here`, which first verifies the Customer Summary overview route, filters targets to visible START HERE controls, excludes Add Product, prefers an actionable button/input over the sidebar link when both are visible, and then waits specifically for `PRODUCT_OVERVIEW`. The Product Tile Grid still must select and verify Auto before Save & Continue.

## 7. Product Tile Grid handler

Product Tile Grid maps to runtime state `PRODUCT_OVERVIEW`.

Detection:

`isProductOverviewPage()` requires:

- URL contains `productOverviewContains` (`/apps/intel/102/overview`);
- body includes `Select Product`;
- body includes `Auto`;
- body includes `Save & Continue to Gather Data`;
- `beginQuotingContinueId` is not visible;
- not customer summary overview.

Source: `assets/js/advisor_quote/src/operator.template.js:79-90`.

`AdvisorQuoteStateProductOverview()`:

- exits successfully if already on `RAPPORT`, `SELECT_PRODUCT`, `ASC_PRODUCT`, or `INCIDENTS`;
- fails if not on `PRODUCT_OVERVIEW`;
- calls `AdvisorQuoteHandleProductOverview()`.

Source: `workflows/advisor_quote_workflow.ahk:437-450`.

`AdvisorQuoteHandleProductOverview()` flow:

1. Waits for JS wait condition `on_product_overview`.
2. Sets `advisorQuoteProductOverviewAutoPending := false`.
3. Calls JS op `click_product_overview_tile` with product text `Auto`.
4. If result is `NO_TILE`, returns `AUTO_TILE_NOT_FOUND`.
5. If result is not `OK`, returns `AUTO_TILE_CLICK_FAILED`.
6. Sleeps `shortMs`.
7. Clicks `Save & Continue to Gather Data` by text.
8. Waits for JS wait condition `gather_data`.
9. Sets `advisorQuoteProductOverviewAutoPending := true`.

Source: `workflows/advisor_quote_workflow.ahk:1732-1768`.

JS `click_product_overview_tile`:

```js
if (!isProductOverviewPage(args)) return 'NOT_OVERVIEW';
const target = findOverviewProductTileTarget(args.productText || 'Auto');
if (!target) return 'NO_TILE';
return clickEl(target) ? 'OK' : 'CLICK_FAILED';
```

Source: `assets/js/advisor_quote/src/operator.template.js:788-792`.

Exact point where Auto selection could be missed:

- After `tileResult = "OK"` (`workflows/advisor_quote_workflow.ahk:1750-1754`) and before clicking `Save & Continue to Gather Data` (`workflows/advisor_quote_workflow.ahk:1759-1760`).
- No AHK or JS readback confirms that Auto became selected on the Product Tile Grid.
- `click_product_overview_tile` returns `OK` when `clickEl()` does not throw; it does not verify selected state.

Risk:

- Product Tile Grid can continue even if Auto did not actually become selected, as long as the Save & Continue click transitions to Gather Data.
- The later `advisorQuoteProductOverviewAutoPending := true` is only set after reaching Gather Data, so the workflow can detect "Auto may not have committed" later, but not prevent the missed selection at the source.

## 8. Gather Data handler

`AdvisorQuoteStateRapport()` maps to the human label Gather Data.

Entry behavior:

- Detects state.
- If already on `SELECT_PRODUCT`, `ASC_PRODUCT`, or `INCIDENTS`, treats Rapport stage as already satisfied.
- Otherwise calls `AdvisorQuoteHandleGatherData()`.

Source: `workflows/advisor_quote_workflow.ahk:471-486`.

`AdvisorQuoteHandleGatherData()`:

1. Waits for JS wait condition `gather_data` using `rapportContains`.
2. Calls `AdvisorQuoteFillGatherDefaults()`.
3. Iterates vehicles.
4. Skips vehicle if `vehicle_already_listed`.
5. Tries `confirm_potential_vehicle`.
6. If no potential match, adds vehicle through Gather Data fields and waits for `vehicle_added_tile`.
7. Reads Start Quoting status with `gather_start_quoting_status`.
8. Validates Start Quoting status.
9. If not ready and Start Quoting text exists, calls `ensure_auto_start_quoting_state`.
10. If ready, clicks `Create Quotes & Order Reports`.
11. Waits for `gather_start_quoting_transition`.
12. If still not ready, scans and calls Add Product fallback unless already on Select Product.

Sources:

- Gather Data readiness/defaults/vehicles: `workflows/advisor_quote_workflow.ahk:1045-1097`
- Start Quoting status/Auto ensure/Create Quotes/fallback: `workflows/advisor_quote_workflow.ahk:1098-1163`
- Status read helper: `workflows/advisor_quote_workflow.ahk:1263-1265`
- Status validity checks: `workflows/advisor_quote_workflow.ahk:1299-1335`
- Create Quotes click: `workflows/advisor_quote_workflow.ahk:1537-1539`
- Add Product fallback: `workflows/advisor_quote_workflow.ahk:1541-1569`

Start Quoting validity requires all of these:

- `hasStartQuotingText=1`
- `autoProductPresent=1`
- `autoProductChecked=1` or `autoProductSelected=1`
- rating state matches default `FL`
- Create Quotes button present
- Create Quotes button enabled

Source: `workflows/advisor_quote_workflow.ahk:1299-1335`.

Add Product fallback:

- Calls JS `click_start_quoting_add_product`.
- Waits for `to_select_product`.
- Then the next workflow state `SELECT_PRODUCT` applies defaults.

Source: `workflows/advisor_quote_workflow.ahk:1541-1569`.

Can Add Product fallback happen just because Auto was never selected upstream?

Yes. Source inspection supports that path:

- Product Overview sets `advisorQuoteProductOverviewAutoPending := true` after Gather Data transition, but it never verifies Auto selection on Product Overview.
- Gather Data then checks Start Quoting status.
- If Auto is missing/not selected, `AdvisorQuoteGatherStartQuotingStatusValid()` fails.
- If Start Quoting text exists, it tries `ensure_auto_start_quoting_state()`.
- If still not ready, it scans and calls `AdvisorQuoteOpenSelectProductFallbackFromGatherData()`.

The exact fallback call is `workflows/advisor_quote_workflow.ahk:1157-1162`.

Risk:

- The fallback may be responding to a missed upstream Product Tile Grid selection, not a genuine need to add another product.
- This is the clearest source-level place where the live flow can drift into Select Product/Add Product even though the intended path is Product Tile Grid Auto -> Gather Data Start Quoting Auto.

## 9. JS detector and wait condition source

JS source: `assets/js/advisor_quote/src/operator.template.js`

`detect_state` branch order (`assets/js/advisor_quote/src/operator.template.js:762-785`):

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
11. `ADVISOR_OTHER`
12. `GATEWAY`
13. `NO_CONTEXT`

Relevant page detectors:

- `isCustomerSummaryOverviewPage()` (`assets/js/advisor_quote/src/operator.template.js:66-77`): URL `/apps/customer-summary/` plus `/overview`, START HERE text, and Quote History or Assets Details.
- `isProductOverviewPage()` (`assets/js/advisor_quote/src/operator.template.js:79-90`): URL `/apps/intel/102/overview`, Select Product text, Auto text, Save & Continue text, and no visible Begin Quoting Continue button.
- `isGatherDataPage()` (`assets/js/advisor_quote/src/operator.template.js:161-168`): URL contains `/rapport`, or body contains Gather Data markers and vehicle field markers while not Product Overview.

Relevant wait conditions:

| Name | Source lines | Positive condition |
|---|---:|---|
| `post_prospect_submit` | 1698-1699 | Rapport URL, Select Product URL, Product Overview, or Duplicate. It does not directly include Customer Summary Overview. |
| `duplicate_to_next` | 1717-1718 | Customer Summary Overview, Gather Data, Select Product URL, Product Overview, or Select Product form. |
| `gather_data` | 1719-1720 | `isGatherDataPage(args)`. |
| `on_customer_summary_overview` | 1721-1722 | `isCustomerSummaryOverviewPage(args)`. |
| `on_product_overview` | 1723-1724 | `isProductOverviewPage(args)`. |
| `gather_start_quoting_transition` | 1727-1728 | Consumer Reports, Drivers/Vehicles, Incidents, or Quote Landing. |
| `is_customer_summary_overview` | 1762-1763 | `isCustomerSummaryOverviewPage(args)`. |
| `is_rapport` | 1764-1765 | `isGatherDataPage(args)`. |
| `is_product_overview` | 1766-1767 | `isProductOverviewPage(args)`. |

Do not change JS as part of this discovery.

## 10. Selector/text/url config

Source: `domain/advisor_quote_db.ahk`

Selectors (`domain/advisor_quote_db.ahk:2-29`):

| Key | Value |
|---|---|
| `advisorQuotingButtonId` | `group2_Quoting_button` |
| `searchCreateNewProspectId` | `outOfLocationCreateNewProspectButton` |
| `beginQuotingContinueId` | `PrimaryApplicant-Continue-button` |
| `sidebarAddProductId` | `addProduct` |
| `quoteBlockAddProductId` | `quotesButton` |
| `createQuotesButtonId` | `consentModalTrigger` |
| `selectProductRatingStateId` | `SelectProduct.RatingState` |
| `selectProductProductId` | `SelectProduct.Product` |
| `selectProductContinueId` | `selectProductContinue` |

Defaults (`domain/advisor_quote_db.ahk:31-50`):

| Key | Value |
|---|---|
| `ratingState` | `FL` |
| `currentInsured` | `YES` |
| `ownOrRent` | `OWN` |

URLs (`domain/advisor_quote_db.ahk:61-67`):

| Key | Value | Notes |
|---|---|---|
| `rapportContains` | `/rapport` | Generic enough for `intel/102/rapport`. |
| `customerSummaryContains` | `/apps/customer-summary/` | Allows dynamic customer summary id. |
| `productOverviewContains` | `/apps/intel/102/overview` | Matches live Product Tile Grid scans currently inspected. |
| `selectProductContains` | `/selectProduct` | Matches Select Product path. |
| `ascProductContains` | `/ASCPRODUCT/` | Updated from stale `/ASCPRODUCT/110/` so live `/ASCPRODUCT/109/` and other ASC product ids are accepted. |

Texts (`domain/advisor_quote_db.ahk:69-83`):

| Key | Value |
|---|---|
| `duplicateHeading` | `This Prospect May Already Exist` |
| `customerSummaryStartHereText` | `START HERE (Pre-fill included)` |
| `customerSummaryQuoteHistoryText` | `Quote History` |
| `customerSummaryAssetsDetailsText` | `Assets Details` |
| `productOverviewHeading` | `Select Product` |
| `productOverviewAutoTile` | `Auto` |
| `productOverviewContinueText` | `Save & Continue to Gather Data` |
| `selectProductCurrentInsuredQuestion` | `Is the customer currently insured?` |
| `selectProductAnswerYesText` | `Yes` |

Stale/missing anchor flags:

- `ascProductContains` was suspicious because scan evidence showed `/ASCPRODUCT/109/`, while config previously said `/ASCPRODUCT/110/`. It now uses generic `/ASCPRODUCT/`.
- Product Overview URL is hardcoded to `/apps/intel/102/overview`. That matches current inspected scan evidence, but it is not dynamic if Advisor Pro changes product route ids.
- Customer Summary URL is correctly dynamic enough for `/apps/customer-summary/<id>/overview`.
- Product Overview detection depends on the text trio `Select Product`, `Auto`, and `Save & Continue to Gather Data`; if any label changes, `PRODUCT_OVERVIEW` may not detect.

## Product Tile Idempotency Update

The Product Tile Grid handler now ensures Auto is selected instead of blindly clicking Auto:

- already-selected Auto is a valid forward state and is not clicked again
- unselected Auto is clicked once and then verified through `product_overview_tile_status`
- `click_product_overview_tile` is defensive and returns `OK` without clicking if the tile is already selected
- `Save & Continue to Gather Data` remains blocked until selected-state evidence is present

This prevents a selected Auto tile from being toggled off before Gather Data.

## 102 Product Auto Gate Update

Customer Summary / Prefill Gate (`/apps/customer-summary/<dynamicId>/overview`) is only the START HERE entry into 102. It is not proof that a product has been selected.

Product Tile Grid (`/apps/intel/102/overview`) can allow `Save & Continue to Gather Data` while the Auto tile is still unselected. The workflow therefore treats Auto tile selection as mandatory independent evidence:

- Auto selected state must come from the resolved Auto tile/card only.
- Save & Continue enabled does not count as selected.
- saved assets, Snapshot Vehicles, body text, current URL, and sidebar content do not count as selected.
- already-selected Auto is valid and is not clicked again.
- unselected Auto is clicked once, then verified before Save & Continue.

After Save & Continue reaches RAPPORT, the workflow separately verifies Gather Start Quoting Auto by DOM state. The 102 Product Tile state, Product Overview save, and Gather Auto commitment are logged separately. If Gather Auto is missing or unchecked, one recovery is allowed through the top `SELECT PRODUCT` subnav back to `/apps/intel/102/overview`; sidebar Add Product is not used.

## Product Tile Resolver Restoration

Auto on Product Tile Grid may be a non-button tile/card. The generic scan button list is not expected to contain Auto in that shape.

The Product Tile resolver used by status, click, and ensure ops is shared:

- `product_overview_tile_status`
- `click_product_overview_tile`
- `ensure_product_overview_tile_selected`

The resolver starts from visible Auto text, resolves a smallest single-product tile/card container, and chooses a real interactive descendant or the tile/card center. It rejects broad containers with multiple product labels, so a grid containing `Auto Home Renters PUP Condo Motorcycle ORV Boat Motorhome Landlords ManufacturedHome` is not treated as the Auto tile. The selected-state proof remains scoped inside the resolved Auto tile only.

## 11. Current likely bug

Blunt source-based diagnosis:

The bug is most likely a combination of Product Tile Grid Auto-selection not being verified and Gather Data Add Product fallback being too willing to compensate later.

Answers:

- Is the bug likely post-create routing? Less likely in the current main state path. `AdvisorQuoteStateEntryCreateForm()` accepts `CUSTOMER_SUMMARY_OVERVIEW`, `PRODUCT_OVERVIEW`, `RAPPORT`, and `SELECT_PRODUCT` after submit. However, the older `post_prospect_submit` wait condition is stale-risky because it does not directly accept `CUSTOMER_SUMMARY_OVERVIEW`.
- Is the bug likely Prefill Gate click/wait? Possible but secondary. The handler clicks by START HERE text and accepts Product Overview or later. Scan evidence shows multiple START HERE texts, so container ambiguity exists.
- Is the bug likely Product Tile Grid Auto selection? Yes. This is the strongest source-level risk. `click_product_overview_tile` returns `OK` after a click attempt, but no code verifies Auto selected before Save & Continue.
- Is the bug likely Gather Data Add Product fallback? Yes, as a downstream symptom. If Auto was never selected upstream, Gather Data can decide Start Quoting is invalid and use Add Product fallback.
- Is the bug a combination? Yes. Product Overview can miss/unverified Auto selection, and Gather Data fallback can turn that into Select Product/Add Product routing instead of failing with a precise upstream error.

Live scan evidence supports the intended page sequence:

- `#/apps/customer-summary/<id>/overview`
- `#/apps/intel/102/overview`
- `#/apps/intel/102/rapport`
- later `#/apps/intel/102/selectProduct`
- later `#/apps/ASCPRODUCT/109/`

Logs are runtime evidence only, not canonical source. Customer-specific scan text is intentionally omitted from this report.

## 12. Recommended patch phases

Do not implement these in this discovery task.

1. Routing from Create/Duplicate to Prefill Gate/Product Tile Grid/Gather Data.
   - Confirm the active state path uses `AdvisorQuoteWaitForObservedState()` and not the stale `post_prospect_submit` helper.
   - If any active path still uses `post_prospect_submit`, include `CUSTOMER_SUMMARY_OVERVIEW`.

2. Prefill Gate START HERE handling.
   - Prefer a more precise START HERE target if scans identify the correct container.
   - After click, prefer waiting specifically for Product Tile Grid first, while still documenting acceptable later-state bypasses.

3. Product Tile Grid Auto-selection enforcement.
   - Add readback after `click_product_overview_tile`.
   - Do not click `Save & Continue to Gather Data` unless Auto is actually selected.
   - Log exact Auto tile status before continue.

4. Gather Data guard.
   - If `advisorQuoteProductOverviewAutoPending` is true and Auto is not present/selected in Start Quoting, fail with a Product Tile Grid selection error or route to a deliberate recovery path.
   - Do not use Add Product fallback just because Auto was never selected upstream.

5. Start Quoting validation before Create Quotes.
   - Keep the current strict checks for Auto present/selected, rating state, Create Quotes present/enabled.
   - Add clearer classification of whether failure is upstream tile selection, current Gather Data state, or selector drift.

6. Downstream popup/modal hardening.
   - After early-flow routing is stable, separately harden Consumer Reports, Drivers/Vehicles, Incidents, and modal handling.

## 13. Open questions for Pablo

1. On the Product Tile Grid, what DOM/visual state definitively proves the Auto tile is selected?
2. Are there multiple valid START HERE buttons on Prefill Gate, or should only one container/button be used?
3. Is `/apps/intel/102/overview` stable across all Advisor Pro users/products, or should Product Overview detection avoid hardcoding `102`?
4. Is `/ASCPRODUCT/109/` now the correct ASC product route, replacing configured `/ASCPRODUCT/110/`, or can both occur?
5. Should Add Product fallback ever be allowed immediately after a Product Tile Grid Auto-selection miss, or should that be a hard failure requiring manual review?
