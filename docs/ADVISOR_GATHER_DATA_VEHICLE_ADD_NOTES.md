# Advisor Gather Data Vehicle Add Notes

## Observed Failure

A live Gather Data run reached `/apps/intel/102/rapport`, applied Gather defaults, then failed while adding the lead vehicle `2019|HONDA|PILOT`.

The page warned that Auto was originally asked for and at least one car or truck must be confirmed or added. The previous `prepare_vehicle_row` contract only reused already-present vehicle fields; when no usable row was open, it returned `-1` and the workflow failed without opening Add Car or Truck.

## Patch Scope

This patch is limited to the Gather Data vehicle-add path. It does not change Product Tile Grid selection, duplicate handling, Customer Summary routing, ASC/109 downstream driver/vehicle/insurance behavior, hotkeys, CRM/QUO, messaging, pricing, lead parsing, or the AHK/JS bridge.

## Vehicle Row Strategy

`prepare_vehicle_row` still returns the AHK-compatible raw index string or `-1`.

Current behavior:

- Reuse a visible, editable, incomplete vehicle row when one exists.
- Do not reuse a completed row with year, manufacturer, model, and submodel already selected.
- If no usable row exists, click a visible Add Car or Truck/Add Vehicle style control.
- Wait briefly for a usable row to appear.
- Set vehicle type to Car or Truck when that field exists and is blank.
- Set the requested year exactly.
- Return `-1` if the row cannot be opened, the year control is missing/disabled/read-only, or the exact year cannot be set.

## Dropdown Sequence

The AHK Gather Data flow now logs row status before and after preparation, then follows this sequence:

1. Prepare or open the vehicle row.
2. Set Vehicle Type to Car or Truck when the field exists.
3. Re-apply the exact ModelYear with the year-cascade op and wait for Manufacturer to become enabled with real options.
4. Wait for Manufacturer options through the existing wait condition as a second guard.
5. Select Manufacturer.
6. Wait for Model options.
7. Select Model.
8. Wait for SubModel options.
9. Select SubModel.
10. Click Confirm/Add using existing controls.
11. Verify `vehicle_added_tile` before continuing.

Failures log `gather_vehicle_row_status` diagnostics and fail safely.

## Matching Rules

Dropdown matching uses:

- Exact value match first.
- Exact visible text match second.
- Normalized exact text/value match through the same normalized comparison.
- Explicit small aliases for common make labels: Chevrolet/Chevy/Chevy Trucks, Toyota/Toy./Toyota Trucks, Ford/Ford Trucks, and Honda.
- Contains matching only when exactly one option matches.

Year is special: exact numeric year is required. The operator does not select a different year as a fallback.

## Submodel Fallback

When trim, drivetrain, or VIN evidence is not available, `SubModel` uses the existing `allowFirstNonEmpty` path and selects the first valid non-placeholder option. This is logged as the normal no-evidence fallback behavior; it does not embed or depend on a static vehicle catalog.

## Diagnostics

New read-only JS op:

`gather_vehicle_row_status`

Return keys include `result`, `rowIndex`, field-presence flags, field values, option summaries, Add Car or Truck button presence/text, and visible alerts.

The workflow logs these diagnostics around row preparation, dropdown selection failures, Add/Confirm click failure, and final verification failure.

New row-specific write/status JS op:

`set_vehicle_year_and_wait_manufacturer`

This op writes only `ConsumerData.Assets.Vehicles[index].ModelYear`. It focuses the Year input, clears/re-sets the exact requested year through the native value setter, dispatches controlled-input style events (`keydown`, `input`, `change`, `keyup`, plus `blur`/`focusout` on retry), optionally focuses Manufacturer on the strongest retry, verifies the Year value still equals the requested year, and reports whether Manufacturer is enabled with at least one real non-placeholder option.

It returns key=value diagnostics including `yearVerified`, `manufacturerEnabled`, `manufacturerOptionCount`, `method`, `eventsFired`, `attempts`, and `failedFields`. Manufacturer `disabled=true` with `options=[]` remains a failure.

## Live Cascade Failure

