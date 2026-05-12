# Codex prompt — Advisor operator contract inventory / productization freeze

You are working in:
C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor

Current branch:
hermes-state-snapshot-foundation

Task:
Create a productization foundation contract inventory without changing runtime behavior.

Context:
The previous patch promoted live Advisor snapshot route classifications and was read-only. A post-patch live recapture is stored under docs/productization/live_snapshot_evidence/2026-05-12/post_classifier_recapture/. It verifies:
- ENTRY_CREATE_FORM and ENTRY_STANDARDIZED_ADDRESS_ALERT blocker
- CUSTOMER_SUMMARY_PREFILL_GATE
- PRODUCT_OVERVIEW with URL-only evidence and mutation blocked
- RAPPORT
- SELECT_PRODUCT
- ASC_DRIVERS_VEHICLES main page
- ASC inline participant panel blocker
- ASC remove-driver modal blocker
- ASC vehicle modal blocker

Hard rules:
- Do not change AHK workflow behavior.
- Do not change JS operator behavior.
- Do not edit assets/js/advisor_quote/ops_result.js manually.
- Do not implement Playwright yet.
- Do not add licensing, backend, Tauri, installer, or desktop shell.
- Do not stage logs, scans, screenshots, raw leads, raw VINs, DOBs, emails, phones, addresses, quote data, traces, or support zips.
- Preserve all existing op names, return fields, status strings, route names, and AHK hotkeys.

Goal:
Inventory every Advisor JS op that AHK calls and add a guard so future productization work cannot accidentally remove or rename those ops.

Files to inspect:
- docs/ADVISOR_JS_OPERATOR_CONTRACT.md
- docs/PROJECT_ARCHITECTURE_AUDIT.md
- ADVISOR_PRO_SCAN_WORKFLOW.md
- workflows/advisor_quote_workflow.ahk
- workflows/advisor/advisor_quote_transport.ahk
- workflows/advisor/advisor_quote_product_overview.ahk
- workflows/advisor/advisor_quote_rapport.ahk
- workflows/advisor/advisor_quote_rapport_vehicles.ahk
- workflows/advisor/advisor_quote_consumer_reports.ahk
- assets/js/advisor_quote/src/operator.template.js
- assets/js/advisor_quote/build_operator.js
- tests/advisor_quote_ops_smoke.js

Tasks:
1. Search all AHK files for Advisor JS op invocations.
2. Create docs/productization/ADVISOR_OPERATOR_CONTRACT_INVENTORY.md.
3. For each AHK-called op, list:
   - op name
   - AHK caller file/function if clear
   - purpose
   - mutating vs read-only
   - expected result shape if clear
   - high-risk status fields or route names
4. Add or extend a smoke assertion that verifies all inventoried AHK-called op names still exist in the generated Advisor JS runtime.
5. Confirm .gitignore excludes logs, scans, screenshots, traces, support packages, raw leads, and run bundles.
6. Do not change runtime behavior.

Validation commands must use the Codex Node runtime path:

```powershell
$NODE="C:\Users\sflzsl7k\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
& $NODE assets/js/advisor_quote/build_operator.js --check
& $NODE .\tests\advisor_quote_ops_smoke.js
```

Run AHK checker only if AHK files changed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

Output:
- exact files changed
- op count inventoried
- test names/assertions added
- validation output
- confirmation that no runtime behavior changed
- confirmation that generated JS was not hand-edited
