You are working in:
C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor

Current branch:
hermes-state-snapshot-foundation

Task:
Use the newly sanitized live Advisor state snapshots to add read-only route-classification/status fixture coverage and then patch only the read-only classifier if tests prove the current classifier is wrong.

This is not a mutation patch.

Hard rules:
- Do not change AHK workflow behavior.
- Do not change mutating JS operator behavior.
- Do not edit assets/js/advisor_quote/ops_result.js manually.
- Do not run live Advisor Pro workflows.
- Do not add raw names, addresses, VINs, phones, emails, DOBs, screenshots, quote data, or full raw page text to fixtures.
- Do not implement Playwright yet.
- Do not broaden vehicle matching.
- Do not alter RAPPORT one-safe-vehicle gate behavior.
- Route promotion must not authorize mutation by itself. Mutating actions still require route-specific status ops and pre/postcondition checks.

Sanitized input package:
- advisor_live_snapshots_sanitized_20260512.json
- sanitized_advisor_live_snapshots_20260512/*.json
- advisor_live_snapshot_findings_20260512.md

Live evidence summary:
1. ENTRY_CREATE_FORM begin/start classified correctly.
2. ENTRY_CREATE_FORM create-new-prospect classified correctly.
3. Standardized Address appears inside ENTRY_CREATE_FORM with blocking alert evidence. Need a dedicated read-only blocker/status code, not a blind action.
4. Product Overview Grid URL /apps/intel/102/overview was reported as ADVISOR_OTHER with confidence 0.45. Expected route: PRODUCT_OVERVIEW, but mutation must remain disallowed unless Auto tile/status evidence is verified.
5. RAPPORT classified correctly with rapport.present=true and vehicleCount populated.
6. SELECT_PRODUCT classified correctly with all required fields present.
7. Consumer Reports page under /apps/ASCPRODUCT/{id}/ was reported as ADVISOR_OTHER even though heading evidence showed order consumer reports. Expected route: CONSUMER_REPORTS.
8. ASC Drivers/Vehicles under /apps/ASCPRODUCT/{id}/ was reported as ADVISOR_OTHER even though ascDriversVehicles.present=true and blockerCode ASC_DRIVERS_VEHICLES_ROWS_UNRESOLVED. Expected route: ASC_DRIVERS_VEHICLES.
9. ASC Remove Driver modal was reported as ADVISOR_OTHER even though ascDriversVehicles.present=true and blockerCode ASC_REMOVE_DRIVER_MODAL_OPEN. Expected route: ASC_DRIVERS_VEHICLES with active blocker/modal evidence.
10. ASC Vehicle modal was reported as ADVISOR_OTHER even though ascDriversVehicles.present=true and blockerCode ASC_VEHICLE_MODAL_OPEN. Expected route: ASC_DRIVERS_VEHICLES with active blocker/modal evidence.

Files to inspect:
- docs/PROJECT_ARCHITECTURE_AUDIT.md
- ADVISOR_PRO_SCAN_WORKFLOW.md
- docs/ADVISOR_JS_OPERATOR_CONTRACT.md
- assets/js/advisor_quote/src/operator.template.js
- assets/js/advisor_quote/src/core/*.js
- assets/js/advisor_quote/src/matchers/*.js
- tests/advisor_quote_ops_smoke.js
- tests/fixtures/advisor_quote_operator/sanitized_dom_scenarios.json

Patch plan:
1. Add sanitized fixture coverage for these live snapshot shapes.
2. First make tests demonstrate the current route-classification gaps.
3. Patch only read-only route/snapshot classification if needed:
   - ASCPRODUCT + order-consumer-reports evidence => CONSUMER_REPORTS.
   - ASCPRODUCT + ascDriversVehicles.present / Drivers and vehicles evidence => ASC_DRIVERS_VEHICLES.
   - ASC remove-driver modal and ASC vehicle modal should remain blockers but route should no longer be generic ADVISOR_OTHER.
   - /apps/intel/102/overview should be PRODUCT_OVERVIEW or a low-confidence Product Overview candidate, but allowed mutating actions must remain gated by tile/status evidence.
   - Standardized Address alert should expose a stable blocker/status code such as ENTRY_STANDARDIZED_ADDRESS_ALERT or ENTRY_ADDRESS_STANDARDIZATION_BLOCKER.
4. Preserve existing public return fields and add backward-compatible fields only.
5. If generated JS source changes, run the required build/check/smoke sequence.

Validation:
- node .\assets\js\advisor_quote\build_operator.js --check
- node .\assets\js\advisor_quote\build_operator.js
- node .\assets\js\advisor_quote\build_operator.js --check
- node .\tests\advisor_quote_ops_smoke.js
- AHK checker only if AHK files changed:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1

Output:
- exact files changed
- route fixtures added
- classifier/status fields changed
- final test output
- confirmation that no mutating behavior changed
- confirmation that generated JS was not hand-edited
- any remaining live scans needed
