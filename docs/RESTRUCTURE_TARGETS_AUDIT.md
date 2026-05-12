# Restructure Targets Audit

Captured: 2026-05-06

Historical status: this audit captured `feature/advisor-resident-runner` on 2026-05-06. It remains useful as a risk inventory, but it is not the current source of truth for `hermes-state-snapshot-foundation` after commit `87c1bbe`. Use `CODEX_ARCHITECTURE_CONTINUATION_AUDIT.md`, `docs/PROJECT_ARCHITECTURE_AUDIT.md`, `ADVISOR_PRO_SCAN_WORKFLOW.md`, `docs/ADVISOR_JS_OPERATOR_CONTRACT.md`, and `docs/ADVISOR_VEHICLE_DB_MATCHING_REDESIGN.md` for current behavior.

At capture time, this audit was intentionally direct and covered then-current structure, not historical intent. Current branch behavior is documented in the source-of-truth docs listed above.

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
- Historical at capture: active docs conflicted on Rapport unmatched vehicle behavior. Current docs now align on controlled DB-backed add for complete DB-resolved vehicles and defer/fail-safe handling for partial, unknown, ambiguous, duplicate, or unsafe vehicles.
- ASC spouse override is now committed default behavior, but the policy is still spread across DB settings, AHK ledger selection, and JS participant modal behavior.
- RAPPORT stale add-row handling remains high-risk, but current branch docs no longer treat it as an always-unhandled active blocker. Detection, detail reads, safe cleanup, and safe commit policy are owned by the RAPPORT blocker resolver and vehicle helpers.
- Start Quoting logic is spread across Product Overview flags, Rapport status reads, scoped handoff, and recovery paths.
- ASC spouse policy is split across AHK ledger evaluation and JS participant resolver.
- Legacy Drivers/Vehicles functions remain in the file after the ledger loop and can confuse future patches.
- The generic `click_by_text` and broad wait ops remain available. They are useful but dangerous if called from new patches without a scoped reason.

## Refactor Next

Refactor only after the current live failure is understood from logs and a sanitized scan. Historical recommendation at capture was to make the RAPPORT snapshot blocker gate route stale Gather add rows safely.

Current branch docs now describe stale Gather add-row detection and cleanup as implemented behavior. The next safe work in this area is regression coverage and sanitized scan verification unless a new trace proves the behavior is still failing.

## Do Not Touch Yet

- Do not rewrite the resident runner into the production engine.
- Do not move large blocks between files while there are active live RAPPORT/ASC failures.
- Do not edit `assets/js/advisor_quote/ops_result.js` manually.
- Edit Advisor JS source under `assets/js/advisor_quote/src/` and use `assets/js/advisor_quote/build_operator.js` to regenerate/check the runtime.
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

Current approximate sizes after the 2026-05-12 continuation audit:

- `assets/js/advisor_quote/src/operator.template.js`: about 407 KB, about 8.0K lines.
- `assets/js/advisor_quote/ops_result.js`: about 431 KB, about 8.6K lines.

Every per-op injection pushes a large script through DevTools. That is still a pressure point:

- empty results cause retries and trace noise
- large payloads increase paste/clipboard failure exposure
- generated runtime drift must be caught by `build_operator.js --check`
- more code in the template makes console paste failures harder to debug

The tiny resident bridge is the right direction for repeated read-only polling, but not ready to replace production actions.

## Recommended Next 5 Restructure Steps

| Order | Step | Risk | Validation requirement |
| --- | --- | --- | --- |
| 1 | Historical at capture: add a narrow RAPPORT stale add-row decision path. Current branch docs now describe this as implemented; next work should add/verify stale-row fixtures and sanitized scan regression evidence before changing behavior again. | Medium | JS smoke for stale-row fixture if present or add sanitized fixture; AHK checker only after AHK changes; live sanitized scan before any new behavior patch if row shape is uncertain. |
| 2 | Split ASC spouse policy into a small AHK policy helper section and make JS participant resolver a narrower field applier/status resolver. | High | AHK helper tests for Single, Married exact spouse, unique age-window, ambiguous, override enabled/disabled; JS smoke for participant resolver. |
| 3 | Isolate legacy ASC helpers behind clear names or remove only after call-site proof. | Medium | Search/call-site audit, AHK checker, JS smoke, one live Drivers/Vehicles validation. |
| 4 | Extract Rapport vehicle orchestration into a dedicated AHK module or section with DB add, confirm-card, partial promotion, stale-row cleanup, and final guard separated. | High | AHK helper tests for classification and DB resolver; JS smoke for vehicle ops; live sanitized RAPPORT validation. |
| 5 | Move repeated read-only waits/status reads to resident runner only after per-op parity is proven. | High | Runner smoke tests, bridge log audit, before/after timing and empty-result comparison, no business behavior changes in same patch. |
