# Sidecar Manual Validation Findings

Run id: `sidecar-work-live-validation-20260513`

## Findings

1. The scan-only CDP sidecar completed a read-only manual validation run. The archived run contains 17 scan outputs produced by `advisor_state_snapshot`.

2. Sanitized route states and page categories observed:
   - `ADVISOR_OTHER` on `/apps/foundations/101/homepage`
   - `ENTRY_CREATE_FORM` on `/apps/intel/102/start`
   - `DUPLICATE_CURRENT_CUSTOMER` on `/apps/intel/102/start`
   - `PRODUCT_OVERVIEW` on `/apps/intel/102/overview`
   - `RAPPORT` on `/apps/intel/102/rapport`
   - `ASC_DRIVERS_VEHICLES` on `/apps/ASCPRODUCT/{id}/`
   - `COVERAGES` on `/apps/foundations/{id}/coverages`
   - `STANDARDIZED_ADDRESS_ALERT`
   - `ASC_PRIOR_INSURANCE_HISTORY_UNSUPPORTED`
   - `COVERAGES_PROMPT_OR_BLOCKER`
   - `UNKNOWN_UNSAFE`

3. The archive system worked. The latest pointer remained separate from the run archive, and the run directory contains numbered route/op-based scan files plus `run_summary.json`.

4. `run_summary.json` updated `scanCount` and `countsByRoute`. The sanitized count is 17 scans: `ADVISOR_OTHER` 4, `ENTRY_CREATE_FORM` 3, `DUPLICATE_CURRENT_CUSTOMER` 1, `PRODUCT_OVERVIEW` 1, `RAPPORT` 1, `ASC_DRIVERS_VEHICLES` 5, and `COVERAGES` 2.

5. The sidecar remained read-only. The evidence contains state reads only through `advisor_state_snapshot`; no click, fill, typing, navigation, screenshot, submit, or AHK behavior is represented in the sanitized evidence.

6. Coverages classified as unsafe/no-action due to prompts or blockers. Both observed Coverages scans were sanitized as `COVERAGES_PROMPT_OR_BLOCKER`, with unsafe set to `1` and no allowed next action.

7. An unsupported ASC prior-insurance-history page was observed and sanitized as `ASC_PRIOR_INSURANCE_HISTORY_UNSUPPORTED`. This is a recurring business field/page, not a mutation target.

8. Recommended future improvement: add a read-only ASC prior-insurance-history snapshot/classifier route that reports the presence and status of the prior-insurance-duration fields without answering them. Prior insurance duration must be supplied by known lead data or client verification; do not assume a default such as `3+ years`.

9. No raw logs or customer data were staged. Raw run files remain under ignored `logs/` paths and this sanitized evidence contains no customer names, addresses, VINs, phone numbers, emails, DOBs, ages, quote amounts, policy/customer IDs, raw page text, screenshots, or full dynamic URLs.
