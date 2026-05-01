# DevTools Bridge Regression and Call-Flow Report

## 1. Executive summary

The strongest current evidence points to a DevTools bridge regression, not Blitz selector drift.

The highest-confidence failure layer is the generic Console preparation/submission path, with a likely interaction between the bridge's internal `Send "{Esc}"` and the repository's global `Esc::` stop hotkey. Current runtime logs repeatedly show:

- `op=bridge_probe`
- `event=DEVTOOLS_RETURN_STOPPED_BEFORE_SUBMIT`
- `consoleFocusAttempted=1`
- `focusSucceeded=0`
- `consolePasteAttempted=0`
- `consoleSubmitAttempted=0`
- `stopRequestedBeforeFocus=1`
- `error=console-prompt-focus-interrupted`

At the same timestamps, `logs/advisor_quote_trace.log` records `STOP | UNKNOWN | manual-esc`. The only global `Esc::` hotkey is in `hotkeys/debug_hotkeys.ahk:1-12`, and it calls `AdvisorQuoteLogStop("manual-esc")`, which persists `lastAction=advisor-quote-stop` at `workflows/advisor_quote_workflow.ahk:3233-3239`.

That strongly suggests the bridge's Console cleanup Escape at `adapters/devtools_bridge.ahk:243-249` is tripping the same stop path that is intended for a human emergency stop, or that an actual stop request is being raised during that exact focus step. Either way, the bridge is aborting before paste/submit.

Older logs also show stale rendered-JS clipboard:

- `DEVTOOLS_RETURN_TIMEOUT` with `clipboardAfterLength == renderedLength`
- `DEVTOOLS_RETURN_STALE` with `consoleFocusAttempted=1`, `consoleSubmitAttempted=0`

Those older entries indicate a previous path where rendered JavaScript was put on the clipboard but never successfully executed through `copy(String(...))`. The current source has moved toward clearer stop/focus diagnostics, but the active blocker remains before Blitz ops run. Blitz selectors and iframe page modeling are future risks, not the first blocker.

Git history was not available in this workspace: `git` is not installed in the shell and there is no `.git` directory under the repo root. This report therefore uses current source, docs, and logs.

## 2. Timeline of relevant recent changes

### Git/history availability

Git history could not be inspected:

- `git status`, `git diff`, and `git log` all failed because `git` is not recognized.
- `.git` does not exist under `C:\Users\sflzsl7k\Documents\Codex\Final_V5.6_js_operator_refactor`.

### Source-state change risk from current files and docs

| Area | Current source/docs evidence | Regression risk |
| --- | --- | --- |
| Bridge return logging | `DevToolsBridgeLogReturn()` in `adapters/devtools_bridge.ahk:263-346`; documented in `docs/DEVTOOLS_BRIDGE_RETURN_LOGGING.md` | Low/medium. Logging runs in `finally` and should be passive, but it now classifies early aborts and stale results. |
| DevTools bridge focus path | `RunDevToolsJSInternalOnce()` sends `^+j`, waits, then calls `DevToolsBridgePrepareConsolePrompt()` at `adapters/devtools_bridge.ahk:84-99` | High. Current prompt prep sends `Esc`, and logs show stop being set during this region. |
| DevTools open wait | `SafeSleep(2000)` at `adapters/devtools_bridge.ahk:85`, recently increased from 500 ms | Low. This did not fix the issue; latest failure elapsed around 2328 ms, consistent with reaching the longer wait and then stopping. |
| Clipboard placement | Rendered JS is now placed on clipboard after focus succeeds at `adapters/devtools_bridge.ahk:122-144` | Medium. Current latest failures abort before this, but older logs had rendered JS left on clipboard. |
| Stop diagnostics | Stop checkpoints are logged at `adapters/devtools_bridge.ahk:54-58`, `63-68`, `78-99`, `102-166` | Medium/high. Diagnostics are good, but the stop source appears contaminated by the bridge's internal Escape or stale active state. |
| Blitz status op | `blitz_page_status` in `assets/js/devtools_bridge/ops_result.js:189-311`; documented in `docs/BLITZ_PAGE_STATUS_CONTRACT.md` | Low for bridge_probe. It increases asset size and syntax surface, but `bridge_probe` fails before selector logic runs. |
| Frame-aware CRM ops | CRM ops search accessible docs in `assets/js/devtools_bridge/ops_result.js:32-71`, `313-380` | Low for bridge_probe. Important after bridge works; not responsible for `bridge_probe` failure. |
| Ctrl+Alt+K guarded engine | `RunCrmAttemptedContactWorkflow()` calls probe then `CrmRunAttemptedContactAppointmentGuarded()` at `workflows/crm_activity.ahk:28-47` | Low for bridge itself. It correctly stops before mutation if probe fails. |
| Ctrl+Alt+H batch orchestrator | `RunCrmAttemptedContactForLatestBatchOkLeads()` at `adapters/crm_adapter.ahk:456-602` | Low/medium. It calls `BeginAutomationRun()` before bridge probe, but logs still show stop before focus. |

