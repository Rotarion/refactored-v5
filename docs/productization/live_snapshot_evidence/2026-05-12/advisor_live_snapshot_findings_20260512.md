# Sanitized Advisor Live Snapshot Findings - 2026-05-12
These findings are based on sanitized read-only `advisor_state_snapshot` outputs captured with `Ctrl+Alt+Shift+S`. Raw names, street addresses, VINs/masked VIN evidence, dynamic ASCPRODUCT IDs, and long page text summaries were redacted.
## Summary
- The ENTRY_CREATE_FORM, RAPPORT, and SELECT_PRODUCT snapshots classify correctly.
- The Standardized Address screen is detected as ENTRY_CREATE_FORM with blocking alert evidence, but it needs a dedicated normalized blocker/status path before any automation action.
- Product Overview, Consumer Reports, ASC Drivers/Vehicles, ASC Remove Driver modal, and ASC Vehicle modal are live route-classification gaps: nested evidence exists, but top-level `route` remains `ADVISOR_OTHER`.
- The ASC snapshots are especially valuable because `ascDriversVehicles.present=true` and specific `blockerCode` values already appear even while top-level route remains `ADVISOR_OTHER`.

## Scenario table
| Scenario | Reported route | Confidence | Expected route | Status | Key evidence |
|---|---:|---:|---:|---|---|
| `live-entry-begin-quoting-start` | `ENTRY_CREATE_FORM` | `0.84` | `ENTRY_CREATE_FORM` | `ok` | none |
| `live-entry-create-new-prospect-form` | `ENTRY_CREATE_FORM` | `0.84` | `ENTRY_CREATE_FORM` | `ok` | none |
| `live-entry-standardized-address-alert` | `ENTRY_CREATE_FORM` | `0.78` | `ENTRY_CREATE_FORM_WITH_STANDARDIZED_ADDRESS_BLOCKER` | `partial_new_blocker` | blocker=alert:STANDARDIZED_ADDRESS_ALTERNATIVE_CITY_ZIP |
| `live-product-overview-grid-route-gap` | `ADVISOR_OTHER` | `0.45` | `PRODUCT_OVERVIEW` | `route_gap` | none |
| `live-rapport-manual-vehicles-selected` | `RAPPORT` | `0.88` | `RAPPORT` | `ok` | rapportVehicles=6 |
| `live-select-product-complete-ready` | `SELECT_PRODUCT` | `0.92` | `SELECT_PRODUCT` | `ok` | selectProductReady=True |
| `live-asc-consumer-reports-route-gap` | `ADVISOR_OTHER` | `0.45` | `CONSUMER_REPORTS` | `route_gap` | none |
| `live-asc-drivers-vehicles-unresolved-driver-route-gap` | `ADVISOR_OTHER` | `0.45` | `ASC_DRIVERS_VEHICLES` | `route_gap` | ascPresent=True ascBlocker=ASC_DRIVERS_VEHICLES_ROWS_UNRESOLVED |
| `live-asc-remove-driver-modal-route-gap` | `ADVISOR_OTHER` | `0.45` | `ASC_DRIVERS_VEHICLES_WITH_REMOVE_DRIVER_MODAL` | `route_gap_blocker_known` | blocker=active:ASC_REMOVE_DRIVER_MODAL:<PERSON_REDACTED>; ascPresent=True ascBlocker=ASC_REMOVE_DRIVER_MODAL_OPEN |
| `live-asc-vehicle-modal-route-gap` | `ADVISOR_OTHER` | `0.45` | `ASC_DRIVERS_VEHICLES_WITH_VEHICLE_MODAL` | `route_gap_blocker_known` | blocker=active:ASC_VEHICLE_MODAL:<VEHICLE_REDACTED>; ascPresent=True ascBlocker=ASC_VEHICLE_MODAL_OPEN |

## Priority fixes implied by the sanitized scans
1. Add route-classification fixtures for live ASCPRODUCT substates so `advisor_state_snapshot.route` is promoted from `ADVISOR_OTHER` to `CONSUMER_REPORTS` or `ASC_DRIVERS_VEHICLES` when nested evidence already proves the substate.
2. Add a standardized-address read-only status path. It should expose a stable blocker code such as `ENTRY_STANDARDIZED_ADDRESS_ALERT`, detected heading, whether postal-record alternative exists, and safe next action as read-only evidence.
3. Add a Product Overview live snapshot fixture. Because the URL is `/apps/intel/102/overview` but product tile evidence was missing from this snapshot, the route may be classified as Product Overview with a low/no-mutation allowed action unless tile evidence is confirmed by `product_overview_tile_status`.
4. Preserve the safety rule: route promotion alone should not authorize mutation. Mutating actions still require specific status ops and pre/postcondition checks.

## Files generated
- `advisor_live_snapshots_sanitized_20260512.json`: combined sanitized bundle.
- `sanitized_advisor_live_snapshots_20260512/*.json`: one sanitized scenario per source scan.
