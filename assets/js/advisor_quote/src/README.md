# Advisor Quote Operator Source

`operator.template.js` is the current source mirror for the Advisor Pro JavaScript operator.

`../build_operator.js` generates `../ops_result.js` from this source file. The generated `ops_result.js` remains the single AHK-injected runtime file and must continue to preserve:

- `@@OP@@`
- `@@ARGS@@`
- `copy(String(...))`
- every existing op name and return contract

Phase 1A intentionally did not refactor logic or split helpers. Phase 1B extracts only pure helpers into source snippets:

- `core/text.js` contains pure text and normalization helpers.
- `core/output.js` contains pure line/check helpers.
- `build_operator.js` inlines these snippets into `operator.template.js`.

Phase 1C extracts only pure matcher helpers into source snippets:

- `matchers/vehicle.js` contains pure vehicle text/scoring helpers.
- `matchers/duplicate.js` contains pure duplicate text/scoring helpers.
- DOM-based vehicle and duplicate helpers remain in `operator.template.js`.

Phase 1D-A extracts only foundational read/support helpers into source snippets:

- `core/dom.js` contains foundational DOM read/support helpers.
- `core/args.js` contains URL/text/selector arg normalization helpers.
- `core/alerts.js` contains visible-alert collection helpers.
- Click helpers, field mutation helpers, page detector helpers, and wait helpers remain in `operator.template.js`.

Phase 1D-B1 extracts only field/value mutation helpers that do not focus or click into source snippets:

- `core/fields.js` contains native value setter/event helpers.
- `setInputValue` and `setSelectValue` remain in `operator.template.js` because they call `focus()`.
- Click helpers, semantic answer helpers, page detector helpers, wait helpers, and op handlers remain in `operator.template.js`.

Phase 1D-B2 extracts only generic click/target interaction helpers into source snippets:

- `core/click.js` contains generic click/target interaction helpers.
- Focused field setters, semantic answer helpers, page detector helpers, wait helpers, and op handlers remain in `operator.template.js`.

`ops_result.js` remains the single runtime file. Future phases can continue extracting source modules only when the generated runtime remains byte-for-byte compatible or the contract tests prove an intentional change.