Recent changes likely caused or surfaced the regression because the current failures happen in bridge scaffolding added around focus/stop/return logging, before Blitz-specific logic.

## 3. Ctrl+Alt+H call graph

Hotkey:

```text
hotkeys/crm_hotkeys.ahk:7
^!h::RunCrmAttemptedContactForLatestBatchOkLeads()
```

Current call graph:

```text
Ctrl+Alt+H
  -> RunCrmAttemptedContactForLatestBatchOkLeads() adapters/crm_adapter.ahk:456
    -> BeginAutomationRun() adapters/clipboard_adapter.ahk:1
    -> LoadLatestBatchOkLeadNames() adapters/crm_adapter.ahk:460
    -> CrmBlitzLog("BATCH_OK_LIST_LOADED") adapters/crm_adapter.ahk:461
    -> FocusWorkBrowser() adapters/browser_focus_adapter.ahk:19
    -> JS_DevToolsBridgeProbe() adapters/devtools_bridge.ahk:538
      -> RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", OP=bridge_probe) adapters/devtools_bridge.ahk:479
      -> RunDevToolsJSGetResult() adapters/devtools_bridge.ahk:6
      -> RunDevToolsJSInternal() adapters/devtools_bridge.ahk:21
      -> RunDevToolsJSInternalOnce() adapters/devtools_bridge.ahk:39
    -> CrmGetBlitzPageStatus("batch-start") adapters/crm_adapter.ahk:479
    -> GetCurrentBlitzLeadName() adapters/crm_adapter.ahk:480
    -> CrmEnsureBlitzLeadOpen() adapters/crm_adapter.ahk:441
      -> BlitzOpenLeadLogByName() adapters/crm_adapter.ahk:434
      -> JS_OpenBlitzLeadLogByName() adapters/devtools_bridge.ahk:559
    -> CrmWaitForBlitzAttemptedContactReady() adapters/crm_adapter.ahk:275
    -> CrmRunAttemptedContactAppointmentGuarded() adapters/crm_adapter.ahk:299
      -> CrmGetBlitzPageStatus() adapters/crm_adapter.ahk:250
      -> CrmRunAttemptedContactAppointment() adapters/crm_adapter.ahk:148
        -> JS_FocusActionDropdown() adapters/devtools_bridge.ahk:513
        -> SetClip(noteText) adapters/clipboard_adapter.ahk:40
        -> JS_SaveHistoryNote() adapters/devtools_bridge.ahk:517
        -> JS_AddNewAppointment() adapters/devtools_bridge.ahk:521
        -> JS_FocusDateTimeField() adapters/devtools_bridge.ahk:526
        -> CrmApplyAppointmentPreset() adapters/crm_adapter.ahk:121
        -> JS_SaveAppointment() adapters/devtools_bridge.ahk:530
    -> BlitzGoToNextLead() adapters/crm_adapter.ahk:427
      -> JS_ClickBlitzNextLead() adapters/devtools_bridge.ahk:546
      -> WaitForBlitzLeadChange() adapters/crm_adapter.ahk:394
```

Step details:

| Step | Function/file | Return/failure behavior | Logs |
| --- | --- | --- | --- |
| Start run | `BeginAutomationRun()`, `adapters/clipboard_adapter.ahk:1-5` | Sets `StopFlag := false`, persists `automation-begin` | `logs/run_state.json` |
| Load OK leads | `LoadLatestBatchOkLeadNames()`, called at `adapters/crm_adapter.ahk:460` | Empty list shows MsgBox and stops | `BATCH_OK_LIST_LOADED` |
| Focus browser | `FocusWorkBrowser()`, `adapters/browser_focus_adapter.ahk:19-24` | MsgBox if no Chrome/Edge | none besides workflow continuation |
| Bridge probe | `JS_DevToolsBridgeProbe()`, `adapters/devtools_bridge.ahk:538-540` | Must return `OK_BRIDGE`; otherwise MsgBox and stop | `BLITZ_BATCH_REPLAY_FAILED`, `devtools_bridge_returns.log` |
| Page status | `CrmGetBlitzPageStatus()`, `adapters/crm_adapter.ahk:250-259` | Parses key/value lines, sets `EMPTY` or `UNKNOWN` if malformed | `BLITZ_STATUS_PRECHECK` |
| Open/match lead | `CrmEnsureBlitzLeadOpen()`, `adapters/crm_adapter.ahk:441-454` | Uses current title or opens target from visible list | `BLITZ_OPEN_LEAD_ATTEMPT`, `BLITZ_OPEN_LEAD_RESULT` |
| Single lead mutation | `CrmRunAttemptedContactAppointmentGuarded()`, `adapters/crm_adapter.ahk:299-310` | Requires ready lead-log status, then runs existing activity | `CRM_ATTEMPTED_CONTACT_START/DONE/FAILED` |
| Next traversal | `BlitzGoToNextLead()`, `adapters/crm_adapter.ahk:427-432` | Clicks Next and waits for title change | `BLITZ_NEXT_ATTEMPT`, `BLITZ_NEXT_DONE` |

