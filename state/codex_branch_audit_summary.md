# Codex Branch Audit Summary

Codex performed a read-only branch audit comparing the runner baseline and Hermes work.

Important caveat:
The audit was run against a different local workspace path, not the main PC repo path. Treat it as diagnostic evidence only. Re-verify everything on the main PC repo:

C:\Users\Pablo\Desktop\script\Final_V5.6_js_operator_refactor

Key findings to verify:

1. Branch state
- Baseline branch was origin/feature/advisor-resident-runner.
- Hermes branch had multiple unique commits for resident transport, modular extraction, RAPPORT, Select Product, and ASC changes.
- A local branch in the audit had an extra RAPPORT commit not necessarily present on origin/Hermes.

2. Runtime/log safety
- Codex found runtime/log/scan files appearing in the Hermes branch diff:
  advisor_quote_trace.log
  advisor_scan_latest.json
  advisor_js_injection_metrics_latest.json
  run_state.json
  devtools_bridge_returns.log
  logs/hermes_github/*
- These must not be committed or promoted.
- Remove from Git tracking if present and ensure .gitignore covers them.

3. Generated JS
- Codex found generated JS drift on an audited local branch.
- Verify with:
  node assets/js/advisor_quote/build_operator.js --check
- If drift exists, rebuild with build_operator.js and rerun smoke tests.

4. Vehicle DB / LFS
- data/vehicle_db_compact.json was still a Git LFS pointer in the audit.
- Do not expand or commit the large JSON.
- Preserve the LFS pointer.

5. Resident transport
- Resident read/status transport direction is good.
- Full injection fallback still exists.
- copy(String(...)) result contract is preserved.
- Resident mutation transport remains disabled by default.
- Preserve this architecture.

6. RAPPORT review required
Review RAPPORT changes around:
- stale/incomplete Add Car/Truck rows
- VIN-backed potential card confirmation
- unknown vehicle deferral
- motorcycle/ORV exclusion from Auto
- Start Quoting scoped Add Product
- avoiding broad sidebar Add Product except as explicit fallback

7. ASC review required
Review ASC changes around:
- inline participant panel fill/save
- optional missing controls
- save-disabled reasons
- ledger retry behavior
- spouse policy unchanged unless explicitly requested

Required next step:
Before any more feature work, re-run this verification on the main PC repo:

git fetch origin --prune
git status --short --branch
git branch -vv
git log --oneline --decorate -10
node assets/js/advisor_quote/build_operator.js --check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1

If logs/scans are tracked, remove them from Git tracking and commit cleanup.
If generated JS drift exists, fix it and commit separately.
Only after branch hygiene is clean should RAPPORT or ASC business patches continue.
