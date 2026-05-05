# Advisor Vehicle DB Matching Redesign

Status: current implemented behavior on `feature/advisor-resident-runner`.
Scope: Gather Data / Rapport vehicle matching only.

This document is part of the active Markdown set. It records durable behavior that should remain true after the vehicle DB quick fix, not a one-off patch log.

## Runtime Data

- Compact DB source: `data/vehicle_db_compact.json`
- Runtime lookup index: `data/vehicle_db_runtime_index.tsv`
- Index builder: `tools/build_vehicle_runtime_index.js`
- AHK owner: `domain/advisor_vehicle_catalog.ahk`
- Browser executor: `assets/js/advisor_quote/ops_result.js`

The compact DB is not embedded in the JS operator. AHK loads the derived TSV once per process and passes only bounded match arguments into JS.

## DB Audit Summary

- Top-level DB keys: `meta`, `indexes`, `exceptions`
- Shape: indexed, not flat
- Covered years: `2000-2026`
- Indexed families include makes by year, manufacturer options, models, submodels, exact correlation, VIN patterns, and year/make/model VIN-pattern buckets
- Advisor manufacturer labels exist, including truck/vans buckets such as `TOY. TRUCKS`, `FORD TRUCKS`, and `RAM TRUCKS`
- The source DB does not expose one canonical alias table; runtime aliases are derived from model and submodel evidence

Confirmed sample coverage:

- Honda CR-V / CRV
- Toyota Prius and Prius Prime
- Toyota Highlander under `TOY. TRUCKS`
- Ford F150, F250, and Mustang
- Jeep Wrangler Unlimited, including truncated Advisor text `WRANGLER UNLIMITE`
- Nissan Cube
- Dodge/Ram truck families
- Kia K5

Mitsubishi Fuso was not present in the audited DB coverage and must resolve safely as `UNKNOWN`.

## Resolver Contract

`AdvisorVehicleDbResolveLeadVehicle(year, make, model, vin := "")` returns a bounded object with:

- `result=RESOLVED|PARTIAL|UNKNOWN|AMBIGUOUS`
- input year, make, model, and VIN
- canonical make and model when resolved
- Advisor make labels
- model aliases
- normalized model keys
- bounded possible match summaries
- confidence and reason

Safe matching rules:

- exact year is required when a lead year exists
- make matching uses DB make family and Advisor make labels
- model matching uses strict normalized DB aliases/keys
- VIN evidence may strengthen a card match, but does not override wrong year or wrong model-family evidence
- broad prefix evidence can return `AMBIGUOUS`; it must not be promoted into a resolved vehicle

Non-overmatch guards remain required:

- Prius must not match Prius Prime
- Transit must not match Transit Connect
- F150 must not match F250
- Silverado 1500 must not match Silverado 2500
- CR-V must not match HR-V

## Rapport Vehicle Flow

Gather Data / Rapport is now evidence-first:

1. Resolve each complete lead vehicle through the DB.
2. Read confirmed Advisor vehicle cards first.
3. If exactly one confirmed card matches exact year, DB make family/label, and DB-normalized model evidence, count the vehicle as satisfied.
4. Read potential/public-record cards only after confirmed-card preflight.
5. If exactly one scoped potential/public-record card matches the same DB-backed evidence, confirm that card.
6. If the confirm action opens an Edit Vehicle panel, complete or update the panel and verify commit.
7. If no safe existing Advisor card matches, skip/defer the vehicle.
8. If DB or card evidence is ambiguous, skip/defer or fail safe.
9. Final expected vehicle reconciliation includes only vehicles already satisfied or safely confirmed/updated from existing Advisor evidence.

Rapport must not construct unmatched vehicles from broad dropdowns. In this flow, unmatched lead vehicles do not open Add Car or Truck, do not call `prepare_vehicle_row`, and do not select the first model from a dropdown.

Skipped/deferred vehicles are logged but not counted as missing expected confirmed vehicles.

## Failure And Trace Codes

- `VEHICLE_DB_RESOLVER`
- `VEHICLE_DEFERRED_NO_DB_CARD_MATCH`
- `VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH`
- `NO_SAFE_RAPPORT_VEHICLE_MATCH`
- `VEHICLE_EDIT_UPDATE_DID_NOT_COMMIT`
- `VEHICLE_SUBMODEL_REQUIRED_UNRESOLVED`

If no vehicle is safely satisfied and Advisor still requires at least one vehicle, the workflow fails with `NO_SAFE_RAPPORT_VEHICLE_MATCH` and includes resolver diagnostics plus candidate/deferred vehicle summaries.

## Edit Vehicle Rule

If an Edit Vehicle panel is open and required fields are already populated, and `Update` is enabled, the workflow must click `Update`.

Required complete-panel evidence:

- year populated
- VIN populated or acceptable under existing policy
- manufacturer populated, including disabled selected controls
- model populated, including disabled selected controls
- required submodel populated, including disabled selected controls
- `Update` present and enabled

JS reports this as `UPDATE_REQUIRED_READY`. AHK then clicks Update through `handle_vehicle_edit_modal`, verifies the matching vehicle becomes confirmed or the scoped panel closes, and uses a two-attempt loop guard. A complete enabled panel must not return `NO_ACTION_NEEDED`.

## Fallback Policy

The old small make/model alias rules remain only as fallback for DB misses or DB load failure. Fallback logic must not broaden fuzzy matching and must not re-enable Rapport dropdown construction for unmatched vehicles.

## Validation

Required validation after JS or AHK changes:

```powershell
node assets/js/advisor_quote/build_operator.js --check
node assets/js/advisor_quote/build_operator.js
node assets/js/advisor_quote/build_operator.js --check
node .\tests\advisor_quote_ops_smoke.js
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

Use the bundled Node runtime if PATH `node` is unavailable. AutoHotkey validation must use the bounded toolchain checker; do not run raw interpreter or compiler diagnostics.