A later live run opened row `6`, set Vehicle Type to Car/Truck (`10`), and wrote `ModelYear=2019`, but Manufacturer stayed disabled with no options. The workflow now calls `set_vehicle_year_and_wait_manufacturer` after row preparation and before Manufacturer selection, so the Year field is re-triggered with a more realistic event sequence and the cascade is explicitly verified.

The exact-year rule is unchanged: the workflow must not select or submit a different year.

## Vehicle Add Completion

Live evidence later showed the Add Car or Truck row could collapse or clear after Add/Confirm, while the older verifier `vehicle_added_tile` still timed out. The workflow now polls the read-only `gather_vehicle_add_status` op after clicking Add/Confirm.

`gather_vehicle_add_status` looks for:

- confirmed vehicle card text matching exact year, normalized make, and normalized model
- selected row values while the row is still open
- row-gone evidence
- the "Confirm or Add at least 1 car or truck" warning
- visible validation alerts

Confirmed vehicle cards are now the primary success evidence. The expected successful page shape is the Cars and Trucks section, a CONFIRMED VEHICLES subsection, a vehicle card containing year/make/model text, Edit/Remove actions, and a CONFIRMED status/checkmark. Potential vehicle text such as POTENTIAL VEHICLES or Confirm Remove is not success, and a different confirmed vehicle is not success.

Row-gone is partial evidence only. It is not treated as `ADDED` unless confirmed vehicle text or safe requirement-satisfied evidence appears. If status remains unresolved, the workflow fails with diagnostics instead of continuing blind.

## Edit Vehicle Sub-Model Required

A later live Gather Data run opened an Advisor Edit Vehicle panel for a potential vehicle. Year, VIN, Manufacturer, and Model were populated, but `CommonComponent.Vehicle[0].SubModel` was still required and set to `Select One`. Valid Sub-Model options were present and the `submitButtonVehicleComponent_0` Update button was enabled.

The workflow now checks for this edit panel before retrying generic confirm/add work and again after potential-confirm/add verification stalls. The read-only `gather_vehicle_edit_status` op reports the vehicle field values, Sub-Model option count/summary, Update button state, alerts, and modal evidence.

The write op `handle_vehicle_edit_modal` completes only this open edit panel:

- if Sub-Model is already valid, it returns `NO_ACTION_NEEDED`
- if VIN evidence matches an option pattern such as `2T1BURHE*K`, it selects the first compatible option and logs `subModelSelectionMethod=vin-pattern`
- if trim, drivetrain, or body evidence uniquely matches one option, it logs `subModelSelectionMethod=trim-match`
- otherwise it selects the first valid non-placeholder Sub-Model option and logs `subModelSelectionMethod=first-valid`
- placeholder/disabled options such as `Select One` are ignored
- Update is clicked only after the selected Sub-Model value verifies and the Update button is present/enabled

This first-valid fallback is intentional for Advisor-required Sub-Model prompts when multiple submodels are possible and the lead/VIN evidence does not safely distinguish them. The patch still does not embed a vehicle database and does not select a different year.

After Update, AHK polls `gather_vehicle_add_status` for the exact vehicle and accepts success only when matching confirmed-card evidence appears. If the edit panel cannot be completed or the vehicle does not become confirmed after Update, the workflow fails with `VEHICLE_SUBMODEL_REQUIRED_UNRESOLVED` or `VEHICLE_EDIT_UPDATE_NOT_CONFIRMED`.

## Short JS Ops

The year-cascade op no longer performs a long blocking wait inside a single injected JS execution. It now performs a short controlled-input action and immediate readiness check; AHK owns the bounded polling through existing wait/status calls. This reduces empty DevTools/copy-result risk from long-running injected snippets.

## Start Quoting Auto

The Start Quoting Auto checkbox is targeted by stable id:

`ConsumerReports.Auto.Product-intel#102`

The new `ensure_start_quoting_auto_checkbox` op checks the box by associated label/input first, then uses a direct checked assignment only for this known checkbox if the click does not stick. It dispatches `input` and `change`, then verifies `checked=true`.

Add Product from Gather Data is legitimate only after Product Tile Grid Auto was verified earlier, vehicle add/confirm is complete or safely accepted, and Start Quoting Auto is selected. It is still not a recovery path for missed Product Tile Grid Auto selection.

