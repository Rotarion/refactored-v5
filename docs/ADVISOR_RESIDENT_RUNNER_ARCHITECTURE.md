# Advisor Resident Runner Architecture

## Executive Summary

The current Advisor automation uses a reliable but expensive one-op-at-a-time DevTools bridge. For every status read, action, scan, or wait poll, AutoHotkey renders the full Advisor operator, pastes it into DevTools, submits it, waits for `copy(String(...))` output, restores the clipboard, and returns to AHK. This keeps ownership clear, but ASCPRODUCT and Gather Data now perform many small status transitions, so repeated full injection is slow and fragile.

A resident runner is feasible as a bounded page-resident state machine installed at `window.__advisorRunner`. The recommended implementation is a hybrid: add one backward-compatible operator command, `resident_runner_command`, to the existing generated Advisor operator. The full generated operator is used for bootstrap and fallback. After bootstrap, AHK can send tiny snippets that call `window.__advisorRunner.handleTinyCommand(...)`, while preserving the existing `ops_result.js`, `@@OP@@` / `@@ARGS@@`, and `copy(String(...))` transport contracts.

The first implementation phase should be disabled by default and read-only. It may read route/state/status, run bounded status polling, collect a small event ring buffer, and return `BLOCKED`. It must not click, add, remove, confirm, select spouse, resolve duplicates, resolve addresses, create quotes, or use sidebar Add Product. AHK remains the workflow owner and the existing op bridge remains the fallback.

## Phase 1 Implementation Note

Phase 1 has been implemented as a skeleton only:

- JS op: `resident_runner_command`
- Page object: `window.__advisorRunner`
- Commands: `bootstrap`, `status`, `stop`, `reset`, `getEvents`, `runUntilBlocked`
- AHK feature flag: `advisorQuoteResidentRunnerFeatureEnabled := false`
- AHK read-only guard: `advisorQuoteResidentRunnerReadOnlyOnly := true`

The production Advisor workflow is not routed through the runner by default. Existing calls still use `AdvisorQuoteRunOp()` and the normal `ops_result.js` one-op bridge. The resident runner can be exercised manually through the AHK wrappers, but only after the feature flag is explicitly enabled.

## Phase 2 Read-Only Polling Pilot

Phase 2 adds an opt-in resident command named `runReadOnlyPoll`. It is a bounded read-only polling command for selected wait/status reads only. The feature flag remains off by default:

```text
advisorQuoteResidentRunnerFeatureEnabled := false
advisorQuoteResidentRunnerReadOnlyOnly := true
```

When the flag is disabled, production behavior is unchanged and `AdvisorQuoteWaitForCondition()` continues to use the old `AdvisorQuoteRunOp("wait_condition", ...)` polling loop. When the flag is explicitly enabled, AHK may try `AdvisorQuoteRunnerWaitCondition()` for allowlisted conditions. Any missing runner, stale build, wrong context, refused command, error, empty result, or unsupported condition falls back to the old op path without changing the business decision.

Phase 2 now uses a lean bridge for post-bootstrap runner commands:

- Bootstrap still uses `AdvisorQuoteRunOp("resident_runner_command", ...)`.
- Runner `status`, `stop`, `reset`, `getEvents`, `runUntilBlocked`, and `runReadOnlyPoll` can use a tiny `copy(String(...))` snippet that calls `window.__advisorRunner.handleTinyCommand(...)`.
- `advisorQuoteResidentRunnerUseTinyBridge := true` enables this lean path only when `advisorQuoteResidentRunnerFeatureEnabled := true`.
- AHK owns polling cadence. `AdvisorQuoteRunnerWaitCondition()` repeats one-read tiny commands and sleeps in AHK between reads.
- JS-side `runReadOnlyPoll` no longer performs long synchronous browser loops. Tiny-mode reads are capped to one immediate read; direct runner loops are hard-capped to very small work.

`runReadOnlyPoll` accepts:

- `conditionName` or `statusOp`
- `conditionArgs`
- `timeoutMs`
- `pollMs`
- `maxSteps`
- `expectedBuildHash`
- `readOnly=1`
- `allowedConditions`
- `allowedStatusOps`

It returns key=value fields:

- `result=OK|TIMEOUT|MAX_STEPS|STOPPED|STALE_BUILD|WRONG_CONTEXT|REFUSED|ERROR`
- `conditionName=`
- `statusOp=`
- `matched=1|0`
- `steps=`
- `elapsedMs=`
- `url=`
- `routeFamily=`
- `detectedState=`
- `lastValue=`
- `blockedReason=`
- `eventSeq=`
- `readOnly=1`
- `mutatingRequestRefused=0|1`

