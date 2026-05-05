# Advisor Vehicle DB Matching Redesign

This quick fix was implemented on `feature/advisor-resident-runner` by explicit instruction. It does not modify resident-runner infrastructure and does not enable the resident runner by default.

## DB Location

- Canonical source: `data/vehicle_db_compact.json`
- Runtime lookup index: `data/vehicle_db_runtime_index.tsv`
- Index builder: `tools/build_vehicle_runtime_index.js`

The compact DB is not embedded in `assets/js/advisor_quote/ops_result.js`. JavaScript remains a DOM status/action executor. AHK loads the derived TSV index from `domain/advisor_vehicle_catalog.ahk`.

## Loader And Cache

`AdvisorVehicleDbLoad()` reads `data/vehicle_db_runtime_index.tsv` once per AHK process and caches:

- metadata (`yearMin`, `yearMax`, counts)
- flat DB records by exact year and Advisor make label/family
- Advisor make labels by year and canonical make family

`AdvisorVehicleDbGet()` returns the same cached object. Missing or malformed index data returns a bounded object with `loaded=false` and `error=...`; callers get `UNKNOWN`/`PARTIAL` instead of repeated file reads or unsafe matching.

## Resolver Contract

`AdvisorVehicleDbResolveLeadVehicle(year, make, model, vin := "")` returns:

- `result=RESOLVED|PARTIAL|UNKNOWN|AMBIGUOUS`
- input year/make/model/VIN
- canonical make and model when available
- DB-derived Advisor make labels
- DB-derived model aliases and normalized model keys
- bounded possible match summaries
- confidence and reason

Matching requires exact year when a year exists. Make matching uses DB-derived Advisor labels/family such as `TOY. TRUCKS`, `FORD TRUCKS`, and `RAM TRUCKS`. Model matching uses strict normalized aliases/keys from the DB-derived runtime index. Broad prefix evidence is used only to return `AMBIGUOUS`; it is not promoted to a safe match.

Preserved non-overmatch guards:

- Prius does not match Prius Prime
- Transit does not match Transit Connect
- F150 does not match F250
- Silverado 1500 does not match Silverado 2500
- CR-V does not match HR-V

## RAPPORT Behavior

For each complete lead vehicle, Gather Data / RAPPORT now resolves the vehicle through the DB and then reads Advisor evidence:

- confirmed cards are checked first
- exactly one DB-backed confirmed card satisfies the vehicle
- potential/public-record cards are scoped and confirmed only when exactly one DB-backed card matches
- if a matching card opens Edit Vehicle, the edit handler completes or updates the panel and verifies commit
- unmatched vehicles are skipped/deferred with `VEHICLE_DEFERRED_NO_DB_CARD_MATCH`
- ambiguous DB/card evidence is skipped/deferred with `VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH`

RAPPORT no longer constructs unmatched vehicles from broad Add Car or Truck dropdowns. It does not call `prepare_vehicle_row` for unmatched RAPPORT vehicles and does not select the first model from a broad dropdown. Existing stale-row cleanup remains only for rows already left open by an earlier run after final confirmed-vehicle reconciliation proves the row is safe to cancel.

Skipped/deferred vehicles are logged but excluded from the final expected confirmed-vehicle list. If no vehicle is safely satisfied and Advisor still requires a vehicle, the workflow fails with `NO_SAFE_RAPPORT_VEHICLE_MATCH` and includes deferred vehicle summaries plus DB resolver diagnostics.

## Edit Vehicle Update Rule

If an Edit Vehicle panel is open and required Year, Manufacturer, Model, and required Sub-Model fields are populated, and `Update` is enabled, JavaScript returns `UPDATE_REQUIRED_READY` from `gather_vehicle_edit_status`. `handle_vehicle_edit_modal` clicks `Update` and returns `UPDATED` with `method=complete-panel-update-clicked`.

AHK wraps this in a two-attempt loop. After each Update click it verifies the matching vehicle becomes confirmed or the scoped Edit Vehicle panel closes. If the panel remains open and no matching confirmed card appears, the workflow fails with `VEHICLE_EDIT_UPDATE_DID_NOT_COMMIT`. It must not return `NO_ACTION_NEEDED` while a complete enabled Update panel remains open.

## Fallback Policy

The previous small hard-coded make/model alias rules remain only as fallback when DB lookup misses or the DB cannot be loaded. Fallback use does not broaden fuzzy matching and does not permit RAPPORT dropdown construction for unmatched vehicles.

## Safety Codes

- `VEHICLE_DEFERRED_NO_DB_CARD_MATCH`
- `VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH`
- `NO_SAFE_RAPPORT_VEHICLE_MATCH`
- `VEHICLE_EDIT_UPDATE_DID_NOT_COMMIT`
- `VEHICLE_SUBMODEL_REQUIRED_UNRESOLVED`
