# Next Patch Decision Tree

Captured: 2026-05-06

Use this before writing another Advisor Pro patch. The default should be read-only audit first unless the latest failure has a clear implemented owner and a sanitized fixture/log already proves the shape.

## First Triage

1. Read `git status --short`.
2. Read the latest relevant tail of `logs/advisor_quote_trace.log`, sanitized.
3. Read `logs/run_state.json`.
4. Summarize `logs/advisor_scan_latest.json` without raw page text.
5. Identify the latest failing state and failure code.
6. Decide:
   - write a narrow patch if the failing code maps to one known owner
   - ask for a fresh scan if the live DOM shape is unclear
   - run a read-only audit first if bridge, route, or snapshot evidence is inconsistent

## If Latest Failure Is RAPPORT

Inspect:

- `logs/advisor_quote_trace.log`
- `logs/advisor_scan_latest.json` summarized only
- `GATHER_RAPPORT_SNAPSHOT`
- `RAPPORT_SNAPSHOT_GATE`
- `VEHICLE_DB_RESOLVER`
- `VEHICLE_PREFLIGHT_STATUS`
- `VEHICLE_EDIT_STATUS`
- `VEHICLE_DB_ADD_*`
- `GATHER_CONFIRMED_VEHICLES_STATUS`
- `GATHER_START_QUOTING_STATUS`

Snapshot fields that matter:

- `activeModalType`
- `activePanelType`
- `blockerCode`
- `editVehiclePanelPresent`
- `editVehicleStatus`
- `editVehicleUpdateEnabled`
- `staleAddRowPresent`
- `vehicleWarningPresent`
- `confirmedVehicleCount`
- `potentialVehicleCount`
- `startQuotingSectionPresent`
- `createQuotesEnabled`
- `missing`
- `nextRecommendedReadOnlyStatus`

Patch vehicle DB matching when:

- resolver returns `UNKNOWN` for a known covered year/make/model
- resolver returns `AMBIGUOUS` for a model that should have one safe DB group
- confirmed/potential card evidence has exact year/make/model but scoring rejects it
- a non-overmatch guard is too broad or too narrow

Patch Edit Vehicle when:

- snapshot or `gather_vehicle_edit_status` says `UPDATE_REQUIRED_READY`
- required fields are present and Update is enabled
- AHK returns `NO_ACTION_NEEDED` or fails to verify panel close/confirmed card
- submodel is required and there is one safe existing option or VIN/trim-backed option

Patch stale row handling when:

- `gather_rapport_snapshot` reports `activeModalType=GATHER_STALE_ADD_VEHICLE_ROW`
- `staleAddRowPresent=1`
- latest failure is `RAPPORT_ACTIVE_BLOCKER_UNHANDLED`
- there is enough scan/status evidence to cancel only the stale Add Car/Truck row without touching confirmed vehicles

Fail manual when:

- no vehicle can be safely resolved, confirmed, promoted, or DB-added
- multiple vehicle candidates remain ambiguous
- DB evidence conflicts with live Advisor card evidence
- stale row cannot be proven safe to cancel
- scan contains an unknown active modal/panel

Current latest log signal:

- RAPPORT failed on `GATHER_STALE_ADD_VEHICLE_ROW_OPEN` after earlier `NO_SAFE_RAPPORT_VEHICLE_MATCH`. This points first to the RAPPORT snapshot blocker gate, not to broadening DB matching.

## If Latest Failure Is ASCPRODUCT Drivers/Vehicles

Inspect:

- `ASC_DRIVERS_VEHICLES_SNAPSHOT`
- `ASC_LEDGER_STATUS`
- `ASC_PARTICIPANT_DETAIL_STATUS`
- `ASC_PARTICIPANT_MARITAL_RESULT`
- `ASC_DRIVER_ROWS_STATUS`
- `ASC_DRIVER_RECONCILE_RESULT`
- `ASC_VEHICLE_ROWS_STATUS`
- `ASC_VEHICLE_RECONCILE_RESULT`
- `ASC_REMOVE_REASON_STATUS`
- `ASC_LEDGER_SAVE_AND_CONTINUE_CLICKED`

Ledger fields that matter:

- `activeModalType`
- `activePanelType`
- `blockerCode`
- `primaryDriverStatus`
- `spousePolicy`
- `spouseStatus`
- `selectedSpouseName`
- `spouseOverrideApplied`
- `spouseCandidateCount`
- `spouseCandidateWithinWindowCount`
- `extraDriverCount`
- `unresolvedDriverCount`
- `expectedVehicleCount`
- `vehiclesAdded`
- `unresolvedVehicleCount`
- `mainSavePresent`
- `mainSaveEnabled`
- `nextAction`
- `reason`

Modal/panel blockers that matter:

- `ASC_INLINE_PARTICIPANT_PANEL_OPEN`
- `ASC_REMOVE_DRIVER_MODAL_OPEN`
- `ASC_VEHICLE_MODAL_OPEN`
- `ASC_MAIN_SAVE_DISABLED`
- `ASC_UNRESOLVED_DRIVERS`
- `ASC_UNRESOLVED_VEHICLES`

Spouse policy checks:

- Current committed defaults enable Single/unknown spouse override by default.
- Verify whether the live failure is using the current default config values from `domain/advisor_quote_db.ahk`.
- Exact lead spouse wins first.
- Unique safe age-window candidate can be selected when policy allows.
- Multiple in-window candidates must fail safe.
- Missing dropdown option for a selected/unique spouse should fail with a specific reason, not silently pick a placeholder.

Remove modal checks:

- Confirm `select_remove_reason` returns `result=OK`.
- Confirm `reasonSelected=1`.
- Confirm configured reason code is `0006` unless db defaults changed.
- Only then click `REMOVE_PARTICIPANT_SAVE-btn`.
- Re-read snapshot and verify modal closed or unresolved driver count moved.

Vehicle row checks:

- `expectedVehicleCount` comes from complete lead vehicles only.
- Partial ASC vehicles are passed separately for row reconciliation.
- Do not remove extra vehicles.
- Add only expected lead-matching vehicle rows.
- Fail on unresolved vehicle ambiguity.

Save gate checks:

- `mainSavePresent=1`
- `mainSaveEnabled=1`
- no unresolved drivers
- no unresolved vehicles
- primary driver added
- expected vehicles added or at least one existing vehicle when no expected vehicle exists
- participant required fields satisfied

Patch when:

- ledger chooses the wrong next action from correct snapshot/status data
- a modal/panel is correctly detected but routed to the wrong handler
- an action succeeds but verification is reading the wrong field

Ask for scan when:

- snapshot says unknown modal/panel
- required radio/control is not visible in sanitized status
- row summaries are empty but page evidence says rows exist

## If Latest Failure Is DevTools Or Console

Inspect:

- `logs/advisor_quote_trace.log` for `DEVTOOLS_BRIDGE_FAILED`, `JS_ASSET_EMPTY`, `WAIT_POLL_JS`, `ACTION_JS`
- `logs/devtools_bridge_returns.log` only if the failing path used the shared adapter bridge
- `logs/js_asset_errors.log`
- whether the operation was Advisor local bridge or shared adapter bridge

Runner/tiny bridge audit path:

- Check `advisorQuoteResidentRunnerFeatureEnabled`.
- If false, the resident runner is not the production path.
- If true, inspect `ADVISOR_RUNNER_*` trace entries.
- Check tiny payload length and `MISSING`, `STALE_BUILD`, `WRONG_CONTEXT`, `REFUSED`, `EMPTY`, and `TIMEOUT` results.

Bridge log checks:

- stale clipboard suspected
- stale rendered clipboard
- console submit attempted
- result empty
- result error payload
- possible paste protection
- stopped before submit
- wrong op or asset path

Pause business patches when:

- the same op returns empty repeatedly
- bridge submit is stale
- paste protection is present
- wrong browser/tab context is likely
- generated operator drift is suspected

Do not patch business logic to compensate for console transport failure.

## If Latest Failure Is Product Overview Or Start Quoting

Inspect docs:

- `ADVISOR_PRO_SCAN_WORKFLOW.md`
- `docs/PROJECT_ARCHITECTURE_AUDIT.md`
- `docs/ADVISOR_JS_OPERATOR_CONTRACT.md`

Inspect AHK functions:

- `AdvisorQuoteHandleProductOverview()`
- `AdvisorQuoteGetProductOverviewTileStatus()`
- `AdvisorQuoteWaitForProductOverviewAutoSelected()`
- `AdvisorQuoteGetGatherStartQuotingStatus()`
- `AdvisorQuoteGatherStartQuotingCoreReady()`
- `AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff()`
- `AdvisorQuoteRunScopedStartQuotingAddProductHandoff()`
- `AdvisorQuoteRecoverProductTileAutoFromRapport()`

Inspect JS ops:

- `product_overview_tile_status`
- `click_product_overview_tile`
- `ensure_product_overview_tile_selected`
- `click_product_overview_subnav_from_rapport`
- `gather_start_quoting_status`
- `ensure_start_quoting_auto_checkbox`
- `ensure_auto_start_quoting_state`
- `click_create_quotes_order_reports`
- `click_start_quoting_add_product`

Patch when:

- Auto tile is present but selected evidence is not recognized
- the wrong Add Product link is being clicked
- Create Quotes enabled state is read incorrectly
- Product Overview verified flags are not reset or set correctly

Ask for scan when:

- tile structure changed
- Start Quoting section disappeared after a click
- route is not clearly Product Overview, Rapport, Select Product, or ASCPRODUCT

## Write Patch, Ask For Scan, Or Audit First

Write a patch when all are true:

- latest failure code is specific
- owner function is obvious
- current snapshot/log fields prove the live shape
- patch can be narrow
- validation command is known
- no customer data or logs need to be staged

Ask for a scan when any are true:

- active modal/panel is unknown
- field/button selectors are missing from status
- live route is ambiguous
- previous scan is stale or from a different state
- fixing would require guessing DOM shape

Run a read-only audit first when any are true:

- bridge failures and business failures are mixed
- generated JS drift is possible
- docs conflict with current code
- working tree has unrelated runtime edits
- the likely patch crosses AHK and JS boundaries

Default next patch from current logs:

- Audit and patch RAPPORT stale Gather add-row blocker handling before broad vehicle matching changes.