The command refuses to run unless `readOnly=1`, refuses unknown conditions/status ops, refuses known mutating ops, checks stale build evidence, can reject wrong context, and hard-caps `timeoutMs`, `pollMs`, and `maxSteps`. In tiny-bridge mode the command performs one immediate read and returns control to AHK; AHK repeats tiny reads if a wait needs polling. This avoids pasting the full generated operator and avoids freezing DevTools with browser-side busy waits.

Allowed Phase 2 wait conditions:

- `on_customer_summary_overview`
- `on_product_overview`
- `gather_data`
- `is_rapport`
- `is_select_product`
- `is_asc`
- `consumer_reports_ready`
- `drivers_or_incidents`
- `after_driver_vehicle_continue`
- `quote_landing`
- `incidents_done`
- `continue_enabled`
- `vehicle_select_enabled`
- `vehicle_added_tile`
- `vehicle_confirmed`

Allowed Phase 2 status ops:

- `detect_state`
- `gather_start_quoting_status`
- `gather_confirmed_vehicles_status`
- `asc_participant_detail_status`
- `asc_driver_rows_status`
- `asc_vehicle_rows_status`
- `product_overview_tile_status`
- `customer_summary_overview_status`
- `gather_vehicle_add_status`
- `gather_vehicle_row_status`
- `gather_vehicle_edit_status`

Explicitly disallowed mutating ops inside the runner include Product Overview tile actions, Customer Summary START HERE, duplicate/address verification handlers, Gather Data fill/vehicle actions, Start Quoting actions, Select Product writes, vehicle dropdown selection, participant/vehicle modal fills, incident handling, generic click helpers, ASC spouse/driver/vehicle reconciliation, and stale-row cancel.

Phase 2 AHK wrappers:

- `AdvisorQuoteRunnerWaitCondition(name, args, timeoutMs := "", pollMs := "")`
- `AdvisorQuoteRunnerReadStatus(opName, args)`
- `AdvisorQuoteExecuteTinyRunnerJs(js, timeoutMs := 1500)`
- `AdvisorQuoteRunnerTinyCommand(command, args := Map(), timeoutMs := 1500)`

Phase 2 trace logs:

- `ADVISOR_RUNNER_WAIT_ATTEMPT`
- `ADVISOR_RUNNER_WAIT_USED`
- `ADVISOR_RUNNER_WAIT_FALLBACK`
- `ADVISOR_RUNNER_WAIT_RESULT`
- `ADVISOR_RUNNER_TINY_PAYLOAD`
- `ADVISOR_RUNNER_TINY_RESULT`
- `ADVISOR_RUNNER_TINY_FALLBACK`
- `ADVISOR_RUNNER_REBOOTSTRAP`

## Current Bridge Flow

### Advisor-specific bridge

Current Advisor op execution runs through:

1. `AdvisorQuoteRunOp()` in `workflows/advisor_quote_workflow.ahk`
2. `AdvisorQuoteRunJsOp()`
3. `AdvisorQuoteRenderOpJs()`
4. `AdvisorQuoteEnsureConsoleBridge()`
5. `AdvisorQuoteExecuteBridgeJs()`
6. JS operator returns through `copy(String(...))`
7. AHK reads the clipboard result as a string

Important source anchors:

- `AdvisorQuoteRunOp()` delegates directly to `AdvisorQuoteRunJsOp()` at `workflows/advisor_quote_workflow.ahk:4574`.
- `AdvisorQuoteRunJsOp()` renders the operator once per op call with `AdvisorQuoteRenderOpJs(op, args)`, retries empty results, and logs each op attempt.
- `AdvisorQuoteRenderOpJs()` loads `advisor_quote/ops_result.js` and calls `RenderJsTemplate()` with `OP` and `ARGS`.
- `AdvisorQuoteEnsureConsoleBridge()` focuses Edge, opens/reuses DevTools with `Ctrl+Shift+J`, and tracks `advisorQuoteConsoleBridgeOpen` / `advisorQuoteConsoleBridgeFocus`.
- `AdvisorQuoteExecuteBridgeJs()` saves the clipboard, places the rendered JS on the clipboard, sends `Ctrl+A`, `Ctrl+V`, `Enter`, polls the clipboard for a result that differs from the sent code, then restores the saved clipboard.
- `AdvisorQuoteWaitForCondition()` calls `AdvisorQuoteRunOp("wait_condition", ...)` on each poll, so a full rendered operator is pasted repeatedly during waits.

