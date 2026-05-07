# Connectors And Bridge Map

Captured: 2026-05-06

In this project, "connectors" means local adapters, bridges, and integration surfaces. It does not mean external data connectors.

## Browser Focus Adapter

File: `adapters/browser_focus_adapter.ahk`

Responsibilities:

- `FocusEdge()` activates `msedge.exe`.
- `FocusChrome()` activates `chrome.exe`.
- `FocusWorkBrowser()` tries Chrome first, then Edge.

Current Advisor quote workflow primarily uses Edge for Advisor Pro. Quo and CRM paths may use the generic work browser focus path.

Failure modes:

- target browser process is not open
- browser activates but wrong tab/page is active
- DevTools opens against the wrong browser context

Rule: do not assume the correct tab merely because Edge or Chrome is focused.

## Clipboard Adapter

File: `adapters/clipboard_adapter.ahk`

Responsibilities:

- stop-aware sleep and clipboard wait helpers
- set clipboard for paste actions
- paste text into fields
- send tabs/type text for non-Advisor workflows
- persist run state when automation begins

Advisor-specific bridge code also captures/restores `ClipboardAll()` around DevTools JS injection.

Failure modes:

- clipboard set timeout
- stop requested before paste
- pasted content into wrong focused field
- destructive clipboard overwrite when preservation is not possible

Rule: preserve clipboard where practical and document destructive clipboard actions when not practical.

## DevTools Bridge

Shared adapter file: `adapters/devtools_bridge.ahk`

Advisor local bridge functions are in `workflows/advisor_quote_workflow.ahk`:

- `AdvisorQuoteEnsureConsoleBridge()`
- `AdvisorQuoteExecuteBridgeJs()`
- `AdvisorQuoteRunJsOp()`
- `AdvisorQuoteRenderOpJs()`

Shared adapter responsibilities:

- focus browser by mode
- open DevTools with `Ctrl+Shift+J`
- prepare console without sending Esc
- paste rendered JS
- submit with Enter only after focus/paste checks
- receive result through clipboard
- restore clipboard after execution
- log structured bridge return diagnostics

Advisor local bridge responsibilities:

- render `assets/js/advisor_quote/ops_result.js` with `@@OP@@` and `@@ARGS@@`
- keep/reuse a console bridge state for Edge
- invalidate bridge on empty results
- log action/wait JS calls into `logs/advisor_quote_trace.log`

Logs:

- Shared bridge returns: `logs/devtools_bridge_returns.log`
- Advisor workflow trace: `logs/advisor_quote_trace.log`
- JS asset failures: `logs/js_asset_errors.log`

## Advisor JS Operator Bridge Contract

Files:

- Source: `assets/js/advisor_quote/src/operator.template.js`
- Generated runtime: `assets/js/advisor_quote/ops_result.js`
- Builder: `assets/js/advisor_quote/build_operator.js`

Contract:

- AHK passes an operation name as `@@OP@@`.
- AHK passes operation arguments as `@@ARGS@@`.
- JS returns either a raw scalar or key/value lines.
- Browser return channel is `copy(String(...))`.
- AHK parses key/value blocks with `AdvisorQuoteParseKeyValueLines()`.
- JS remains a DOM reader/executor. It does not load the vehicle DB.
- AHK owns vehicle DB lookup and passes bounded labels, aliases, normalized keys, strict-match flags, and defaults.

Do not edit `ops_result.js` manually. Edit the source template or snippets, then regenerate through the build script.

## CRM And Blitz Bridge Path

Files:

- `adapters/crm_adapter.ahk`
- `assets/js/devtools_bridge/ops_result.js`
- `adapters/devtools_bridge.ahk`

Implemented browser ops include:

- `bridge_probe`
- `blitz_page_status`
- `focus_action_dropdown`
- `save_history_note`
- `add_new_appointment`
- `focus_date_time_field`
- `save_appointment`
- `get_blitz_current_lead_title`
- `click_blitz_next_lead`
- `open_blitz_lead_log_by_name`

