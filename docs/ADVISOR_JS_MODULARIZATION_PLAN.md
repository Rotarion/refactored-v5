# Advisor JS Modularization Implementation Plan

> For Hermes: implement mechanically in small extraction commits, preserving generated output and business behavior.

Goal: Stop growing `assets/js/advisor_quote/src/operator.template.js` as a monolithic JavaScript file while keeping `ops_result.js` output and Advisor Pro behavior unchanged.

Architecture: Keep `operator.template.js` as the assembly/root dispatch file and use the existing `/* @include ... */` build system to concatenate extracted source modules in deterministic order. Extract only cohesive helper/operation blocks whose dependencies are already declared earlier in the template, so no business policy moves from AHK into JS.

Tech Stack: Node.js build script, plain browser JavaScript, AutoHotkey v2 DevTools bridge caller.

---

## Target module map

1. `assets/js/advisor_quote/src/resident/command_bus.js`
   - Resident operator allowlists, registry/status helpers, `createAdvisorResidentOperator`, and `advisorResidentOperatorCommand`.
   - First safe extraction because it is contiguous and already isolated around the resident operator bootstrap/command entrypoint.

2. `assets/js/advisor_quote/src/resident/runner.js`
   - Resident runner state machine, event helpers, runner command dispatcher.
   - Extract after command bus validation because it is larger and has more internal moving parts.

3. `assets/js/advisor_quote/src/core/dispatch.js`
   - Final `switch (op)` dispatch table and dispatch-only helpers.

4. `assets/js/advisor_quote/src/ops/product_overview.js`
   - Product Overview DOM/status/action operations only.

5. `assets/js/advisor_quote/src/ops/rapport_snapshot.js`
   - RAPPORT page/snapshot reads only.

6. `assets/js/advisor_quote/src/ops/rapport_vehicle.js`
   - RAPPORT vehicle DOM reads/actions only.

7. `assets/js/advisor_quote/src/ops/asc_snapshot.js`
   - ASC snapshot/status reads only.

8. `assets/js/advisor_quote/src/ops/asc_driver_vehicle.js`
   - ASC driver/vehicle DOM reconciliation actions only.

9. `assets/js/advisor_quote/src/ops/incidents.js`
   - Incidents page DOM status/action functions only.

## Build script changes

No build-script behavior change is needed for the first extraction. `assets/js/advisor_quote/build_operator.js` already supports full-file includes and snippets under `src/` and validates required runtime markers.

Future build-script work, only if needed:
- Add clearer include-order diagnostics.
- Add duplicate include detection as a warning, not a behavior change.
- Keep output byte-for-byte generated from source includes.

## Source concatenation order

`operator.template.js` remains the root source in this order:

1. Existing core snippets (`core/text.js`, `core/dom.js`, `core/click.js`, `core/fields.js`, `core/output.js`, `core/args.js`, `core/alerts.js`, matchers).
2. Existing monolith-local operation helpers that the resident command bus depends on.
3. `/* @include resident/command_bus.js */` at the original resident operator block location.
4. Resident runner block, then later runner extraction include.
5. Final operation dispatch switch.

## No behavior-change guarantee

For each extraction:
- Move contiguous source text only.
- Replace the moved text with one include marker at the same location.
- Do not rename public functions.
- Do not change allowlists, retry behavior, result shape, copy output, or DOM selectors.
- Verify `ops_result.js` is byte-for-byte identical after rendering.

## Test plan

Run after each JS extraction:

```bash
node assets/js/advisor_quote/build_operator.js --check
node assets/js/advisor_quote/build_operator.js
node assets/js/advisor_quote/build_operator.js --check
node ./tests/advisor_quote_ops_smoke.js
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

Expected:
- Build check OK before and after render.
- Render reports `unchanged` for byte-for-byte extraction or writes identical generated output if line endings normalize.
- Smoke test passes.
- AHK toolchain smoke/main validation passes.

## First safe extraction task

1. Create `assets/js/advisor_quote/src/resident/command_bus.js`.
2. Move the contiguous resident operator command bus block from `operator.template.js` into the new file.
3. Replace that block with `/* @include resident/command_bus.js */`.
4. Run the JS build/check/smoke commands.
5. Run the AHK toolchain checker because the AHK transport calls this JS entrypoint.
6. Commit as `refactor: extract Advisor resident JS command bus`.
