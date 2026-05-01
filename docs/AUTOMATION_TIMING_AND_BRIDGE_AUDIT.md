# Automation Timing and DevTools Bridge Audit

## 1. Executive summary

The current reliability risk is mixed, but the strongest live evidence points first to DevTools bridge submission/stop-state timing, not Blitz selector drift.

Observed bridge logs show `bridge_probe` failing before Blitz logic runs. Older entries show stale rendered-JS clipboard after timeout, while newer entries show `DEVTOOLS_RETURN_STOPPED_BEFORE_SUBMIT` with `consoleFocusAttempted=1`, `focusSucceeded=0`, `consolePasteAttempted=0`, and `consoleSubmitAttempted=0`. That means the bridge did not reach paste/Enter. It is not yet a Blitz selector failure.

Timing is partly centralized but uneven:

- QUO/follow-up, batch, prospect fill, and CRM activity sleeps are configurable through `config/timings.ini` and loaded in `main.ahk:116-151`.
- DevTools bridge open/focus/paste/submit/return waits are hardcoded in `adapters/devtools_bridge.ahk:21-239`.
- Advisor Pro workflow has its own `db["timeouts"]` map in `domain/advisor_quote_db.ahk:47-59`, plus additional local waits in `workflows/advisor_quote_workflow.ahk`.
- Clipboard helper timings are hardcoded in `adapters/clipboard_adapter.ahk`.

There is no explicit slow-machine / laptop power-save timing profile for DevTools bridge or Blitz. The only "SlowMode" profile currently belongs to QUO message scheduling, not DevTools or CRM/Blitz bridge execution.

Diagnostics are much better than before: `logs/devtools_bridge_returns.log` can now distinguish focus, paste, submit, stale clipboard, timeout, and stop checkpoints. The remaining weakness is that Console prompt focus is not positively verified; it is inferred from keystrokes and subsequent clipboard return.

## 2. DevTools bridge timing map

| Step | Source | Current timing | Configurable? | Current evidence | Weakness |
| --- | --- | ---: | --- | --- | --- |
| Public work-browser call | `RunDevToolsJS()` / `RunDevToolsJSGetResult()`, `adapters/devtools_bridge.ahk:1-9` | delegates | No | Used by CRM/Blitz and QUO JS assets | No direct timing control here. |
| Retry wrapper | `RunDevToolsJSInternal()`, `adapters/devtools_bridge.ahk:21-36` | 2 attempts for result ops; 250 ms between attempts | No | `logs/js_asset_errors.log` shows repeated "Empty result; retrying" | Retry count and retry delay are hardcoded. |
| Focus browser | `DevToolsFocusByMode()`, `adapters/devtools_bridge.ahk:380-382`; `FocusWorkBrowser()`, `adapters/browser_focus_adapter.ahk:19-23` | Chrome/Edge `WinWaitActive` 2 sec | No | Browser found enough to open DevTools in live failures | Verifies browser process, not tab, URL, DevTools panel, or Console prompt. |
| Open/reuse DevTools | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:84-89` | `Send "^+j"`, then 500 ms | No | Logs show `consoleFocusAttempted=1` after this point | 500 ms may be short on slower power mode; DevTools readiness is not positively checked. |
| Console prompt focus | `DevToolsBridgePrepareConsolePrompt()`, `adapters/devtools_bridge.ahk:243-250` | `Esc`, then 80 ms | No | Logs show `consoleFocusAttempted=1`, but latest failures have `focusSucceeded=0` due stop | Does not verify the caret is in Console prompt. Could still be in filter/search/drawer. |
| Clear prompt | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:102-113` | `Ctrl+A`, then 80 ms | No | No specific control-state evidence | Safe only if Console prompt is focused. |
| Set rendered JS clipboard | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:116-144` | clear clipboard, 30 ms, set JS, `WaitForClip(1000)` | No | Older logs showed rendered JS left on clipboard; newer code sets clipboard after focus | Clipboard set timeout may be short under system stress. |
| Paste JS | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:146-162` | `Ctrl+V`, then 120 ms | No | New fields: `consolePasteAttempted`, `consolePasteSucceeded`, `consolePasteFailed` | Paste success is not positively verified; `consolePasteSucceeded=unknown` on normal path. |
| Submit JS | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:163-174` | `Enter`, then 300 ms if expecting result | No | Older evidence: `consoleSubmitAttempted=0`; current code logs stop/failure before submit | Enter submission is not positively verified except by clipboard return. |
| Poll return | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:176-194` | 25 polls x 100 ms = 2.5 sec | No | Timeout entries elapsed around 4.7 sec including setup | Return timeout can be too short if DevTools is slow, page is busy, or copy permission is delayed. |
| Close/refocus | `RunDevToolsJSInternalOnce()`, `adapters/devtools_bridge.ahk:196-211` | close wait 220 ms; refocus wait 150 ms | No | Not the live failure layer yet | Refocus is hardcoded and not verified beyond browser activation. |
| Log result | `DevToolsBridgeLogReturn()`, `adapters/devtools_bridge.ahk:263-346` | immediate | N/A | Captures event, op, timing, hashes, focus/paste/submit/stop fields | Log is good; redaction/capping exists. |