Current live failure does not reach page status or mutation. It stops at bridge probe.

## 4. Ctrl+Alt+K call graph

Hotkey:

```text
hotkeys/crm_hotkeys.ahk:5
^!k::RunCrmAttemptedContactWorkflow()
```

Current call graph:

```text
Ctrl+Alt+K
  -> RunCrmAttemptedContactWorkflow() workflows/crm_activity.ahk:28
    -> BeginAutomationRun() adapters/clipboard_adapter.ahk:1
    -> TemplateRead("CrmNotes", "AttemptedContact", "txt")
    -> BuildLastConfiguredFollowupDateText() workflows/crm_activity.ahk:1
    -> FocusWorkBrowser() adapters/browser_focus_adapter.ahk:19
    -> JS_DevToolsBridgeProbe() adapters/devtools_bridge.ahk:538
    -> CrmRunAttemptedContactAppointmentGuarded(noteText, dtText, "ctrl-alt-k-current-lead") adapters/crm_adapter.ahk:299
      -> CrmGetBlitzPageStatus() adapters/crm_adapter.ahk:250
      -> CrmBlitzStatusReadyForAttemptedContact() adapters/crm_adapter.ahk:261
      -> CrmRunAttemptedContactAppointment() adapters/crm_adapter.ahk:148
```

Shared code with Ctrl+Alt+H:

- Both call `BeginAutomationRun()`.
- Both call `FocusWorkBrowser()`.
- Both call `JS_DevToolsBridgeProbe()` before any Blitz mutation.
- Both use `CrmRunAttemptedContactAppointmentGuarded()` for the actual attempted-contact sequence.
- Both depend on the same `RunDevToolsJsAssetWork()` bridge and the same `assets/js/devtools_bridge/ops_result.js` operator.

Divergence:

- Ctrl+Alt+K operates on the current lead only.
- Ctrl+Alt+H loads `logs/latest_batch_ok_leads.txt`, opens/matches each target, and traverses Next/open fallback.
- Ctrl+Alt+H logs batch events and cursor progress; Ctrl+Alt+K only logs current-lead attempted-contact readiness/failure.

## 5. DevTools bridge call graph

```text
RunDevToolsJsAssetWork(assetPath, params, expectResult) adapters/devtools_bridge.ahk:479
  -> LoadJsAsset(assetPath) adapters/devtools_bridge.ahk:399
  -> RenderJsTemplate(jsText, params) adapters/devtools_bridge.ahk:458
  -> DevToolsBridgeContext(assetPath, params) adapters/devtools_bridge.ahk:252
  -> RunDevToolsJSGetResult(rendered, context) adapters/devtools_bridge.ahk:6
    -> RunDevToolsJSInternal(rendered, "work", true, context) adapters/devtools_bridge.ahk:21
      -> RunDevToolsJSInternalOnce(rendered, "work", true, context, attempt) adapters/devtools_bridge.ahk:39
        -> StopRequested() adapters/clipboard_adapter.ahk:7
        -> DevToolsFocusByMode("work") adapters/devtools_bridge.ahk:377
          -> FocusWorkBrowser() adapters/browser_focus_adapter.ahk:19
        -> ClipboardAll()
        -> Send "^+j"
        -> SafeSleep(open wait) adapters/clipboard_adapter.ahk:12
        -> DevToolsBridgePrepareConsolePrompt() adapters/devtools_bridge.ahk:243
          -> Send "{Esc}"
          -> SafeSleep(80)
        -> Send "^a"
        -> A_Clipboard := rendered JS
        -> WaitForClip(1000) adapters/clipboard_adapter.ahk:25
        -> Send "^v"
        -> Send "{Enter}"
        -> poll A_Clipboard for copy(String(...)) result
        -> DevToolsBridgeLogReturn() adapters/devtools_bridge.ahk:263
        -> restore clipboard
```

Function responsibilities:

| Function | Lines | Responsibility | Failure behavior |
| --- | ---: | --- | --- |
| `RunDevToolsJS()` | `adapters/devtools_bridge.ahk:1-4` | Fire-and-forget work-browser JS | Converts internal result to boolean |
| `RunDevToolsJSGetResult()` | `adapters/devtools_bridge.ahk:6-9` | Result-returning work-browser JS | Converts non-string to empty string |
| `RunDevToolsJSInternal()` | `adapters/devtools_bridge.ahk:21-36` | Retry wrapper, 2 attempts for result ops | Logs empty retry/final empty to `js_asset_errors.log` |
| `RunDevToolsJSInternalOnce()` | `adapters/devtools_bridge.ahk:39-241` | Focus, clipboard, paste, submit, wait, close, restore | Returns `""` or `false` on any failure; logs in `finally` |
| `DevToolsBridgePrepareConsolePrompt()` | `adapters/devtools_bridge.ahk:243-250` | Console prompt cleanup | Sends `Esc`; returns false if stop becomes true |
| `DevToolsBridgeContext()` | `adapters/devtools_bridge.ahk:252-260` | Extract asset/op/caller labels | No runtime failure path |
| `DevToolsBridgeLogReturn()` | `adapters/devtools_bridge.ahk:263-346` | Classify and append return diagnostics | Catches FileAppend only by `try` |
| `DevToolsFocusByMode()` | `adapters/devtools_bridge.ahk:377-379` | Select work or Edge browser focus helper | Returns boolean |
| `RenderJsTemplate()` | `adapters/devtools_bridge.ahk:458-477` | Replace `@@OP@@` / `@@ARGS@@` tokens | Logs unresolved token or empty render |
| `RunDevToolsJsAssetWork()` | `adapters/devtools_bridge.ahk:479-490` | Load/render/execute JS asset in work browser | Returns empty/false on asset/render failure |

## 6. Expected bridge state machine

Intended state machine:

1. Begin operation.
2. Confirm no stop request.
3. Activate target browser/DevTools.
4. Focus Console prompt.
5. Backup clipboard.
6. Put rendered JS on clipboard.
7. Paste rendered JS into Console prompt.
8. Submit with Enter.
9. Wait for clipboard to change to the `copy(String(...))` result.
10. Classify result: OK / ERROR / EMPTY / STALE / TIMEOUT / STOPPED.
11. Restore clipboard according to existing behavior.
12. Return result to caller.

Comparison to current source:

- The current source backs up clipboard before opening DevTools, at `adapters/devtools_bridge.ahk:75`, not after Console prompt focus.
- It opens/reuses DevTools with `Send "^+j"` at `adapters/devtools_bridge.ahk:84`.
- It focuses/prepares the prompt by sending `Esc` at `adapters/devtools_bridge.ahk:246`.
- It puts rendered JS on the clipboard only after focus succeeds, at `adapters/devtools_bridge.ahk:122-144`.
- It sends paste at `adapters/devtools_bridge.ahk:152-153`.
- It sends Enter at `adapters/devtools_bridge.ahk:168-170`.
- It waits for the clipboard to differ from `sentCode` and be nonblank at `adapters/devtools_bridge.ahk:177-190`.
- It logs before restoring the clipboard at `adapters/devtools_bridge.ahk:237-239`.

The current state machine is conceptually right, but it is vulnerable at state 4: Console prompt preparation sends an Escape key while a global Escape hotkey is used as the automation stop command.

## 7. Actual bridge state machine from source

### Can clipboard be set to rendered JS but paste not attempted?

Yes, but current source labels the reasons.

After `A_Clipboard := jsCode` and `sentCode := A_Clipboard`, the bridge can return before paste if `StopRequested()` is true at `adapters/devtools_bridge.ahk:146-150`. It should log:

- `stopRequestedBeforeSubmit=1`
- `stoppedBeforeSubmit=1`
- `consolePasteAttempted=0`
- `consoleSubmitAttempted=0`
- `error=stop-requested-before-console-paste`

Older logs show rendered JS stayed on the clipboard with no submit, which is consistent with a prior version or an early-return path before the current clearer stop logging.

### Can paste be attempted but submit not attempted?

Yes.

Paths:

- Paste wait interrupted at `adapters/devtools_bridge.ahk:154-160`.
- Stop detected after paste but before Enter at `adapters/devtools_bridge.ahk:162-166`.

These should log `consolePasteAttempted=1` and `consoleSubmitAttempted=0`.

### Can `consoleFocusAttempted=1` but `consoleSubmitAttempted=0` without explicit stop/error?

In current source, no obvious path should do that without an `error` or stop flag. The main paths after `consoleFocusAttempted := true` at `adapters/devtools_bridge.ahk:92` return with error messages:

- `console-prompt-focus-interrupted` at `adapters/devtools_bridge.ahk:94-99`
- `stop-requested-before-console-select` at `adapters/devtools_bridge.ahk:102-106`
- `console-select-wait-interrupted` at `adapters/devtools_bridge.ahk:109-113`
- `stop-requested-before-js-clipboard` at `adapters/devtools_bridge.ahk:116-133`
- `js-clipboard-set-timeout` at `adapters/devtools_bridge.ahk:136-141`
- `stop-requested-before-console-paste` at `adapters/devtools_bridge.ahk:146-150`
- `console-paste-wait-interrupted` at `adapters/devtools_bridge.ahk:154-160`
- `stop-requested-before-console-enter` at `adapters/devtools_bridge.ahk:162-166`

Older logs at `2026-04-30 01:24:31` and `01:24:48` had `consoleFocusAttempted=1`, `consoleSubmitAttempted=0`, stale clipboard, and an `error=[id]` redacted by the logger. Those are not enough to prove current-source behavior.