### Generic bridge

`adapters/devtools_bridge.ahk` provides the broader bridge machinery:

- `RunDevToolsJsAssetWork(assetPath, params, expectResult)` loads an asset, renders placeholders, and executes it.
- `RenderJsTemplate()` replaces `@@OP@@` and `@@ARGS@@`, then refuses unresolved template tokens.
- `RunDevToolsJSGetResult()` and `RunDevToolsJSInternalOnce()` focus DevTools, paste rendered JavaScript, submit with `Enter`, and wait for a `copy(String(...))` result.
- `DevToolsBridgeLogReturn()` records rendered length, result preview, focus/paste/submit state, stale clipboard suspicion, timeout, and stop-related diagnostics.

The bridge now avoids using bare `Esc` in prompt preparation, which matters because `Esc` is the global emergency stop hotkey.

### Injection cost

The full Advisor operator is rendered and pasted for each small op. A typical ASCPRODUCT stretch can call:

- `detect_state`
- `wait_condition`
- `asc_participant_detail_status`
- `asc_driver_rows_status`
- `asc_vehicle_rows_status`
- `scan_current_page`
- repeated status re-reads after each row action

Each old-path call pays the same DevTools focus, clipboard, paste, submit, wait, and restore cost. The lean resident bridge adds an Advisor-specific tiny-snippet command path for runner status/polling after bootstrap, but the old full-op path remains the production default and fallback.

## Existing Operator Runtime Contract

These contract points must not change:

- Runtime file remains `assets/js/advisor_quote/ops_result.js`.
- Source remains `assets/js/advisor_quote/src/operator.template.js`, generated through `assets/js/advisor_quote/build_operator.js`.
- Build output must retain `@@OP@@`, `@@ARGS@@`, and `copy(String(` markers.
- AHK renders `@@OP@@` as a JS string literal and `@@ARGS@@` as a JS object literal.
- Return transport remains `copy(String((() => { ... })()))`.
- Unknown top-level Advisor op returns an empty string.
- Thrown top-level errors return key=value lines with `result=ERROR`, `op=`, `message=`, `stack=`, and `url=`.
- AHK expects string results. Many callers parse key=value lines with `AdvisorQuoteParseKeyValueLines()`.
- Existing op names and return shapes remain supported.
- `ops_result.js` must remain generated byte-for-byte from the template and includes.

The resident runner should extend this contract, not replace it.

## Resident Runner Feasibility

### Survival expectations

`window.__advisorRunner` should survive normal console executions and same-document Advisor SPA route changes because it is attached to the page `window`.

Likely behavior:

| Transition | Expected runner survival | Notes |
|---|---:|---|
| Repeated DevTools console execution on same page | Yes | Same page global object. |
| Advisor hash-route change within the same SPA | Likely yes | Current routes are hash-shaped, such as `#/apps/intel/102/rapport` and `#/apps/ASCPRODUCT/<id>/`. |
| `/apps/intel/102/rapport` to `/apps/ASCPRODUCT/<id>/` without full reload | Likely yes | Needs live validation because the app could recreate root DOM without reloading `window`. |
| In-app ASCPRODUCT substate changes | Likely yes | Same caveat as above. |
| Full page reload or hard navigation | No | A new `window` loses the object. |
| Browser tab switch | No guarantee | AHK must still verify the target tab/page before command use. |
| DevTools console context changed to iframe/extension | Unknown/risky | Command should report page URL/context and AHK should fall back if context evidence is wrong. |

### Missing, stale, and rebootstrap detection

AHK should treat the runner as disposable. Detection should be cheap:

- Missing runner: `typeof window.__advisorRunner !== "object"` or missing command method.
- Stale build: runner `buildHash` or `version` differs from the hash requested by AHK.
- Wrong page/context: runner status URL does not match expected Advisor host/route evidence.
- Busy runner: `running=1` when AHK wants to reset or bootstrap.
- Reload/lost runner: command returns `MISSING` or empty bridge result.

Rebootstrap should be safe:

1. Send `resident_runner_command` with `command=bootstrap`.
2. If missing, install.
3. If stale and not running, replace.
4. If stale and running, request `stop`, then replace only after `running=0`.
5. If bootstrap fails or returns empty, fall back to existing one-op path.