Specific answers:

- `consoleFocusAttempted=1` but `consoleSubmitAttempted=0` can happen in `RunDevToolsJSInternalOnce()` between `adapters/devtools_bridge.ahk:92` and `168`. Current source logs specific early exits for stop/focus/select/clipboard/paste/enter interruptions.
- There is a 500 ms delay after opening DevTools before focus logic (`adapters/devtools_bridge.ahk:85`).
- There is a 120 ms delay after paste before Enter (`adapters/devtools_bridge.ahk:154-170`).
- There is a 300 ms delay after Enter before polling result for result ops (`adapters/devtools_bridge.ahk:171`).
- Console prompt is not positively verified.
- Focus could remain in the wrong DevTools area because the bridge uses keystrokes, not DOM/UI automation of the DevTools prompt.
- Current source no longer sets rendered JS before Console focus, reducing the old "clipboard set then stop before Enter" risk. Stop can still abort before paste/submit, now logged explicitly.
- Slower CPU/power-save can plausibly make the 500/80/120/300/2500 ms bridge waits too short.

## 3. Clipboard timing and stale result audit

Clipboard helpers:

- `BeginAutomationRun()` clears `StopFlag` and persists run state at `adapters/clipboard_adapter.ahk:1-4`.
- `WaitForClip(timeoutMs := 1000)` polls `ClipWait(0.05)` until timeout at `adapters/clipboard_adapter.ahk:25-32`.
- `SetClip()` clears clipboard, waits 30 ms, sets text, waits up to 1000 ms at `adapters/clipboard_adapter.ahk:40-49`.
- `PasteValue()` waits 60 ms after setting clipboard, sends `Backspace`, waits 60 ms, pastes, waits 90 ms at `adapters/clipboard_adapter.ahk:52-69`.
- `PasteValueRaw()` waits 60 ms, pastes, waits 90 ms at `adapters/clipboard_adapter.ahk:73-85`.

DevTools bridge clipboard path:

- Backs up `ClipboardAll()` at `adapters/devtools_bridge.ahk:75`.
- Sets rendered JS after Console focus at `adapters/devtools_bridge.ahk:122-144`.
- Polls result by comparing `A_Clipboard != sentCode` and nonblank at `adapters/devtools_bridge.ahk:176-190`.
- Restores clipboard in `finally` at `adapters/devtools_bridge.ahk:235-239`.

Answers:

- Yes, the rendered JS can remain on clipboard during a failed attempt before `finally`, but final restore should put the prior clipboard back if `savedClipCaptured=true`.
- Rendered-JS clipboard is treated differently from true empty return by `staleClipboardSuspected`, `consoleSubmissionStale`, and `probeFailedStale` in `adapters/devtools_bridge.ahk:282-285`.
- Clipboard restore does not appear too early; it occurs after logging in `finally`. The risk is not early restore, but relying on clipboard mutation as the only proof of Console execution.
- Another automation path could overwrite clipboard if running concurrently, but this script appears single-process/hotkey-driven. No lock prevents another hotkey from firing during a bridge attempt.
- Logs are capped/redacted in `DevToolsBridgeRedact()` at `adapters/devtools_bridge.ahk:349-363`; result previews are capped and emails/phones/SSNs/long IDs are redacted.