### Is stale detection happening before submit?

Current source classifies stale in `DevToolsBridgeLogReturn()` after the attempt, at `adapters/devtools_bridge.ahk:282-298`. It does not proactively detect stale before submit.

### Is `StopRequested()` checked after clipboard set but before submit?

Yes:

- Before paste: `adapters/devtools_bridge.ahk:146-150`
- Before Enter: `adapters/devtools_bridge.ahk:162-166`

### Is clipboard restored before return is read?

No. The result is read/polled before restoration. Logging also happens before restoration at `adapters/devtools_bridge.ahk:237`; restoration happens at `adapters/devtools_bridge.ahk:239`.

### Is Enter sent to the Console prompt?

It is intended to be. The actual focus is inferred, not verified. `Send "{Enter}"` at `adapters/devtools_bridge.ahk:170` goes wherever Windows focus/caret actually is.

### Is the focus method reliable?

Current focus method:

- Browser focus through `FocusWorkBrowser()` / `FocusEdge()`.
- Toggle DevTools with `Ctrl+Shift+J`.
- Send `Esc` to close prompt distractions.
- Select all with `Ctrl+A`.

It does not positively verify:

- DevTools is on the Console panel.
- The Console prompt/editor has caret focus.
- The paste landed in the prompt.

It also uses `Esc`, which conflicts with the global stop hotkey.

### Does `bridge_probe` use the same path as Blitz ops?

Yes. `JS_DevToolsBridgeProbe()` at `adapters/devtools_bridge.ahk:538-540` calls `RunDevToolsJsAssetWork()` with the same asset and bridge path used by `blitz_page_status` and CRM mutation ops.

## 8. Bridge return logging audit

Logging is implemented in `DevToolsBridgeLogReturn()` at `adapters/devtools_bridge.ahk:263-346`.

Logged fields:

- `timestamp`
- `event`
- `mode`
- `assetPath`
- `op`
- `caller`
- `attempt`
- `elapsedMs`
- `renderedLength`
- `resultLength`
- `resultEmpty`
- `resultLooksError`
- `resultLooksKeyValue`
- `resultPreview`
- `clipboardBeforeLength`
- `clipboardBeforeHash`
- `clipboardAfterLength`
- `clipboardAfterHash`
- `staleClipboardSuspected`
- `consoleFocusAttempted`
- `focusSucceeded`
- `consolePasteAttempted`
- `consolePasteSucceeded`
- `consolePasteFailed`
- `consoleSubmitAttempted`
- `consoleSubmissionStale`
- `probeFailedStale`
- `panelFocusMethod`
- `submitMethod`
- `possiblePasteProtection`
- `stopRequestedBeforeFocus`
- `stopRequestedBeforePaste`
- `stopRequestedBeforeSubmit`
- `stoppedBeforeSubmit`
- `stoppedWhileWaiting`
- `timeout`
- `error`

Answers:

- Logging itself should not alter bridge behavior; it runs in `finally` and only appends to a log.
- No current-source early return appears to be introduced by logging itself.
- It can report `consoleSubmitAttempted=0` accurately if the function returns before `adapters/devtools_bridge.ahk:168`.
- It should not classify a valid delayed return as stale before the polling loop completes. Stale classification happens after `clipboardAfter` is captured.
- Hashes and lengths are computed before clipboard restore, because logging occurs at `adapters/devtools_bridge.ahk:237` and restore at `239`.
- Logs are capped/redacted by `DevToolsBridgeRedact()` at `adapters/devtools_bridge.ahk:349-360`.
- The fields are sufficient to identify the latest failure as stop-before-submit, but not sufficient to prove whether `Send "{Esc}"` is self-triggering the global stop hotkey versus an actual user stop.

Potential logging weakness:

- `probeFailedStale` is only true when `consoleSubmitAttempted=1` and clipboard still equals sent code. Older rendered-JS stale events with `consoleSubmitAttempted=0` remain `DEVTOOLS_RETURN_STALE`, not `DEVTOOLS_BRIDGE_PROBE_FAILED_STALE`. That is diagnostically acceptable but less blunt.

## 9. Stop flag and run-state audit

Relevant source:

- `StopFlag` global default is `false` in `main.ahk:27`.
- `PersistRunState()` writes current `StopFlag` to `logs/run_state.json` at `main.ahk:195-213`.
- `BeginAutomationRun()` clears in-memory `StopFlag` and persists `automation-begin` at `adapters/clipboard_adapter.ahk:1-5`.
- `StopRequested()` returns the in-memory global at `adapters/clipboard_adapter.ahk:7-10`.
- Global `Esc::` stop hotkey is `hotkeys/debug_hotkeys.ahk:1-12`.
- `AdvisorQuoteLogStop()` persists `advisor-quote-stop` at `workflows/advisor_quote_workflow.ahk:3233-3239`.

Answers:

- A stale `stopFlag=true` in `logs/run_state.json` should not by itself block a later run, because current source does not read it back into `StopFlag` during CRM startup. The active in-memory `StopFlag` matters.
- Ctrl+Alt+H clears stop state at start in `RunCrmAttemptedContactForLatestBatchOkLeads()`, `adapters/crm_adapter.ahk:456-459`.
- Ctrl+Alt+K clears stop state at start in `RunCrmAttemptedContactWorkflow()`, `workflows/crm_activity.ahk:28-30`.
- `bridge_probe` checks `StopRequested()` before focus, before Console open, before paste, before submit, and during result wait in `adapters/devtools_bridge.ahk:63-199`.
- Stop can be triggered between clipboard set and submit; the source checks for it at `adapters/devtools_bridge.ahk:146-150` and `162-166`.
- The bridge logs stopped-before-submit distinctly as `DEVTOOLS_RETURN_STOPPED_BEFORE_SUBMIT`.
- `lastAction=advisor-quote-stop` is relevant because it is produced by the global `Esc::` stop hotkey's call to `AdvisorQuoteLogStop("manual-esc")`. The repeated exact timestamp pairing between bridge failure and Advisor STOP strongly links the CRM bridge failure to the stop hotkey path.

Most important observation:

`DevToolsBridgePrepareConsolePrompt()` sends `{Esc}` at `adapters/devtools_bridge.ahk:246`. Every recent bridge-probe failure timestamp also has `STOP | UNKNOWN | manual-esc` in `logs/advisor_quote_trace.log`. This is the most direct evidence of stop contamination.

## 10. DevTools focus and submission audit

Current source behavior:

| Operation | Source | Detail |
| --- | --- | --- |
| Browser focus | `DevToolsFocusByMode()`, `adapters/devtools_bridge.ahk:377-379` | Work mode calls `FocusWorkBrowser()` |
| Work browser focus | `FocusWorkBrowser()`, `adapters/browser_focus_adapter.ahk:19-24` | Prefers Chrome, then Edge |
| DevTools open/reuse | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:84-85` | Sends `Ctrl+Shift+J`, waits 2000 ms |
| Console prompt prep | `DevToolsBridgePrepareConsolePrompt()`, `adapters/devtools_bridge.ahk:243-249` | Sends `Esc`, waits 80 ms |
| Clear prompt | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:108-113` | Sends `Ctrl+A`, waits 80 ms |
| Paste | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:152-161` | Sends `Ctrl+V`, waits 120 ms |
| Submit | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:168-171` | Sends Enter, waits 300 ms for result ops |
| Return wait | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:177-190` | 25 polls at 100 ms each |

Risks:

- It relies on keyboard shortcuts and does not click the Console prompt.
- It does not verify the Console panel or prompt caret.
- Focus could land in browser address bar, DevTools search, DevTools filter, page content, or another DevTools editor.
- Current source no longer uses `Ctrl+L`, but older logs had `panelFocusMethod=ctrl-shift-j/esc/ctrl-l/esc`, which could have sent focus into address/search contexts.
- The internal `Esc` is currently the sharpest risk because `Esc` is also the global automation stop key.
- Timing is hardcoded, not configurable.

Increasing the DevTools open wait to 2 seconds did not fix the failure. Latest elapsed time around 2328 ms confirms the longer wait was taken, then the run stopped during prompt preparation.

## 11. JS operator audit

File: `assets/js/devtools_bridge/ops_result.js`

Key source facts:

- The operator is wrapped in `copy(String((() => { ... })()))` at line `1`.
- `@@OP@@` and `@@ARGS@@` placeholders are at lines `2-3`.
- `bridge_probe` exists and returns `OK_BRIDGE` at lines `186-187`.
- `blitz_page_status` exists at lines `189-311`.
- CRM ops exist at lines `313-380`.
- Unknown ops return `NO_OP` at lines `382-383`.

Answers:

- `bridge_probe` exists.
- `bridge_probe` returns through the same top-level `copy(String(...))` wrapper as all other ops.
- All ops share the same wrapper.
- Unknown ops return `NO_OP`, not empty.
- A syntax error in the rendered JS would prevent any `copy(String(...))` return, but current failure evidence points to no submit before JS execution.
- `blitz_page_status` adds syntax/control-flow surface, but it does not explain `bridge_probe` failing before execution.
- `@@OP@@` and `@@ARGS@@` replacement is compatible with `RenderJsTemplate()`, which uses `JsLiteral()` at `adapters/devtools_bridge.ahk:418-455`.
- Missing args are safe: `const args = @@ARGS@@ || {};`.

No JS operator regression is the leading explanation. The bridge is not reaching execution.

## 12. Blitz status and iframe relevance

Blitz DOM is probably not the first blocker because:

- Manual DevTools JavaScript execution works.
- Manual Blitz scan copied a result successfully.
- `blitz_page_status` can model the mixed page state where the top document is a lead list and an accessible iframe is the lead-log action context.
- Current failures occur at `bridge_probe`, which does not inspect Blitz selectors.
- `crm_blitz_workflow.log` shows `BLITZ_BATCH_REPLAY_FAILED | reason=bridge-probe-failed;result=` before any Blitz page status or selector action.

Future risks after the bridge works:

- Mixed top lead-list plus lead-log iframe.
- Nested appointment iframe/date field timing.
- First-iframe assumptions in any remaining legacy code.
- Lead title matching from iframe document title.
- Legacy ID drift for Blitz controls.

Current `assets/js/devtools_bridge/ops_result.js` has already moved CRM actions toward frame-aware control lookup through `walkDocs()`, `findByIdInDocs()`, and `findSelectorInDocs()` at lines `32-71`.

## 13. Root-cause hypotheses ranked

### 1. Bridge-internal Escape triggers global stop hotkey

Evidence supporting:

- `DevToolsBridgePrepareConsolePrompt()` sends `Esc` at `adapters/devtools_bridge.ahk:246`.
- The global stop hotkey is `Esc::` at `hotkeys/debug_hotkeys.ahk:1`.
- Recent bridge logs stop at focus prep with `stopRequestedBeforeFocus=1`, `error=console-prompt-focus-interrupted`.
- `advisor_quote_trace.log` shows `STOP | UNKNOWN | manual-esc` at the same timestamps as bridge probe failures.
- `run_state.json` shows `stopFlag=true`, `lastAction=advisor-quote-stop`.

Evidence against:

- AutoHotkey-generated keys may not always retrigger same-script hotkeys depending on send/input level behavior, so this should be confirmed.
- A real human Esc press during every attempt would produce similar evidence, though repeated exact timing makes that less likely.

Source locations:

- `adapters/devtools_bridge.ahk:243-249`
- `hotkeys/debug_hotkeys.ahk:1-12`
- `workflows/advisor_quote_workflow.ahk:3233-3239`

How to confirm:

- Add a bridge-probe-only diagnostic that avoids sending `Esc`, or uses a non-hotkey-safe prompt focus method, then run Ctrl+Alt+K/H.
- Alternatively log immediately before and after `Send "{Esc}"` with a field indicating whether `StopFlag` flipped during that single call.

Safest fix shape:

- Do not use bare `Esc` for bridge prompt cleanup while `Esc::` is the global stop.
- Replace prompt preparation with a safe Console-focus strategy that cannot trigger the stop hotkey, or temporarily guard the stop hotkey from self-generated bridge cleanup.

### 2. Stale stopFlag active despite BeginAutomationRun

Evidence supporting:

- Latest bridge logs show `stopRequestedBeforeFocus=1`.
- `run_state.json` shows `stopFlag=true`.

Evidence against:

- Ctrl+Alt+H and Ctrl+Alt+K both call `BeginAutomationRun()` before `bridge_probe`.
- `BeginAutomationRun()` clears the in-memory `StopFlag`.
- `logs/run_state.json` is not read back into memory by current source.
- The repeated `manual-esc` log points more strongly to a fresh stop during bridge prompt prep than a stale file value.

How to confirm:

- Log `StopFlag` immediately after `BeginAutomationRun()` and immediately before `JS_DevToolsBridgeProbe()` in a diagnostic patch.

Safest fix shape:

- Keep clearing stale stop at run start.
- Add stop-source diagnostics and avoid internal `Esc`.

### 3. Focus helper exits before submit

Evidence supporting:

- Current failure exits from `DevToolsBridgePrepareConsolePrompt()` before paste/submit.
- `focusSucceeded=0`.

Evidence against:

- The logged reason is tied to stop interruption, not generic inability to focus.

How to confirm:

- Replace `Esc` focus prep temporarily with a no-Escape path and observe whether it reaches paste/submit.

### 4. Return logging changed control flow

Evidence supporting:

- Regression appeared around return logging/hardening work.

Evidence against:

- Logging runs in `finally` after the result path is already determined.
- The failing branch occurs before logging is called.

How to confirm:

- Inspect logs: they accurately show source branches.

Safest fix shape:

- Keep logging. It is now the best diagnostic surface.

### 5. Paste happens but Enter is skipped

Evidence supporting:

- Older stale logs had rendered JS on clipboard and no submit.

Evidence against:

- Current latest logs show paste is not attempted.

How to confirm:

- After fixing Escape/stop issue, watch for `consolePasteAttempted=1`, `consoleSubmitAttempted=0`.

### 6. Ctrl+L/focus method moves to wrong input

Evidence supporting:

- Older logs showed `panelFocusMethod=ctrl-shift-j/esc/ctrl-l/esc`.
- `Ctrl+L` could focus browser address bar or DevTools location/filter, depending context.

Evidence against:

- Current source no longer uses `Ctrl+L` in the bridge focus method.

Safest fix shape:

- Do not reintroduce `Ctrl+L` as Console prompt focus.

### 7. Clipboard wait/restore regression

Evidence supporting:

- Older logs showed rendered JS remaining on clipboard.

Evidence against:

- Latest logs show clipboard is not replaced with rendered JS at all; the stop happens before paste.
- Current source logs before restoring clipboard.

How to confirm:

- After stop/focus fix, check whether clipboard return wait reaches timeout with `consoleSubmitAttempted=1`.

### 8. JS operator syntax/render regression

Evidence supporting:

- Large operator asset changed recently, including `blitz_page_status`.

Evidence against:

- `bridge_probe` is simple and present.
- No evidence the rendered JS is submitted.
- Manual DevTools execution and manual scan worked.

How to confirm:

- Run a syntax check of rendered `bridge_probe` in a future validation patch.

### 9. Blitz selector drift

Evidence supporting:

- Blitz page has iframes and legacy controls; selector drift is always possible.

Evidence against:

- Failure occurs at `bridge_probe` before selector ops.
- Manual scan saw the page and controls.

Safest fix shape:

- Address after bridge probe reliably returns.

## 14. Recommended fix strategy

Recommended order:

1. Restore a canonical bridge sequence that does not send a stop hotkey as part of Console prompt preparation.
2. Add a minimal diagnostic proving whether `StopFlag` flips during bridge prompt preparation.
3. Confirm `bridge_probe` reaches `consolePasteAttempted=1` and `consoleSubmitAttempted=1`.
4. If `bridge_probe` still fails after submit, fix clipboard return timing/restore.
5. Only after bridge probe is reliable, continue validating Ctrl+Alt+K as the guarded current-lead primitive.
6. Then validate Ctrl+Alt+H as the batch orchestrator.
7. Keep frame-aware CRM ops, but do not treat them as the first blocker.
8. Centralize timing settings later. Random sleeps are not the main solution.

Do not start with Blitz selectors. The current failure is upstream of Blitz selectors.

## 15. Exact next patch prompt outline

Title:

Patch DevTools bridge prompt preparation so internal Console cleanup does not trigger global Esc stop.

Files likely changed:

- `adapters/devtools_bridge.ahk`
- `hotkeys/debug_hotkeys.ahk` only if a scoped self-generated-Escape guard is needed
- `docs/DEVTOOLS_BRIDGE_RETURN_LOGGING.md`
- Optional helper test file only if existing AHK checker can cover pure helper behavior

Hard restrictions:

- Do not change Ctrl+Alt+H business logic.
- Do not change Ctrl+Alt+K business logic.
- Do not change Blitz selectors.
- Do not change JS op return formats.
- Do not remove the user emergency stop behavior.
- Do not run unsafe AutoHotkey diagnostics.

Definition of done:

- Bridge prompt prep no longer uses bare `Esc` in a way that can fire `Esc::`.
- `bridge_probe` reaches paste/submit when not actually stopped.
- If a real stop happens, logs identify it clearly.
- No path leaves rendered JS on clipboard without a specific focus/paste/submit/stop event.
- Ctrl+Alt+H/K meanings remain unchanged.

Validation:

- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1`.
- If a JS syntax check is run, use only safe Node syntax checks for rendered `bridge_probe`.

