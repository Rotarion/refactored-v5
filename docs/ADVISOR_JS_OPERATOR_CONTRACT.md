# Advisor JavaScript Operator Contract

Canonical status: stable prompt and contract path.

The detailed current operator overview is consolidated in `docs/PROJECT_ARCHITECTURE_AUDIT.md` under `JavaScript Operator Contract`. Keep this file as the durable entry point for prompts and audits that reference the original contract path.

## Runtime Contract

- Runtime file remains `assets/js/advisor_quote/ops_result.js`.
- Generated source starts at `assets/js/advisor_quote/src/operator.template.js`.
- Build script is `assets/js/advisor_quote/build_operator.js`.
- AHK renders `@@OP@@` and `@@ARGS@@` through `workflows/advisor_quote_workflow.ahk`.
- The browser return channel remains `copy(String(...))`.
- Do not edit `assets/js/advisor_quote/ops_result.js` manually. Edit the source template/snippets and regenerate through the build script.
- JavaScript remains a DOM executor and status reader. It does not load `data/vehicle_db_compact.json`; AHK passes bounded DB-derived make labels, model aliases, normalized model keys, and strict match flags into JS ops.

## Current Contract Notes

- Top-level ops and stable argument names are summarized in `docs/PROJECT_ARCHITECTURE_AUDIT.md`.
- DB-backed Rapport vehicle matching behavior is documented in `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md`.
- Read-only snapshot ops are `advisor_active_modal_status`, `gather_rapport_snapshot`, and `asc_drivers_vehicles_snapshot`.
- Snapshot ops return compact key/value blocks for route, active modal/panel, save gates, card/row counts, blocker codes, evidence, and missing data. They must not click, type, save, confirm vehicles, remove drivers, create quotes, or navigate.
- AHK wrappers are `AdvisorQuoteGetActiveModalStatus()`, `AdvisorQuoteGetGatherRapportSnapshot()`, and `AdvisorQuoteGetAscDriversVehiclesSnapshot()`. They parse the key/value blocks and log compact trace entries without changing production workflow decisions.
- Future page-level action handlers should prefer checking active modal/panel state before acting on the underlying page.
- Generated operator changes require `build_operator.js --check`, regeneration, another `--check`, and the Advisor JS smoke test.