## 4. Run-state and stop-flag audit

Stop/run-state source:

- `StopFlag` global default is `false` in `main.ahk:27`.
- `PersistRunState()` writes `running`, `stopFlag`, `lastAction`, and timestamps in `main.ahk:195-213`.
- `Esc` sets `StopFlag := true`, `running := false`, and persists `stop-requested` in `hotkeys/debug_hotkeys.ahk:1-7`.
- Advisor stop logging persists `advisor-quote-stop` in `workflows/advisor_quote_workflow.ahk:3233-3239`.
- `BeginAutomationRun()` sets in-memory `StopFlag := false` and persists `automation-begin` in `adapters/clipboard_adapter.ahk:1-4`.

Answers:

- A stale `stopFlag=true` in `logs/run_state.json` is not read back into `StopFlag` at runtime. By source, it should not block later runs after `BeginAutomationRun()`. However, if the same AHK process still has `StopFlag=true` and a workflow probes before calling `BeginAutomationRun()`, it can block.
- `Ctrl+Alt+H` clears stop state at start in `RunCrmAttemptedContactForLatestBatchOkLeads()`, `adapters/crm_adapter.ahk:456-459`.
- `Ctrl+Alt+K` now clears stop state at start in `RunCrmAttemptedContactWorkflow()`, `workflows/crm_activity.ahk:28-30`.
- Current bridge checks stop before focus, before paste, before submit, and while waiting. Current code avoids placing rendered JS on clipboard until after focus.
- If stop happens after rendered JS is placed on clipboard but before Enter, the bridge should log `DEVTOOLS_RETURN_STOPPED_BEFORE_SUBMIT`, `stopRequestedBeforeSubmit=1`, and `consoleSubmitAttempted=0`.

Runtime evidence:

- `logs/run_state.json` currently shows `stopFlag=true`, `lastAction=advisor-quote-stop`, updated `2026-04-30 06:34:31`.
- `logs/devtools_bridge_returns.log` latest entries show `DEVTOOLS_RETURN_STOPPED_BEFORE_SUBMIT`, `stopRequestedBeforeFocus=1`, `focusSucceeded=0`, `consolePasteAttempted=0`, `consoleSubmitAttempted=0`.

This means the latest failures are cleanly diagnosed as stopped before submit, but it remains important to confirm whether the active AHK process is the patched one and whether `BeginAutomationRun()` is actually reached before `bridge_probe`.

## 5. Ctrl+Alt+H timing map

Entry and batch flow:

| Step | Source | Timing/wait | Readiness/diagnostics | Risk |
| --- | --- | --- | --- | --- |
| Hotkey | `hotkeys/crm_hotkeys.ahk:7` | none | Direct call | Low |
| Clear stop | `RunCrmAttemptedContactForLatestBatchOkLeads()`, `adapters/crm_adapter.ahk:456-459` | immediate | `PersistRunState("automation-begin")` | Low, if patched process is running |
| Load OK leads | `LoadLatestBatchOkLeadNames()`, `workflows/batch_run.ahk:26-40` | file read | `BATCH_OK_LIST_LOADED` in CRM log | Low |
| Focus browser | `adapters/crm_adapter.ahk:466-469` | `WinWaitActive` 2 sec via focus adapter | no tab validation | Medium |
| Bridge probe | `adapters/crm_adapter.ahk:472-477` | full DevTools bridge timings | bridge return log | High until live bridge returns OK |
| Page status | `CrmGetBlitzPageStatus()`, `adapters/crm_adapter.ahk:250-259`; first call at `479` | bridge op | `BLITZ_STATUS_PRECHECK` | Medium |
| Current lead title | `GetCurrentBlitzLeadName()`, `adapters/crm_adapter.ahk:376-378`; first call at `480` | bridge op | `BLITZ_CURRENT_LEAD_TITLE` | Medium |
| Open first/target lead | `CrmEnsureBlitzLeadOpen()`, `adapters/crm_adapter.ahk:441-454` | `WaitForBlitzLeadMatch()` up to 12000 ms, 250 ms poll | open attempt/result logs | Medium |
| Wait ready lead-log | `CrmWaitForBlitzAttemptedContactReady()`, `adapters/crm_adapter.ahk:275-296` | 12000 ms, 300 ms poll | ready/wait timeout logs | Medium |
| Per-lead mutation | `CrmRunAttemptedContactAppointmentGuarded()`, `adapters/crm_adapter.ahk:299-309` | status check then CRM sequence | start/done/fail logs | Medium |
| Between leads | `adapters/crm_adapter.ahk:559-562` | 500 ms | none beyond logs | Medium |
| Next lead | `BlitzGoToNextLead()`, `adapters/crm_adapter.ahk:427-431` | `WaitForBlitzLeadChange()` up to 12000 ms, 250 ms poll | next attempt/done logs | Medium |
| Fallback open next target | `adapters/crm_adapter.ahk:566-573` | same open/match wait | result logs | Medium |