## Recommended Architecture

### Recommendation

Use Option C: a hybrid bootstrap op bundled in the generated Advisor operator.

The implementation uses the top-level op:

```text
resident_runner_command
```

This op would accept a command string and args, then install or talk to `window.__advisorRunner`. The command still returns through the existing `copy(String(...))` wrapper.

Why this is the best first implementation:

- Keeps the current DevTools bridge unchanged.
- Keeps `copy(String(...))` unchanged.
- Reuses existing operator helper functions for route/state/status readers.
- Uses the current `build_operator.js` include system and drift checks.
- Requires only one new AHK wrapper family.
- Allows feature-flagged rollout with fallback to current ops.
- Avoids a second asset/bootstrap path while the system is still under active workflow repair.

### Option comparison

| Option | Shape | Pros | Cons | Recommendation |
|---|---|---|---|---|
| A | Put runner directly inside `operator.template.js` and expose command op | Simple build path, reuses helpers, one runtime file | Grows `ops_result.js`; runner code loaded on every op even if disabled | Acceptable |
| B | Separate resident runner JS asset | Keeps operator smaller; clearer file boundary | New bridge/bootstrap path, harder helper reuse, more AHK bridge changes | Not first |
| C | Hybrid command op installs runner bundled in `ops_result.js` | Keeps current bridge and build, reuses helpers, runner persists after bootstrap, easiest fallback | Some size impact in generated operator | Recommended |

## Command Contract

All commands should return key=value lines unless `getEvents` needs compact JSON payload as a single field.

### `bootstrap`

Purpose: Install or refresh `window.__advisorRunner`.

Args:

- `version`
- `buildHash`
- `maxEventCount`, default 200
- `replaceStale`, default false

Output:

- `result=OK|ALREADY_BOOTSTRAPPED|STALE_REPLACED|BUSY|ERROR`
- `runnerId=`
- `version=`
- `buildHash=`
- `url=`
- `state=`
- `eventSeq=`
- `message=`

Mutation level: runner object only; no page UI mutation.

Failure modes: stale active runner, unsupported page context, install error, bridge empty result.

### `status`

Purpose: Read runner health and current page evidence.

Args:

- `expectedBuildHash`
- optional `expectedHost`

Output:

- `result=OK|MISSING|STALE_BUILD|WRONG_CONTEXT|ERROR`
- `running=0|1`
- `stopRequested=0|1`
- `version=`
- `buildHash=`
- `url=`
- `routeFamily=`
- `detectedState=`
- `lastBlockedReason=`
- `eventSeq=`
- `eventCount=`

Mutation level: read-only.

Failure modes: runner missing, stale hash, wrong page context.

### `stop`

Purpose: Request that a running loop exit at its next stop check.

Args:

- `reason`

Output:

- `result=OK|MISSING|ERROR`
- `stopRequested=1`
- `running=`
- `reason=`

Mutation level: runner state only; no page UI mutation.

Failure modes: missing runner, command error.

### `reset`

Purpose: Clear runner state and optionally clear event history.

Args:

- `clearEvents=1|0`
- `reason`

Output:

- `result=OK|BUSY|MISSING|ERROR`
- `eventCount=`
- `stopRequested=0`
- `running=0`

Mutation level: runner state only.

Failure modes: busy runner, missing runner.

### `getEvents`

Purpose: Return bounded runner event history.

Args:

- `sinceSeq`
- `limit`, capped

Output:

- `result=OK|MISSING|ERROR`
- `fromSeq=`
- `toSeq=`
- `eventCount=`
- `eventsJson=` compact JSON array or `events=` compact pipe-delimited summary

Mutation level: read-only.

Failure modes: missing runner, output too large. The runner must cap output to protect the clipboard bridge.

### `runUntilBlocked`

Purpose: Run a bounded read-only status loop inside the page until a known stop or blocked state is reached. In lean tiny-bridge use, this is intentionally capped to tiny work and AHK owns repeated polling.

Args:

- `maxSteps`, default 1, tiny hard cap 3
- `maxMs`, default 250, tiny hard cap 250
- `readOnly=1`, required in phase 1
- `allowedRouteFamilies`
- `allowedStates`
- `stopOnModal=1`
- `expectedBuildHash`

Output:

- `result=BLOCKED|DONE|STOPPED|TIMEOUT|MAX_STEPS|STALE_BUILD|ERROR`
- `blockedReason=`
- `steps=`
- `elapsedMs=`
- `url=`
- `routeFamily=`
- `detectedState=`
- `lastStatusOp=`
- `manualRequired=0|1`
- `eventSeq=`

