# Advisor JS Operator Refactor Plan

## Phase 1A: Build Scaffold

This phase adds a source/build scaffold only. It does not extract helpers, split modules, or change runtime behavior.

Files added:

- `assets/js/advisor_quote/src/operator.template.js`
- `assets/js/advisor_quote/src/README.md`
- `assets/js/advisor_quote/build_operator.js`

Runtime contract preserved:

- AHK still injects `assets/js/advisor_quote/ops_result.js`.
- `ops_result.js` remains a single-file runtime.
- `@@OP@@` and `@@ARGS@@` placeholders remain unchanged.
- `copy(String(...))` return behavior remains unchanged.
- Op names, return strings, key=value fields, selectors, waits, click logic, matchers, and scan JSON behavior are unchanged.

Build command:

```powershell
node assets/js/advisor_quote/build_operator.js
```

Check command:

```powershell
node assets/js/advisor_quote/build_operator.js --check
```

Smoke test command:

```powershell
node .\tests\advisor_quote_ops_smoke.js
```

## Next Phases

- Phase 1B: extract pure text/output helpers.
- Phase 1C: extract pure matcher helpers.
- Phase 1D-A: extract foundational DOM read/support helpers.
- Phase 1D-B1: extract field/value mutation helpers.
- Phase 1D-B2: extract click/target interaction helpers.
- Phase 1D-B3 or later: extract focused field setters and semantic/radio helpers, if needed.
- Phase 1E: extract state/wait helpers.
- Phase 1F: extract op handlers group-by-group.

Each phase should keep generating the same single injected `ops_result.js` runtime and should pass the build check and operator smoke tests before proceeding.

## Phase 1B: Pure Text/Output Helpers

Status: completed as a source-only extraction.

Phase 1B moves pure text/normalization helpers into `assets/js/advisor_quote/src/core/text.js` and pure line/check helpers into `assets/js/advisor_quote/src/core/output.js`. `build_operator.js` inlines those snippets back into `operator.template.js` at the original positions so generated `ops_result.js` remains byte-for-byte identical.

No op handlers, DOM helpers, selector logic, page detection, wait logic, click behavior, vehicle matching, duplicate matching, modal behavior, or AHK integration are changed in this phase.

## Phase 1C: Pure Matcher Helpers

Status: completed as a source-only extraction.

Phase 1C moves only pure vehicle text/scoring helpers into `assets/js/advisor_quote/src/matchers/vehicle.js` and pure duplicate text/scoring helpers into `assets/js/advisor_quote/src/matchers/duplicate.js`. `build_operator.js` inlines those snippets back into `operator.template.js` at the original positions so generated `ops_result.js` remains byte-for-byte identical.

DOM-based vehicle/duplicate helpers, selector scanning, click behavior, modal behavior, wait logic, page detection, op handlers, and AHK integration remain in `operator.template.js` unchanged.

## Phase 1D-A: Foundational DOM Read/Support Helpers

Status: completed as a source-only extraction.

Phase 1D-A moves foundational non-mutating DOM/read helpers into `assets/js/advisor_quote/src/core/dom.js`, URL/text/selector argument helpers into `assets/js/advisor_quote/src/core/args.js`, and visible-alert collection helpers into `assets/js/advisor_quote/src/core/alerts.js`. `build_operator.js` inlines those snippets back into `operator.template.js` at the original positions so generated `ops_result.js` remains byte-for-byte identical.

Phase 1D is intentionally split:

- Phase 1D-A: foundational DOM read/support helpers.
- Phase 1D-B1: native field value/event helpers.
- Phase 1D-B2: click/target interaction helpers.
- Phase 1D-B3 or later: focused field setters and semantic/radio helpers, if needed.
- Phase 1E: state/wait helpers.

Click behavior, field-setting behavior, page detector helpers, wait-condition logic, vehicle/duplicate DOM helpers, modal behavior, scan helper logic, op handlers, and AHK integration remain in `operator.template.js` unchanged.

## Phase 1D-B1: Field/Value Mutation Helpers

Status: completed as a source-only extraction.

Phase 1D-B1 moves only field/value mutation helpers that do not focus or click into `assets/js/advisor_quote/src/core/fields.js`. `setInputValue` and `setSelectValue` remain in `operator.template.js` because they call `focus()`. `build_operator.js` inlines the extracted snippet back into `operator.template.js` at the original position so generated `ops_result.js` remains byte-for-byte identical.

Phase 1D-B is intentionally split:

- Phase 1D-B1: field/value mutation helpers.
- Phase 1D-B2: click/target interaction helpers.
- Phase 1D-B3 or later: focused field setters and semantic/radio helpers, if needed.
- Phase 1E: state/wait helpers.

Focused field setters, click behavior, click target helpers, semantic answer helpers, page detector helpers, wait-condition logic, modal behavior, vehicle/duplicate DOM helpers, scan helper logic, op handlers, and AHK integration remain in `operator.template.js` unchanged.

## Phase 1D-B2: Click/Target Interaction Helpers

Status: completed as a source-only extraction.

Phase 1D-B2 moves only generic click/target interaction helpers into `assets/js/advisor_quote/src/core/click.js`. `build_operator.js` inlines those snippets back into `operator.template.js` at the original positions so generated `ops_result.js` remains byte-for-byte identical.

Focused field setters, semantic/radio helpers, page detector helpers, wait-condition logic, modal behavior, vehicle/duplicate DOM helpers, scan helper logic, op handlers, and AHK integration remain in `operator.template.js` unchanged.