Missing diagnostics:

- There is no direct screenshot/scan of DevTools focus state.
- `GetCurrentBlitzLeadName()` only returns title text; if blank it does not return reason details.
- Batch lead names are operational input and logged in concise form; avoid copying full logs into reports.

## 6. Ctrl+Alt+K timing map

Current-lead attempted contact:

| Step | Source | Timing/wait | Readiness/diagnostics | Risk |
| --- | --- | --- | --- | --- |
| Hotkey | `hotkeys/crm_hotkeys.ahk:5` | none | Direct call | Low |
| Clear stop | `RunCrmAttemptedContactWorkflow()`, `workflows/crm_activity.ahk:28-30` | immediate | run state | Low |
| Focus browser | `workflows/crm_activity.ahk:34-37` | `WinWaitActive` 2 sec | no tab validation | Medium |
| Bridge probe | `workflows/crm_activity.ahk:39-44` | full bridge | bridge log | High until live probe passes |
| Guarded status | `CrmRunAttemptedContactAppointmentGuarded()`, `adapters/crm_adapter.ahk:299-305` | one `blitz_page_status` bridge op | logs ready/missing/evidence | Medium |
| Focus action dropdown | `CrmRunAttemptedContactAppointment()`, `adapters/crm_adapter.ahk:148-154` | `CRM_ACTION_FOCUS_DELAY` default 500 ms | no field-level verification after click | Medium |
| Key sequence to activity | `adapters/crm_adapter.ahk:155-166` | `CRM_KEYSTEP_DELAY` 150 ms; `CRM_MEDIUM_DELAY` 250 ms; `CRM_SHORT_DELAY` 200 ms | no selection verification | Medium/high |
| Paste note | `adapters/crm_adapter.ahk:168-174` | `SetClip()` 1000 ms; 80 ms; paste; `CRM_MEDIUM_DELAY` | clipboard failure dialog only | Medium |
| Save history | `adapters/crm_adapter.ahk:176-177` | `CRM_SAVE_HISTORY_DELAY` 800 ms | JS returns OK/NO but caller does not check | Medium/high |
| Add appointment | `adapters/crm_adapter.ahk:179-180` | `CRM_ADD_APPOINTMENT_DELAY` 800 ms | JS return ignored | Medium/high |
| Focus date field | `adapters/crm_adapter.ahk:182-183` | `CRM_FOCUS_DATE_DELAY` 300 ms | JS return ignored | Medium/high |
| Date preset | `CrmApplyAppointmentPreset()`, `adapters/crm_adapter.ahk:121-145` | 80 ms, 220 ms, tab waits 50 ms per tab, CRM delays | no date field value verification | Medium |
| Final save | `adapters/crm_adapter.ahk:188-189` | `CRM_FINAL_SAVE_DELAY` 400 ms | JS return ignored | Medium/high |

The top-level status guard is good. The internal activity sequence still relies on fixed sleeps and ignores several JS boolean return values.

## 7. Blitz iframe / frame timing map

Current source:

- `assets/js/devtools_bridge/ops_result.js:32-44` walks accessible frames recursively.
- `assets/js/devtools_bridge/ops_result.js:46-69` adds control-target helpers across accessible documents.
- `blitz_page_status` at `assets/js/devtools_bridge/ops_result.js:189` inspects top document and accessible frames.
- CRM action ops now use `findByIdInDocs()` / `findDoc()` / `findSelectorInDocs()` at `assets/js/devtools_bridge/ops_result.js:313-371`.
- `getFrameDoc()` still exists at `assets/js/devtools_bridge/ops_result.js:31`, but current CRM cases no longer use it for the hardened actions.

Frame-aware by target:

- action dropdown
- history save
- add appointment
- date input
- final appointment save
- next lead
- lead-log links

Wait concerns:

- After opening a lead log, AHK waits up to 12000 ms for current title match and separately up to 12000 ms for ready attempted-contact status.
- After clicking New Appointment, AHK waits only `CRM_ADD_APPOINTMENT_DELAY` default 800 ms before focusing date field.
- Appointment iframe/date readiness is not polled through `blitz_page_status`; this is a likely timing gap on slow machines.

## 8. FA / follow-up automation timing map

Relevant hotkeys:

- `Ctrl+Alt+6` / `^!6`: `ScheduleLeadFollowupsByClipboard(false)` in `hotkeys/schedule_hotkeys.ahk:6`.
- `Ctrl+Alt+7` / `^!7`: `ScheduleLeadFollowupsByClipboard(true)` in `hotkeys/schedule_hotkeys.ahk:7`.
- `Ctrl+Alt+8` / `^!8`: `ShowFollowupBatchPickerFromClipboard()` in `hotkeys/schedule_hotkeys.ahk:8`.

Scheduling source:

- `ScheduleFollowupMessages()` loops messages and calls QUO schedule helpers at `workflows/message_schedule.ahk:1-10`.
- `ScheduleBuilderForLead()` focuses browser, waits 200 ms, and schedules initial quote at `workflows/message_schedule.ahk:14-32`.
- `ScheduleLeadFollowupsByClipboard()` reads clipboard with `ClipWait(1)` and starts automation at `workflows/message_schedule.ahk:39-61`.
- `SendSelectedBatchV2()` uses the picker and calls `EnsureQuoComposerReady()` before scheduling at `workflows/message_schedule.ahk:111-168`.

QUO scheduling:

- Fast/paste mode: `QuoScheduleCurrentMessage()`, `adapters/quo_adapter.ahk:143-181`.
  - 100 ms after message clipboard set
  - paste
  - `Ctrl+Alt+Enter`
  - 300 ms after schedule UI open
  - 100 ms after date/time clipboard set
  - paste
  - 300 ms
  - Enter
  - 200 ms final wait
- Stable/typed mode: `QuoScheduleCurrentMessageTyped()`, `adapters/quo_adapter.ahk:184-220`.
  - `SLOW_ACTIVATE_DELAY` default 250 ms
  - 50 ms after message clipboard set
  - paste
  - `SLOW_AFTER_MSG` default 550 ms
  - `Ctrl+Alt+Enter`
  - `SLOW_AFTER_SCHED` default 650 ms
  - type date/time
  - `SLOW_AFTER_DT_PASTE` default 650 ms
  - Enter
  - `SLOW_AFTER_ENTER` default 300 ms

Scheduled-message deletion:

- No scheduled-message deletion implementation was found.
- Searches for `delete scheduled`, `scheduled delete`, `delete message`, `DeleteScheduled`, and related patterns found no runtime code.
- Therefore there is no delete pre-click delay, delete post-click delay, confirmation handling, retry/poll loop, or config setting to audit yet.

FA abbreviation:

- No dedicated `FA` automation was found. The only search hit was unrelated text (`ALFA ROMEO`) in Advisor vehicle data.

## 9. Current settings/config audit