CRM/Blitz logs:

- `logs/crm_blitz_workflow.log`
- `logs/devtools_bridge_returns.log`

Current bridge log note: latest available `devtools_bridge_returns.log` tail is mostly CRM/Blitz/Quo activity and contains live lead data. Summarize it only; do not paste or stage raw entries.

## Quo Adapter Path

File: `adapters/quo_adapter.ahk`

Bridge assets:

- `assets/js/quo/ops_result.js`
- `assets/js/participant_input_focus.js`

Responsibilities:

- focus Quo slate composer
- verify participant input readiness
- start new conversations
- select lead holder
- schedule messages

Failure modes:

- wrong browser tab
- participant input not focused
- clipboard paste failure
- user interaction required for manual focus

## How AHK Calls JS

Advisor path:

1. AHK calls `AdvisorQuoteRunOp(op, args, retries, retryDelayMs)`.
2. `AdvisorQuoteRenderOpJs()` loads `assets/js/advisor_quote/ops_result.js`.
3. `RenderJsTemplate()` substitutes `@@OP@@` and `@@ARGS@@`.
4. `AdvisorQuoteEnsureConsoleBridge()` focuses Edge and opens/reuses DevTools.
5. `AdvisorQuoteExecuteBridgeJs()` saves clipboard, pastes JS, submits, waits for clipboard result, and restores clipboard.
6. AHK either uses the raw result or parses key/value lines.

Shared adapter path:

1. AHK calls `RunDevToolsJsAssetWork()` or `RunDevToolsJsAssetEdge()`.
2. The adapter loads an asset under `assets/js`.
3. It substitutes tokens through `RenderJsTemplate()`.
4. It uses `RunDevToolsJSInternal()` to focus, paste, submit, wait, restore, and log.

## How JS Returns To AHK

The JS operator returns via:

```javascript
copy(String(result))
```

Most higher-risk Advisor ops return key/value lines:

```text
result=OK
field=value
failedFields=
```

AHK treats empty results as bridge failures or retry signals. It treats parsed diagnostics as action evidence, not as proof of success unless required fields verify.

## Where Logs Are Written

- `logs/run_state.json`: current run state and stop flag.
- `logs/advisor_quote_trace.log`: Advisor workflow state/action/status trace.
- `logs/advisor_scan_latest.json`: latest page scan pointer. Contains live page text; summarize only.
- `logs/advisor_scans/advisor_scan_run_*.json`: scan bundles. Contains live page text; summarize only.
- `logs/devtools_bridge_returns.log`: shared bridge diagnostics. Can contain live CRM/Blitz data; summarize only.
- `logs/js_asset_errors.log`: JS asset loading/rendering failures.
- `logs/crm_blitz_workflow.log`: CRM/Blitz workflow logs.
- `logs/toolchain_checks/*.json`: AHK toolchain checker artifacts.

## What Can Fail In The Bridge

- Browser not found or wrong browser mode.
- Wrong tab focused.
- DevTools not open or not focused.
- Console paste protection.
- Clipboard set timeout.
- Clipboard stale after submit.
- Empty `copy()` result.
- JS syntax/runtime error.
- Large generated payload causing paste or console pressure.
- Stop requested before submit or while waiting.
- Route changed while waiting.
- Result payload looks like an error even when it is a key/value status block.

## What Should Never Be Done

- Never run raw AHK diagnostics.
- Never run `AutoHotkeyUX.exe /?`.
- Never run `Ahk2Exe.exe /?`.
- Never manually edit `assets/js/advisor_quote/ops_result.js`.
- Never use broad DOM clicks when a scoped selector/status gate exists.
- Never navigate directly unless the user explicitly allowed direct navigation.
- Never stage logs, scans, CRM data, customer data, raw lead rows, live names, addresses, phone numbers, emails, VINs, or raw scan payloads.
- Never send Enter unless the active context and target field are verified.