Live validation steps:

1. Reload/restart the AHK script after patch.
2. Open Blitz in the work browser.
3. Run Ctrl+Alt+K first on an already-open lead log.
4. Confirm `logs/devtools_bridge_returns.log` shows `bridge_probe` with `consolePasteAttempted=1`, `consoleSubmitAttempted=1`, and `event=DEVTOOLS_RETURN_OK`.
5. Then run Ctrl+Alt+H from the lead list/open lead-log mixed state.
6. Collect logs if anything fails.

## 16. Files/logs to collect after next failure

Collect:

- `logs/devtools_bridge_returns.log`
- `logs/js_asset_errors.log`
- `logs/run_state.json`
- `logs/crm_blitz_workflow.log`
- `logs/advisor_quote_trace.log` only around STOP lines, without customer details
- Screenshot of DevTools Console only if logs remain ambiguous
- Current active page URL/title if possible

Do not collect or paste:

- Full rendered JavaScript payloads
- Raw lead/customer PII
- Full Blitz DOM dumps unless sanitized

## 17. Implementation note: Esc-free Console prep

The recommended bridge fix has been implemented narrowly in `adapters/devtools_bridge.ahk`.

The bridge no longer sends a bare `Esc` during `DevToolsBridgePrepareConsolePrompt()`. It uses an Esc-free prompt settle step after `Ctrl+Shift+J`, then the caller clears the Console prompt with `Ctrl+A`. The global human `Esc::` emergency stop hotkey was not changed.

Additional bridge return fields now distinguish Console prep, clipboard, paste, submit, and stale-rendered-clipboard causes. A healthy live `bridge_probe` should now reach `consolePasteAttempted=1`, `consoleSubmitAttempted=1`, `submitMethod=enter`, and `rootCauseHint=ok`.