| Setting | File | Default/current | Unit | Used by | User clarity | Better description |
| --- | --- | ---: | --- | --- | --- | --- |
| `SlowMode.ActivateDelay` | `config/timings.ini:2`, loaded `main.ahk:116` | 250 | ms | stable QUO scheduling | Terse | Wait after activating browser before scheduling. |
| `SlowMode.AfterMessage` | `config/timings.ini:3`, loaded `main.ahk:117` | 550 | ms | typed scheduling after message paste | Terse | Wait after pasting follow-up text before opening schedule dialog. |
| `SlowMode.AfterSchedule` | `config/timings.ini:4`, loaded `main.ahk:118` | 650 | ms | typed scheduling after `Ctrl+Alt+Enter` | Terse | Wait for schedule dialog/date field to appear. |
| `SlowMode.AfterDatePaste` | `config/timings.ini:5`, loaded `main.ahk:119` | 650 | ms | typed scheduling date/time | Terse | Wait after typing scheduled date/time before pressing Enter. |
| `SlowMode.AfterEnter` | `config/timings.ini:6`, loaded `main.ahk:120` | 300 | ms | typed scheduling final submit | Terse | Wait after confirming scheduled send. |
| `Batch.AfterAltN` | `config/timings.ini:10`, loaded `main.ahk:122` | 5000 | ms | QUO new conversation | Medium | Wait after Alt+N for new conversation UI. |
| `Batch.AfterPhone` | `config/timings.ini:11`, loaded `main.ahk:123` | 650 | ms | after phone paste | Terse | Wait after recipient phone is pasted. |
| `Batch.AfterTab` | `config/timings.ini:12`, loaded `main.ahk:124` | 150 | ms | tab navigation | Terse | Wait after moving from recipient to composer. |
| `Batch.AfterSchedule` | `config/timings.ini:13`, loaded `main.ahk:125` | 600 | ms | batch after builder/followups | Ambiguous | Wait after each scheduling block completes. |
| `Batch.AfterEnter` | `config/timings.ini:14`, loaded `main.ahk:126` | 150 | ms | lead holder selection | Terse | Wait after pressing Enter in lead-name picker. |
| `Batch.AfterNamePick` | `config/timings.ini:15`, loaded `main.ahk:127` | 250 | ms | lead holder selection | Terse | Wait after pasting/selecting holder name. |
| `Batch.AfterTagPick` | `config/timings.ini:16`, loaded `main.ahk:128` | 250 | ms | tag selection | Terse | Wait after choosing QUO tag. |
| `Batch.BeforeTagPaste` | `config/timings.ini:17`, loaded `main.ahk:129` | 500 | ms | tag paste | Medium | Wait before pasting tag after control focus. |
| `Batch.AfterTagPaste` | `config/timings.ini:18`, loaded `main.ahk:130` | 700 | ms | tag paste | Medium | Wait for tag dropdown/result after paste. |
| `Batch.PostParticipantReadyStable` | `config/timings.ini:19`, loaded `main.ahk:131` | 150 | ms | participant input ready | Too technical | Extra wait after recipient field is detected in stable mode. |
| `Batch.PostParticipantReadyFast` | `config/timings.ini:20`, loaded `main.ahk:132` | 0 | ms | participant input ready | Too technical | Extra wait after recipient field is detected in fast mode. |
| `Batch.AfterParticipantToComposer` | `config/timings.ini:21`, loaded `main.ahk:133` | 1000 | ms | recipient to composer | Medium | Wait after tabbing from recipient to message composer. |
| `Batch.AfterTagComplete` | `config/timings.ini:22`, loaded `main.ahk:134` | 300 | ms | batch tag complete | Terse | Wait after tag/save action is complete. |
| `ProspectFill.*` | `config/timings.ini:25-29`, loaded `main.ahk:136-141` | 30-500 | ms | prospect form fill | Mostly clear | Add "milliseconds" and target context. |
| `CrmActivity.ActionFocusDelay` | `config/timings.ini:32`, loaded `main.ahk:143` | 500 | ms | after focusing CRM action dropdown | Medium | Wait after CRM action dropdown is focused/clicked. |
| `CrmActivity.KeyStepDelay` | `config/timings.ini:33`, loaded `main.ahk:144` | 150 | ms | CRM key sequence | Terse | Delay between individual CRM keyboard steps. |
| `CrmActivity.ShortDelay` | `config/timings.ini:34`, loaded `main.ahk:145` | 200 | ms | CRM sequence | Terse | Short pause after tab navigation. |
| `CrmActivity.MediumDelay` | `config/timings.ini:35`, loaded `main.ahk:146` | 250 | ms | CRM sequence | Terse | Standard pause after CRM field/action changes. |
| `CrmActivity.QuoteShiftTabDelay` | `config/timings.ini:36`, loaded `main.ahk:147` | 3050 | ms | quote-call workflow | Medium | Wait after Shift+Tab during quote-call action selection. |
| `CrmActivity.SaveHistoryDelay` | `config/timings.ini:37`, loaded `main.ahk:148` | 800 | ms | after history save click | Medium | Wait after saving history note before adding appointment. |
| `CrmActivity.AddAppointmentDelay` | `config/timings.ini:38`, loaded `main.ahk:149` | 800 | ms | after add appointment | Medium | Wait for appointment form/frame to appear. |
| `CrmActivity.FocusDateDelay` | `config/timings.ini:39`, loaded `main.ahk:150` | 300 | ms | date field focus | Terse | Wait after date/time field focus before typing/pasting preset. |
| `CrmActivity.FinalSaveDelay` | `config/timings.ini:40`, loaded `main.ahk:151` | 400 | ms | final appointment save | Medium | Wait after appointment save before next action. |
| Advisor `shortMs` | `domain/advisor_quote_db.ahk:52` | 1200 | ms | Advisor waits | Not in user timing UI | Short page/action settle. |
| Advisor `actionMs` | `domain/advisor_quote_db.ahk:53` | 4000 | ms | Advisor click/action waits | Not in UI | Wait for one UI action. |
| Advisor `pageMs` | `domain/advisor_quote_db.ahk:54` | 25000 | ms | Advisor pages | Not in UI | Wait for page load/state. |
| Advisor `transitionMs` | `domain/advisor_quote_db.ahk:55` | 35000 | ms | Advisor route transitions | Not in UI | Wait for route/state transition. |
| Advisor `pollMs` | `domain/advisor_quote_db.ahk:56` | 350 | ms | Advisor polling | Not in UI | Poll interval for Advisor state/status checks. |
| Advisor `maxRetries` | `domain/advisor_quote_db.ahk:57-58` | 3 | count | Advisor state retries | Not in UI | Retry count for state handlers. |

