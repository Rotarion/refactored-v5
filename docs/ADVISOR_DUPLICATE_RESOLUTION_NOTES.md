# Advisor Duplicate Resolution Notes

Date: 2026-04-29

## Scope

This patch changes only duplicate prospect resolution inside `handle_duplicate_prospect`.

It does not change Customer Summary routing, Product Tile Grid selected-state detection, Product Tile Auto guard behavior, ASC/109 downstream handling, runtime state names, hotkeys, config, CRM/QUO, pricing, messaging, or lead parsing.

## Decision Rules

Select an existing profile only when the duplicate option has a strong identity match and the existing profile address matches the entered quote address.

Create a new profile when Advisor Pro shows the same person at an old or materially different address and a duplicate-page option labeled like `Create NEW profile using data you entered` is available.

Name/DOB alone is not enough to auto-select an existing profile when the address differs. Moved-address cases should preserve the newly entered quote address by selecting the create-new duplicate option.

## Address Matching

The operator normalizes case and punctuation before comparing address evidence. It checks the entered street number/street tokens, city, state, and ZIP when available.

A materially different address includes different ZIP, city/state, street number, or street name evidence. Missing or unclear address evidence fails safe unless the duplicate page provides a clear create-new profile option.

## Duplicate Page Targeting

The preferred create-new action is the duplicate-resolution radio/row for `Create NEW profile using data you entered`, followed by `Continue with Selected`.

Patch B2 tightened this for the live duplicate page shape:

1. Prefer a local row/container whose text contains `Create NEW profile using data you entered`.
2. If local row text is unavailable but the page has exactly two `sfmOption` radios and the expected existing/create-new text order, use `input[name="sfmOption"][value="0"]` as the create-new duplicate option.
3. If value evidence is missing in that exact two-radio layout, use the second `sfmOption` radio as a last duplicate-page radio fallback.

After the radio is selected, the operator waits briefly for `Continue with Selected` to become enabled and clicks it. `CREATE_NEW` should not be returned for the duplicate-radio path unless the radio is selected and Continue is clicked.

The lower `Create New Prospect` form button remains a fallback only for cases where no duplicate create-new radio/row is available and the page is not clearly offering a duplicate create-new option.

## Return Diagnostics

`handle_duplicate_prospect` keeps existing result values:

- `SELECT_EXISTING`
- `SELECTED_NO_CONTINUE`
- `CREATE_NEW`
- `FALLBACK_CONTINUE`
- `AMBIGUOUS_DUPLICATE`
- `FAILED`

Additional diagnostic fields may include:

- `addressDecision`
- `existingAddressMatch`
- `newProfileOptionFound`
- `continueClicked`
- `radioValue`
- `radioSelected`
- `continueButtonPresent`
- `continueButtonEnabled`
- `existingCandidateSummaries`
- `candidateSummaries`
- `failedFields`

## Remaining Live Validation

- Confirm a live moved-address duplicate page selects the `Create NEW profile using data you entered` radio option.
- Confirm `Continue with Selected` becomes enabled after that selection and advances to a forward Advisor route.
- Confirm a true same-address duplicate still selects the existing profile.

## Validation

- Initial `node assets/js/advisor_quote/build_operator.js --check` failed with expected drift before generation because the JS template changed.
- `node assets/js/advisor_quote/build_operator.js` passed and generated `assets/js/advisor_quote/ops_result.js`.
- Final `node assets/js/advisor_quote/build_operator.js --check` passed.
- `node .\tests\advisor_quote_ops_smoke.js` passed using bundled Codex Node.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1` passed: `SMOKE_VALIDATE=pass`, `MAIN_VALIDATE=pass`, `COMPILER_CHECK=skipped`.
- Toolchain artifact: `logs\toolchain_checks\20260429_093032`.
- `ops_result.js` before patch: `A77284B39D3F6628158804F37B5ABB6031A644D00AA73C48FC67F06E7CF27B16`.
- `ops_result.js` after patch: `D539DAF978F54CDB597746A395551556A8AB5C2DE9C0AF8D7C2F9230B0C1DB66`.

## Patch B2 Validation

- Initial `node assets/js/advisor_quote/build_operator.js --check` failed with expected drift before generation because the JS template changed.
- `node assets/js/advisor_quote/build_operator.js` passed and generated `assets/js/advisor_quote/ops_result.js`.
- Final `node assets/js/advisor_quote/build_operator.js --check` passed.
- `node .\tests\advisor_quote_ops_smoke.js` passed using bundled Codex Node.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1` passed: `SMOKE_VALIDATE=pass`, `MAIN_VALIDATE=pass`, `COMPILER_CHECK=skipped`.
- Toolchain artifact: `logs\toolchain_checks\20260429_095505`.
- `ops_result.js` before Patch B2: `D539DAF978F54CDB597746A395551556A8AB5C2DE9C0AF8D7C2F9230B0C1DB66`.
- `ops_result.js` after Patch B2: `1736ECA08A39EF79F2B2504BFAC23DAF06AE714B41B2C1AAD028F22D9181FA1E`.
