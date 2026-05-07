# Restructure Targets Audit

Captured: 2026-05-06

This audit is intentionally direct. It covers current structure, not historical intent.

## Structurally Sound Now

- The workflow has real state handlers instead of one flat monolith.
- The JS operator has a source/build/runtime contract. `ops_result.js` is generated and should not be edited manually.
- Vehicle matching has a real DB-backed AHK owner in `domain/advisor_vehicle_catalog.ahk`.
- Rapport vehicle matching no longer depends only on fuzzy text.
- Product Overview grid handling is separated from the older Select Product form.
- Customer Summary is now a first-class state.
- Snapshot ops are read-only and provide useful route/blocker evidence.
- ASC Drivers/Vehicles has a ledger loop that chooses one action at a time and verifies progress.
- Remove-driver reason selection returns diagnostics and is verified before save.
- AutoHotkey validation policy is explicit and bounded.
- Resident runner is separated from production mutation flow and is disabled by default.

## Still Fragile

- `workflows/advisor_quote_workflow.ahk` is still too large and owns too many concerns.
- `assets/js/advisor_quote/src/operator.template.js` is also too large and mixes DOM reads, DOM mutations, business policy, state detection, snapshots, and runner code.
- Active docs conflict on Rapport unmatched vehicle behavior. Current code allows controlled DB-backed add; one scan workflow note still says do not open Add Car or Truck for unmatched vehicles.
- ASC spouse override is now committed default behavior, but the policy is still spread across DB settings, AHK ledger selection, and JS participant modal behavior.
- RAPPORT snapshot detects stale add rows but AHK treats them as an unhandled active blocker.
- Start Quoting logic is spread across Product Overview flags, Rapport status reads, scoped handoff, and recovery paths.
- ASC spouse policy is split across AHK ledger evaluation and JS participant resolver.
- Legacy Drivers/Vehicles functions remain in the file after the ledger loop and can confuse future patches.
- The generic `click_by_text` and broad wait ops remain available. They are useful but dangerous if called from new patches without a scoped reason.

## Refactor Next

Refactor only after the current live failure is understood from logs and a sanitized scan. The next restructuring target should be narrow: make the RAPPORT snapshot blocker gate route stale Gather add rows safely.

The current latest failure is not a missing selector in the main vehicle loop. It is the snapshot gate stopping on `GATHER_STALE_ADD_VEHICLE_ROW_OPEN`. Patch the gate first, or run a read-only audit if the stale row shape is unclear.

## Do Not Touch Yet

- Do not rewrite the resident runner into the production engine.
- Do not move large blocks between files while there are active live RAPPORT/ASC failures.
- Do not edit `assets/js/advisor_quote/ops_result.js` manually.
- Do not broaden vehicle dropdown matching.
- Do not weaken DB ambiguity handling.
- Do not remove legacy functions until call sites are proven inactive and tests/logs cover the replacement path.
- Do not stage logs, scans, CRM data, or customer data.
- Do not patch generic DevTools bridge behavior to fix a business-logic failure unless bridge logs prove the bridge is the blocker.
- Do not run raw AHK diagnostics.

## Old Logic Likely Still Present

These paths look like old or fallback logic and should eventually be retired or isolated after call-site proof:

- `AdvisorQuoteAddVehicleInGatherData()`: older direct vehicle add path. Current controlled path is `AdvisorQuoteAddCompleteDbResolvedVehicle()`.
- `AdvisorQuoteResolveDrivers()`, `AdvisorQuoteResolveVehicles()`, and `AdvisorQuoteAscSaveAndContinueIfReady()`: older ASC reconciliation helpers remain after the ledger implementation.
- `AdvisorQuoteHandleOpenModals()`: still uses modal-exists checks and generic modal handling. The ledger/snapshot path should own ASC blockers.
- JS ops `list_driver_slugs`, `driver_is_already_added`, `find_vehicle_add_button`, and `vehicle_marked_added`: older row/card helpers remain available.
- `AdvisorQuoteOpenSelectProductFallbackFromGatherData()`: legacy fallback is still present but should remain gated behind Product Overview Auto verification.
- Generic `click_by_id` and `click_by_text`: keep as low-level bridge utilities, not policy-level routing.

## Policy Still Mixed With DOM Logic

Policy in JS should be reduced over time:

- ASC spouse selection and age-window resolution is partly in JS.
- Participant modal required-field policy is partly in JS.
- Vehicle card scoring and dropdown ambiguity handling is partly in JS.
- Start Quoting readiness and Product Overview tile evidence are partly in JS.
- Incident reason selection is a policy string passed to JS, but JS owns label matching and clicking.

AHK should own policy decisions. JS should read status or perform a narrow, already-approved action.

## Snapshots Should Be Used More

Use snapshots more in these places:

- RAPPORT stale add-row blocker resolution.
- Start Quoting readiness before scoped Add Product handoff.
- Product Overview after Save & Continue when transitions are inconsistent.
- Consumer Reports ASCPRODUCT substates before routing forward.
- Incidents/Quote Landing distinction after Drivers/Vehicles save.
- Active modal/panel checks before legacy modal handlers.

## Runner Should Stay Separate

The runner should remain:

- disabled by default
- read-only by default
- tiny-bridge optimized for bounded status reads
- separate from mutating workflow actions
- treated as an optimization, not a correctness dependency

Do not move business patches into the runner until per-op logic is stable and covered.

## Generated JS Size And Console Pressure

Current approximate sizes:

- `assets/js/advisor_quote/src/operator.template.js`: 327 KB, about 6.6K lines.
- `assets/js/advisor_quote/ops_result.js`: 338 KB, about 6.9K lines.

Every per-op injection pushes a large script through DevTools. That is still a pressure point:

- empty results cause retries and trace noise
- large payloads increase paste/clipboard failure exposure
- generated runtime drift must be caught by `build_operator.js --check`
- more code in the template makes console paste failures harder to debug

The tiny resident bridge is the right direction for repeated read-only polling, but not ready to replace production actions.

## Recommended Next 5 Restructure Steps

| Order | Step | Risk | Validation requirement |
| --- | --- | --- | --- |
| 1 | Add a narrow RAPPORT stale add-row decision path in `AdvisorQuoteResolveGatherSnapshotBlockers()` using the existing `gather_stale_add_vehicle_row_status` and `cancel_stale_add_vehicle_row` ops. | Medium | JS smoke for stale-row fixture if present or add sanitized fixture; AHK checker; live sanitized scan before patch if row shape is uncertain. |
| 2 | Split ASC spouse policy into a small AHK policy helper section and make JS participant resolver a narrower field applier/status resolver. | High | AHK helper tests for Single, Married exact spouse, unique age-window, ambiguous, override enabled/disabled; JS smoke for participant resolver. |
| 3 | Isolate legacy ASC helpers behind clear names or remove only after call-site proof. | Medium | Search/call-site audit, AHK checker, JS smoke, one live Drivers/Vehicles validation. |
| 4 | Extract Rapport vehicle orchestration into a dedicated AHK module or section with DB add, confirm-card, partial promotion, stale-row cleanup, and final guard separated. | High | AHK helper tests for classification and DB resolver; JS smoke for vehicle ops; live sanitized RAPPORT validation. |
| 5 | Move repeated read-only waits/status reads to resident runner only after per-op parity is proven. | High | Runner smoke tests, bridge log audit, before/after timing and empty-result comparison, no business behavior changes in same patch. |