Mutation level: read-only in phase 1.

Failure modes: max steps, max time, stop requested, unknown route, unknown substate, unexpected modal, stale build, output too large.

## Safety And Stop Model

The resident runner is not allowed to be autonomous in the first phase. It is a bounded in-page loop that returns control to AHK quickly.

Hard stop conditions:

- `maxSteps` reached.
- `maxMs` reached.
- `stopRequested=1`.
- AHK global stop is observed before or after a command.
- URL or route family changes outside allowed routes.
- Unknown route or unknown substate.
- Ambiguous target evidence.
- Modal appears unexpectedly.
- Required validation fails.
- Build hash mismatch.
- Runner missing or stale.
- Clipboard output would exceed a safe cap.
- Manual-required state is detected.
- Any destructive or mutating action is requested while runner is in read-only mode.

First version may:

- Read URL and route family.
- Run `detect_state`-equivalent logic.
- Run read-only status operations.
- Run bounded polling loops.
- Append sanitized event entries.
- Return `BLOCKED` with evidence.

First version must not:

- Resolve duplicate prospects.
- Resolve Address Verification.
- Add, confirm, edit, remove, or select vehicles.
- Add or remove ASC drivers.
- Select spouse or marital controls.
- Click Create Quotes.
- Click Start Quoting Add product.
- Click sidebar Add Product.
- Select product tiles.
- Answer yes/no radios.
- Dispatch broad DOM events.
- Override AHK emergency stop behavior.

## AHK Integration Plan

Phase 1 adds these wrappers behind a disabled-by-default feature flag:

- `AdvisorQuoteEnsureResidentRunner()`
- `AdvisorQuoteRunnerStatus()`
- `AdvisorQuoteRunnerStop()`
- `AdvisorQuoteRunnerReset()`
- `AdvisorQuoteRunnerGetEvents()`
- `AdvisorQuoteRunnerRunUntilBlocked(args)`

Feature flag:

- Default false.
- Prefer an Advisor-domain config or DB flag such as `residentRunnerEnabled`.
- A second guard such as `residentRunnerReadOnlyOnly=1` should remain true for the pilot.

Fallback:

- If flag is false, use current `AdvisorQuoteRunOp()` path.
- If runner is missing, stale, wrong-context, timed out, or returns empty, log and use current op path.
- If runner returns `BLOCKED`, AHK decides the next workflow step.
- If a mutating action is needed, AHK uses the existing op path.

Logging:

- `ADVISOR_RUNNER_BOOTSTRAP`
- `ADVISOR_RUNNER_STATUS`
- `ADVISOR_RUNNER_RUN_UNTIL_BLOCKED`
- `ADVISOR_RUNNER_BLOCKED`
- `ADVISOR_RUNNER_EVENTS`
- `ADVISOR_RUNNER_FALLBACK`
- `ADVISOR_RUNNER_STOP`

Emergency stop:

- AHK remains the owner of `StopRequested()`.
- JS runner should not install keyboard listeners.
- JS runner should not synthesize `Esc`.
- On AHK stop, the wrapper may send `stop` if bridge access is still safe, but AHK must not wait indefinitely for acknowledgement.

## Build Integration Plan

The preferred implementation adds code to the Advisor operator source tree and rebuilds through the existing tool:

```text
assets/js/advisor_quote/src/operator.template.js
assets/js/advisor_quote/src/core/... if a small include boundary is useful
assets/js/advisor_quote/build_operator.js
assets/js/advisor_quote/ops_result.js
```

No build script behavior needs to change initially. `build_operator.js` already inlines source includes and verifies the required runtime markers. The new command should be covered by the existing smoke harness that renders `ops_result.js` with `@@OP@@` and `@@ARGS@@` replacements and captures the fake `copy()` result.

Size impact should be watched, but the first runner can be small:

- command dispatch
- event ring buffer
- status/read helpers that delegate to already-present functions
- bounded loop machinery

## Phase 2 Candidate Ops

Good candidates for read-only resident polling:

- `detect_state`
- `scan_current_page`
- `gather_start_quoting_status`
- `gather_confirmed_vehicles_status`
- `asc_participant_detail_status`
- `asc_driver_rows_status`
- `asc_vehicle_rows_status`
- `wait_condition` read branches

