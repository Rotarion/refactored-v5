# Advisor Gather Data Vehicle Add Notes

Canonical status: stable prompt and workflow note path.

The detailed current Rapport vehicle behavior is consolidated in `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`. Keep this file as the durable entry point for prompts and audits that reference the original Gather Data vehicle path.

## Current Rapport Vehicle Contract

- Gather Data / Rapport vehicle handling is DB-backed and evidence-first.
- Default Rapport vehicle mode is `match-existing-then-add-complete`; `match-existing-only` remains supported for strict defer-only behavior.
- Canonical compact DB path is `data/vehicle_db_compact.json`; AHK uses the derived runtime index through `domain/advisor_vehicle_catalog.ahk`.
- Confirmed Advisor cards are read first. Exactly one DB-backed confirmed card can satisfy a lead vehicle.
- Potential/public-record cards can be confirmed only when exactly one scoped card matches exact year, DB make family/Advisor label, and DB-normalized model evidence.
- If no existing card matches and the lead vehicle is complete and DB-resolved, the workflow may add it through the controlled DB-backed Add Car/Truck flow.
- Partial, unknown, ambiguous, or unsafe add candidates are skipped/deferred with trace diagnostics such as `VEHICLE_DEFERRED_NO_DB_CARD_MATCH`, `VEHICLE_DEFERRED_DB_ADD_UNSAFE`, or `VEHICLE_DEFERRED_DB_MODEL_OPTION_AMBIGUOUS`.
- Ambiguous vehicles are skipped/deferred or fail safe with diagnostics such as `VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH`.
- Skipped/deferred vehicles are not counted as missing expected confirmed vehicles during final Rapport reconciliation.
- If Advisor requires a vehicle and no vehicle can be safely satisfied, the workflow fails with `NO_SAFE_RAPPORT_VEHICLE_MATCH`.

## Prohibited Rapport Behavior

- Do not construct unmatched Rapport vehicles from broad dropdowns.
- Do not open Add Car or Truck until confirmed and potential cards have been checked and no safe existing match exists.
- Do not call `prepare_vehicle_row` for a partial, unknown, ambiguous, duplicate, or DB-unresolved Rapport vehicle.
- Do not select the first model from a broad dropdown.

## Edit Vehicle Update Rule

If an Edit Vehicle panel is open, required fields are populated, and `Update` is enabled, the workflow must click `Update` and verify the panel closes or the matching vehicle becomes confirmed. A complete enabled panel must not return `NO_ACTION_NEEDED`.

See `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md` for resolver details, fallback policy, failure codes, and validation requirements.