Missing config today:

- DevTools open wait
- Console focus settle
- DevTools paste settle
- Submit settle
- Clipboard return timeout / poll interval
- DevTools retry count
- Blitz lead-log/status wait
- Appointment-frame readiness wait
- Scheduled-message delete waits

## 10. Proposed timing profile design

Recommended new timing categories:

| Setting | Normal default | Slow-machine default | Plain English description | Place | Migration risk |
| --- | ---: | ---: | --- | --- | --- |
| `DevToolsBridge.OpenWaitMs` | 750 | 1500 | Wait after opening DevTools before interacting with Console. | `config/timings.ini [DevToolsBridge]` | Low |
| `DevToolsBridge.ConsoleFocusSettleMs` | 150 | 400 | Wait after Console focus cleanup before selecting/pasting. | same | Low |
| `DevToolsBridge.PasteSettleMs` | 200 | 500 | Wait after pasting rendered JS before pressing Enter. | same | Low |
| `DevToolsBridge.SubmitSettleMs` | 500 | 1000 | Wait after Enter before polling for copied result. | same | Low |
| `DevToolsBridge.ReturnTimeoutMs` | 5000 | 10000 | Maximum wait for `copy(String(...))` to update clipboard. | same | Medium |
| `DevToolsBridge.ReturnPollMs` | 100 | 150 | Clipboard polling interval while waiting for JS return. | same | Low |
| `DevToolsBridge.RetryCount` | 2 | 3 | Number of attempts for result-returning bridge ops. | same | Medium |
| `Blitz.LeadOpenWaitMs` | 12000 | 20000 | Wait for opened lead log/title to match target. | `[Blitz]` | Low |
| `Blitz.IframeSettleMs` | 500 | 1000 | Extra wait after lead-log iframe appears before mutation. | `[Blitz]` | Low |
| `Blitz.AppointmentFrameWaitMs` | 8000 | 15000 | Poll for appointment date/save controls after Add Appointment. | `[Blitz]` | Medium |
| `Blitz.NextLeadWaitMs` | 12000 | 20000 | Wait for Next lead title/status change. | `[Blitz]` | Low |
| `FollowUp.DeleteScheduledPreClickMs` | 300 | 800 | Wait after locating scheduled-message delete control before click. | `[FollowUp]` | Future only |
| `FollowUp.DeleteScheduledConfirmWaitMs` | 2000 | 5000 | Wait for delete confirmation UI. | `[FollowUp]` | Future only |
| `FollowUp.DeleteScheduledPostWaitMs` | 1000 | 2500 | Wait after confirming delete before next action. | `[FollowUp]` | Future only |
| `Clipboard.SetTimeoutMs` | 1000 | 3000 | Maximum wait for clipboard set. | `[Clipboard]` | Medium |
| `Clipboard.RestoreDelayMs` | 50 | 150 | Wait after restoring clipboard before next action. | `[Clipboard]` | Low |
| `Typing.KeyDelayMs` | 150 | 300 | Delay between UI-driving keystrokes. | existing or `[Typing]` | Medium |