The Add product click is scoped to the Start Quoting section. The left/sidebar Add Product control must not be used for this handoff.

Gather Start Quoting Auto is a separate commitment check from Product Tile Grid selection:

- `ProductTileAutoSelectedOnOverview` means Auto was selected on `/apps/intel/102/overview`.
- `ProductOverviewSaved` means Save & Continue was clicked after Auto selected-state proof.
- `GatherAutoCommitted` means RAPPORT Start Quoting contains Auto and Auto is selected/checked.

The workflow does not treat RAPPORT arrival as proof of commitment. If Start Quoting Auto is missing or unchecked after a verified Product Overview save, it may recover once by clicking the top `SELECT PRODUCT` subnav back to Product Tile Grid, reselecting Auto if needed, saving again, and re-reading Start Quoting. Sidebar Add Product remains refused as a Product Tile recovery path.

## Potential Vehicle Confirmation Guard

Live evidence showed `confirm_potential_vehicle` could receive a broad Cars and Trucks container containing both CONFIRMED VEHICLES and POTENTIAL VEHICLES. That is unsafe because the first `Confirm` button inside the broad container can belong to an unrelated public-record vehicle.

Potential vehicle confirmation is now limited to a single card/row:

- exact lead year is required
- normalized make/model must match the current lead vehicle
- the candidate must have one vehicle title and one Confirm button
- broad containers with both CONFIRMED VEHICLES and POTENTIAL VEHICLES are rejected
- containers with multiple Confirm buttons, multiple vehicle titles, or Add Car or Truck controls are rejected
- lead vehicles missing year are logged/skipped and are not auto-confirmed

The operator adds confirmation diagnostics: `candidateScope`, `confirmButtonCount`, `vehicleTitleCount`, `matchedCardText`, `rejectedReason`, and `confirmClicked`.

## Unexpected Confirmed Vehicle Guard

The workflow now calls `gather_confirmed_vehicles_status` before Start Quoting. It compares confirmed vehicle cards against the lead vehicles with usable years. Extra confirmed vehicles produce `result=UNEXPECTED`; the workflow fails safely with `UNEXPECTED_CONFIRMED_VEHICLES` and captures a scan.

Missing-year lead vehicles are reported as unresolved and are not used to auto-confirm public-record vehicles. This patch does not auto-remove unexpected confirmed vehicles; removal remains a future, separately bounded task.

## Gather Data Lead Vehicle Policy

Gather Data now classifies lead vehicles before confirmation/add:

- `actionableVehicles`: year, make, and model are all present. Only these vehicles are confirmed, added, and passed as expected confirmed vehicles.
- `ignoredMissingYearVehicles`: make/model are present, year is missing, and no VIN/VIN suffix exists. These are ignored/deferred when at least one actionable vehicle exists.
- `deferredVinVehicles`: VIN or VIN suffix exists but year/make/model are incomplete. These are logged for a later VIN-aware ASC/109 patch and are not auto-added in Gather Data.
- `blockingMissingVehicleData`: insufficient vehicle data when there are no actionable vehicles.

If no actionable vehicle exists, the workflow fails safely/manual with `NO_ACTIONABLE_LEAD_VEHICLE` or `VIN_PRESENT_BUT_YEAR_MISSING_DEFERRED`. It does not guess, decode VINs, or select a different year.

The confirmed-vehicle guard receives only actionable vehicles as expected vehicles. Ignored/deferred missing-year vehicles do not appear in `missingExpectedVehicles`, while unexpected confirmed public-record vehicles still fail with `UNEXPECTED_CONFIRMED_VEHICLES`.

## Vehicle Loop Idempotency

The Gather Data vehicle loop now performs a confirmed-card preflight for each actionable lead vehicle before any legacy listed check, potential confirmation, or Add Car or Truck row work.

Preflight uses `gather_vehicle_add_status` for the exact lead vehicle. A vehicle is counted as already satisfied only when the status reports:

- `result=ADDED`
- `confirmedVehicleMatched=1`
- `confirmedStatusMatched=1`
- exact `yearMatched=1`
- normalized `makeMatched=1`
- normalized `modelMatched=1`