These are attractive because they are status-heavy and currently cause many repeated DevTools injections.

Ops that must stay AHK-mediated until later approval:

- `handle_duplicate_prospect`
- `handle_address_verification`
- `confirm_potential_vehicle`
- `prepare_vehicle_row`
- `select_vehicle_dropdown_option`
- `asc_reconcile_driver_rows`
- `asc_reconcile_vehicle_rows`
- `click_create_quotes_order_reports`
- `click_start_quoting_add_product`
- Product Tile click/ensure ops
- Driver and vehicle modal fill ops

## Testing Plan

Before implementation, add offline smoke tests for:

- `resident_runner_command command=bootstrap` creates `window.__advisorRunner`.
- `status` returns current URL, route family, state, build hash, and running flags.
- `status` returns `MISSING` before bootstrap.
- `status` returns `STALE_BUILD` when expected hash differs.
- `stop` sets `stopRequested=1`.
- `reset` clears stop state and optionally clears event log.
- `getEvents` returns a bounded ring buffer.
- `runUntilBlocked` stops at `maxSteps`.
- `runUntilBlocked` stops at `maxMs`.
- `runUntilBlocked` returns `BLOCKED` on unknown route/substate.
- `runUntilBlocked` refuses mutating commands in read-only mode.
- Existing unknown-op behavior still returns empty string.
- Existing top-level error behavior still returns `result=ERROR`.
- Existing status ops still work through the old op path.
- Simulated hash-route changes preserve the runner when the same fake `window` is reused.
- Simulated full reload loses the runner and requires rebootstrap.
- Read-only pilot performs no clicks; fixture button click counters remain zero.

Live validation later should be limited:

1. Bootstrap on a stable Advisor page.
2. Read `status`.
3. Read events.
4. Run a very small read-only `runUntilBlocked`.
5. Confirm no DOM mutations occurred.
6. Confirm fallback still works after reset and after page reload.

## Phased Migration Plan

### Phase 1: Skeleton, disabled by default

- Add `resident_runner_command`.
- Install `window.__advisorRunner`.
- Implement `bootstrap`, `status`, `stop`, `reset`, `getEvents`, and read-only `runUntilBlocked`.
- Add AHK wrappers behind `residentRunnerEnabled=false`.
- Do not route production workflow through it by default.

Risk: low if disabled and old path remains untouched.

### Phase 2: Move repeated status polling

- Use runner only for read-only wait/status loops where AHK currently calls `wait_condition` repeatedly.
- Return `BLOCKED` for any action need.
- Keep all mutations on old op path.

Risk: medium because route classification bugs could change wait behavior; mitigate with fallback and side-by-side logs.

### Phase 3: Bounded status-to-status transitions

- Allow the runner to chain reads across known page families.
- Still no clicks/removes/adds.
- Use it to summarize ASCPRODUCT readiness and unresolved row counts before AHK action decisions.

Risk: medium.

### Phase 4: Consider selected scoped mutations

- Only after live validation and explicit approval.
- Candidate mutations must already have strong scoped ops, tests, and verification.
- Destructive actions remain especially conservative.

Risk: high; defer.

## Explicit Non-Goals

- Do not replace AHK with all-JS automation.
- Do not create unbounded recursion or an indefinite in-page loop.
- Do not remove the existing op-based bridge.
- Do not change existing op return contracts.
- Do not change the `copy(String(...))` result channel.
- Do not move destructive actions into the first resident runner phase.
- Do not click sidebar Add Product.
- Do not bypass duplicate prospect, address verification, vehicle, driver, spouse, or quote guards.
- Do not make ASCPRODUCT a generic success state.
- Do not hide failures inside the runner; return `BLOCKED` with evidence.

## Files Reviewed

- `adapters/devtools_bridge.ahk`
- `workflows/advisor_quote_workflow.ahk`
- `assets/js/advisor_quote/src/operator.template.js`
- `assets/js/advisor_quote/ops_result.js`
- `assets/js/advisor_quote/build_operator.js`
- `docs/ADVISOR_JS_OPERATOR_CONTRACT.md`
- `docs/DEVTOOLS_BRIDGE_REGRESSION_CALLFLOW_REPORT.md`
- `docs/AHK_TOOLCHAIN_CHECKS.md`
- `docs/ADVISOR_SCAN_LOGGING_CONTRACT.md`
- `tests/advisor_quote_ops_smoke.js`
- `tests/fixtures/advisor_quote_operator/sanitized_dom_scenarios.json`