The key design point is profile support, not just bigger numbers: the user should be able to select Normal vs Slow/Laptop Power Save without editing many fields manually.

## 11. Proposed implementation phases

| Patch | Scope | Likely files | Risk | Tests | Live validation |
| --- | --- | --- | --- | --- | --- |
| T0 | Bridge-return logs already exist; verify field coverage and redaction. | `adapters/devtools_bridge.ahk`, docs | Low | AHK checker | Trigger `bridge_probe` |
| T1 | Fix stale stop flag / `consoleSubmitAttempted=0` path. | `adapters/devtools_bridge.ahk`, `workflows/crm_activity.ahk`, `adapters/crm_adapter.ahk` | Medium | AHK checker | Ctrl+Alt+K/H bridge probe |
| T2 | Centralize DevTools bridge timing constants/settings. | `main.ahk`, `config/timings.ini`, `workflows/config_ui.ahk`, `adapters/devtools_bridge.ahk` | Medium | AHK checker | Bridge probe on charger/off charger |
| T3 | Ctrl+Alt+K uses guarded page status before mutation. | `workflows/crm_activity.ahk`, `adapters/crm_adapter.ahk` | Medium | AHK checker | Current lead attempted contact |
| T4 | Ctrl+Alt+H batch orchestrator calls shared Ctrl+Alt+K engine. | `adapters/crm_adapter.ahk` | Medium/high | AHK checker | Batch OK replay |
| T5 | CRM JS ops frame-aware by control target. | `assets/js/devtools_bridge/ops_result.js` | Medium | JS syntax check | Lead list with open iframe |
| T6 | Centralize FA scheduled-message deletion timings. | Future deletion module, config UI/timings | Unknown | TBD | Requires feature/page scan |
| T7 | Add user-facing descriptions for timing settings. | `workflows/config_ui.ahk`, docs | Low | AHK checker | Config UI review |

T1, T3, T4, and T5 are already partially/mostly implemented in current source. The next unimplemented reliability patch should be T2.

## 12. Exact recommended next patch

Recommended next patch: centralize DevTools bridge timing constants/settings (T2).

Why:

- The current failure evidence is bridge-level, and DevTools timing is hardcoded.
- Laptop power mode likely affects DevTools open/focus/paste/return timings.
- Existing settings cover QUO/CRM activity waits but not the bridge itself.
- Increasing random sleeps would hide the problem; named settings with normal/slow defaults make it testable.

The patch should add `[DevToolsBridge]` timing keys, load them in `main.ahk`, use them in `adapters/devtools_bridge.ahk`, and expose clear labels/descriptions in config UI. Do not change Blitz selectors or business behavior in that patch.

## 13. What to collect after next failure

Collect these files:

- `logs/devtools_bridge_returns.log`
- `logs/js_asset_errors.log`
- `logs/run_state.json`
- `logs/crm_blitz_workflow.log`

If return logs still do not prove whether Console prompt received the paste/Enter, also collect:

- screenshot of DevTools Console only
- whether laptop was charging or on battery/power saver
- whether the AHK process was restarted after the latest patch

Do not collect raw lead list contents unless needed for lead matching. If collected, keep it local and avoid pasting PII into issue reports.