When that strict confirmed-card evidence is present, the workflow logs `VEHICLE_ALREADY_CONFIRMED`, increments the satisfied count, and skips all confirm/add attempts for that vehicle. This makes RAPPORT retries idempotent: a retry begins by re-reading current confirmed cards and does not try to re-add an already confirmed Honda Pilot or Toyota Prius.

Confirmed-card model matching now uses the same exact-normalized model keys for common punctuation variants before any Add Car or Truck row work. For example, `2019 Honda CRV`, `2019 Honda CR-V`, and `2019 Honda CR V` all match the confirmed card `2019 Honda CR-V ... CONFIRMED`. The matcher also normalizes `HR-V`, `CX-30`, `QX56`, Ford F-series spacing/hyphens, and `4Runner` spacing while preserving strict non-overmatch guards such as Prius/Prius Prime, Transit/Transit Connect, F150/F250, Silverado 1500/Silverado 2500, and CR-V/HR-V.

If a retry starts after a previous failed attempt left an incomplete Add Car or Truck row open for a vehicle that is now proven already confirmed, `gather_vehicle_add_status` reports `duplicateAddRowOpenForConfirmedVehicle=1`. The workflow does not continue filling that duplicate row. Because there is no proven row-scoped cancel action for this live shape, it fails closed with `DUPLICATE_ADD_ROW_OPEN_FOR_CONFIRMED_VEHICLE` and captures a scan instead of adding a duplicate or removing a confirmed card.

Partial year/make vehicles also get a confirmed-card preflight before any Add Car or Truck work. In `partialYearMakeMode=1`, `gather_vehicle_add_status` is read-only and inspects confirmed cards only. A partial vehicle is promoted only when exactly one confirmed same-year/same-make card exists, the card has visible model text, and the card has VIN or masked-VIN evidence. Example: a lead vehicle `2010 Nissan` can be promoted to `2010 Nissan CUBE` when Advisor already shows a single `2010 Nissan CUBE ... CONFIRMED` card with VIN evidence.

The partial path does not select a model from a broad Add Car or Truck dropdown. If the Nissan model dropdown contains many options such as `370Z`, `ALTIMA`, `CUBE`, and `FRONTIER`, the workflow will not choose the first option. If no unique VIN-bearing confirmed card exists, the partial vehicle is deferred or fails safely depending on whether another vehicle is already satisfied.

If a retry starts with an incomplete Add Car or Truck row open for a partial vehicle that is now satisfied by a promoted confirmed card, the workflow fails closed with `DUPLICATE_ADD_ROW_OPEN_FOR_PROMOTED_CONFIRMED_VEHICLE` unless a future patch proves a row-scoped safe cancel. It never clicks Add on that duplicate row and never removes the confirmed card.

The older `vehicle_already_listed` check is no longer allowed to skip work by itself. If it reports listed but the confirmed-card preflight does not prove the vehicle is confirmed, the workflow logs that legacy evidence and continues with the normal potential-confirm/add path.

After `confirm_potential_vehicle` clicks a matching potential card, the workflow no longer relies only on the narrow `vehicle_confirmed` wait condition. It polls `gather_vehicle_add_status` for the same exact vehicle and accepts success only when the confirmed-card predicate above becomes true. If a potential confirmation does not become a matching confirmed vehicle card, the workflow fails with a vehicle-confirm status timeout and captures diagnostics.

After all actionable vehicles and partial confirmed-card promotions are processed, the workflow reconciles the page with `gather_confirmed_vehicles_status` using complete actionable vehicles plus promoted partial vehicles as expected. Unpromoted partial vehicles are not reported as missing expected vehicles. Missing expected confirmed vehicles fail with `MISSING_EXPECTED_CONFIRMED_VEHICLES`; unexpected confirmed vehicles still fail with `UNEXPECTED_CONFIRMED_VEHICLES`.

## Final Confirmed-Vehicle Reconciliation

The final Gather Data guard must receive the full actionable vehicle list, regardless of how each vehicle became satisfied:

- already confirmed before the loop
- confirmed from a potential vehicle card during the loop
- added through an Add Car or Truck row during the loop

The guard now passes structured `expectedVehicles` objects to `gather_confirmed_vehicles_status` instead of relying on the legacy pipe-delimited `expectedVehiclesText` string. The old string format is ambiguous when VIN is blank because `year|make|model|` joined with `||` can produce triple pipes between records. In the Jeannette-style lead, that ambiguity caused the second expected vehicle to parse as unresolved text (`2007 TOYOTA`) instead of `2007 TOYOTA PRIUS`, so the confirmed Prius card was incorrectly reported as unexpected.

For the Jeannette-style lead, 102 expected vehicles are:

- `2019 HONDA PILOT`
- `2007 TOYOTA PRIUS`

The missing-year `TOYOTA PRIUS PRIME` is excluded from the final expected list and remains ignored/deferred for 102. `expectedCount` should equal `actionableVehicleCount`; if those diverge, the reconciliation trace logs both the expected count/list and the actionable count/list.

## Catalog-Aware Confirmed Cards

Confirmed-card matching now uses a compact domain-level catalog helper for Advisor manufacturer labels. The helper mirrors the compact catalog summary instead of loading the full crawler database into injected JS.

The workflow adds optional allowed make labels to complete actionable expected vehicles before calling confirmed-card status ops. Example:

- Lead: `2019 Toyota Highlander`
- Advisor confirmed card: `2019 Toy. trucks HIGHLANDER ... CONFIRMED`
- Expected labels: `TOYOTA|TOY. TRUCKS`

This card now matches the expected Toyota Highlander instead of being reported as unexpected.

The match is still strict:

- exact year is required
- normalized model exact match is required
- VIN is preferred when available but is not required when the lead has no VIN
- `Toyota Prius` does not match `Toyota Prius Prime`
- partial vehicles such as `2021 Mazda` are promoted only from a unique VIN-bearing confirmed card during 102 Gather Data; broad model dropdowns remain unsafe

The catalog-aware labels apply to confirmed-card evidence (`gather_vehicle_add_status` preflight/status and `gather_confirmed_vehicles_status` final guard). Potential-card confirmation, Add Car or Truck row selection, model dropdown selection, and ASC/109 handling are unchanged.

## ASCPRODUCT Vehicle Reconciliation

ASCPRODUCT is now a separate downstream reconciliation stage. It does not loosen the 102 Gather Data rules. Instead, it receives:

- complete lead vehicles: exact year, recognized make, and non-empty normalized model
- partial year/make vehicles: exact year and recognized make, with no model text
- deferred vehicles: insufficient evidence for automatic action

Complete ASCPRODUCT vehicle rows still require exact year, catalog-aware make family, and strict normalized model. Partial year/make rows may be promoted only from scoped live Advisor evidence: exactly one same-year/same-make row, visible model text, and VIN or masked VIN evidence. This is why a synthetic `2010 Nissan` lead can promote only when Advisor shows a single VIN-bearing `2010 Nissan <model>` row. If two same-year/same-make candidates appear, the workflow fails/defer safely instead of choosing a first model from a broad dropdown.

Already added/confirmed ASCPRODUCT vehicle rows count as satisfied only after the row is re-read. Save and Continue remains blocked until driver rows are resolved, at least one expected or safely promoted vehicle is added/confirmed, and Advisor's `profile-summary-submitBtn` is enabled.

## Validation

- `node assets/js/advisor_quote/build_operator.js --check`: passed.
- `node assets/js/advisor_quote/build_operator.js`: generated `assets/js/advisor_quote/ops_result.js`.
- `node assets/js/advisor_quote/build_operator.js --check`: passed after generation.
- `node .\tests\advisor_quote_ops_smoke.js`: passed with the bundled Codex Node runtime.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1`: passed with `SMOKE_VALIDATE=pass`, `MAIN_VALIDATE=pass`, and `COMPILER_CHECK=skipped`.

## Future Catalog Plan

A later task can add an explicit vehicle catalog or crawler-backed fixture plan if Advisor Pro submodel choices need stronger VIN/trim/drivetrain selection. This patch intentionally avoids embedding a large static database into the injected operator.
