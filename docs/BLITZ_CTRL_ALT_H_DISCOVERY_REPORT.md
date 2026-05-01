# Blitz Ctrl+Alt+H Discovery Report

## 1. Executive summary

`Ctrl+Alt+H` currently starts `RunCrmAttemptedContactForLatestBatchOkLeads()` from `hotkeys/crm_hotkeys.ahk:7`. It is not a generic page scanner and it is not a clipboard parser at runtime. It is a mixed Blitz/CRM replay workflow:

- loads the saved successful batch lead-name list from `logs/latest_batch_ok_leads.txt`
- focuses Chrome or Edge through `FocusWorkBrowser()`
- injects the CRM/Blitz JS operator through DevTools
- locates the current Blitz lead or opens the first saved OK lead from a lead list
- runs the attempted-contact CRM activity sequence on matching leads
- advances through Blitz lead logs with the Next link

The source describes `Ctrl+Alt+H` as a "latest-batch-ok CRM replay" rather than a direct lead auto-update of phone/mobile fields. The update it performs is CRM activity/history/appointment work: action dropdown, history note, new appointment, date/time, and save.

`Ctrl+Alt+K` currently starts `RunCrmAttemptedContactWorkflow()` from `hotkeys/crm_hotkeys.ahk:5`. In this repo it is not a scanner either. It runs the attempted-contact activity on the currently open Blitz/CRM lead page and does not traverse saved batch leads.

Most likely failure layer from current source/logs: DevTools/clipboard bridge or Blitz page state detection. `logs/js_asset_errors.log` shows recent empty DevTools result retries in `mode=work`; this means the console operator did not return through `copy(String(...))`. A second likely layer is page-model drift: the current Blitz JS assumes specific iframe structure and legacy IDs.

No patch is implemented in this report.

## 2. Hotkey map

| Hotkey | File | Function called | Workflow | Required active app/page | Input source | Output/action |
| --- | --- | --- | --- | --- | --- | --- |
| `Ctrl+Alt+H` / `^!h` | `hotkeys/crm_hotkeys.ahk:7` | `RunCrmAttemptedContactForLatestBatchOkLeads()` | Batch OK leads to CRM attempted-contact replay | Chrome/Edge on Blitz lead list or open lead log | `logs/latest_batch_ok_leads.txt`; current Blitz page | Adds attempted-contact note/appointment, walks Blitz Next |
| `Ctrl+Alt+K` / `^!k` | `hotkeys/crm_hotkeys.ahk:5` | `RunCrmAttemptedContactWorkflow()` | Current-lead attempted-contact activity | Chrome/Edge on an open Blitz/CRM lead log | Current page only; templates/date config | Adds attempted-contact note/appointment to current lead |
| `Ctrl+Alt+J` / `^!j` | `hotkeys/crm_hotkeys.ahk:6` | `RunCrmQuoteCallWorkflow()` | Current-lead quote-call activity | Chrome/Edge on open Blitz/CRM lead log | Current page only | Adds quote-call note/appointment |
| `Ctrl+Alt+B` / `^!b` | `hotkeys/lead_hotkeys.ahk:80` | `RunBatchFromClipboard("stable")` | Batch QUO follow-up/tag workflow | Chrome/Edge QUO/CRM context | Clipboard batch | Writes batch log and OK lead list |
| `Ctrl+Alt+N` / `^!n` | `hotkeys/lead_hotkeys.ahk:81` | `RunBatchFromClipboard("fast")` | Fast batch QUO follow-up/tag workflow | Chrome/Edge QUO/CRM context | Clipboard batch | Writes batch log and OK lead list |
| `Ctrl+Alt+U` / `^!u` | `hotkeys/lead_hotkeys.ahk:1` | inline `RunQuickLeadCreateAndTag()` | Single lead quick create/tag | Chrome/Edge QUO context | Clipboard single lead | Creates conversation, selects holder, applies tag |
| `Ctrl+Alt+L` / `^!l` | `hotkeys/debug_hotkeys.ahk:92` | inline batch preview | Debug parser preview | none specific | Clipboard batch | MsgBox preview of parsed lead holder/prices |
| `Ctrl+Alt+S` / `^!s` | `hotkeys/debug_hotkeys.ahk:114` | inline `AdvisorQuoteScanCurrentPage()` | Advisor page scanner | Edge on Advisor Pro | Current Advisor page | Saves Advisor scan JSON |
| `Ctrl+Alt+G` / `^!g` | `hotkeys/debug_hotkeys.ahk:16` | `RunQuoTagSelector()` | QUO tag selector diagnostic | Chrome/Edge QUO context | Current page | MsgBox selector result |

Important correction: the only scanner-like hotkey found in source is `Ctrl+Alt+S`, and it is Advisor-oriented. `Ctrl+Alt+K` is a current-lead CRM activity workflow.

## 3. Ctrl+Alt+H workflow trace from source

1. Hotkey binding: `hotkeys/crm_hotkeys.ahk:7` maps `^!h` to `RunCrmAttemptedContactForLatestBatchOkLeads()`.
2. Entry function: `adapters/crm_adapter.ahk:322`.
3. Run-state start: calls `BeginAutomationRun()` from `adapters/clipboard_adapter.ahk:1`, which clears `StopFlag` and writes `lastAction=automation-begin` through `PersistRunState()`.
4. Input list: calls `LoadLatestBatchOkLeadNames()` from `workflows/batch_run.ahk:26`; it reads `logs/latest_batch_ok_leads.txt` and returns non-empty trimmed lines as names.
5. Clipboard/parser use: `Ctrl+Alt+H` itself does not parse clipboard lead data. The OK list is produced earlier by `RunBatchFromClipboard()` in `workflows/batch_run.ahk:77`, which parses the clipboard with `BuildBatchLeadHolder(raw)` and writes successful lead names through `WriteLatestBatchOkLeadNames()` at `workflows/batch_run.ahk:45`.
6. Browser targeting: calls `FocusWorkBrowser()` from `adapters/browser_focus_adapter.ahk:19`; it activates Chrome first, then Edge. It verifies process/window focus, not exact tab or URL.
7. DevTools/JS usage: calls `JS_DevToolsBridgeProbe()` at `adapters/devtools_bridge.ahk:274`, then other JS wrappers. The generic bridge loads `assets/js/devtools_bridge/ops_result.js`, renders `@@OP@@` and `@@ARGS@@`, pastes into DevTools Console, sends Enter, and waits for `copy(String(...))` to update the clipboard.
8. Current lead detection: `GetCurrentBlitzLeadName()` at `adapters/crm_adapter.ahk:253` calls `JS_GetBlitzCurrentLeadTitle()`. The JS op `get_blitz_current_lead_title` at `assets/js/devtools_bridge/ops_result.js:94` searches accessible documents for a lead-log marker and returns `document.title`.
9. Lead-list fallback: if current lead is blank, `BlitzOpenLeadLogByName()` at `adapters/crm_adapter.ahk:315` calls `open_blitz_lead_log_by_name`. The JS op at `assets/js/devtools_bridge/ops_result.js:114` searches lead-log anchors (`a[id*='lnkProspectLog']`, `a[title='View Lead Log']`) and matches row text to a target name.
10. Matching cursor: `FindBlitzLeadNameIndex()` at `adapters/crm_adapter.ahk:263` maps current lead name into the saved OK list.
11. Per-lead update: `CrmRunAttemptedContactAppointment()` at `adapters/crm_adapter.ahk:148` performs the activity sequence.
12. Activity sequence: focus action dropdown via JS, send `l`, tab/choose values, paste attempted-contact note from templates, save history, add appointment, focus date/time field, paste configured follow-up date, save appointment.
13. Next lead loop: `BlitzGoToNextLead()` at `adapters/crm_adapter.ahk:308` calls JS op `click_blitz_next_lead` and waits for title change with `WaitForBlitzLeadChange()` at `adapters/crm_adapter.ahk:275`.
14. Success criteria: loop reaches the end of the saved OK list; MsgBox reports processed count and matched leads.
15. Failure criteria: missing OK list, browser not found, DevTools probe failure, cannot detect/open first lead, cannot read current lead name, attempted-contact failure, or cannot move to next lead.

The workflow has no Blitz status scanner, no URL validation, and no structured page-state object before it mutates the current page.

## 4. Ctrl+Alt+K workflow/scanner trace from source

`Ctrl+Alt+K` is not a scanner in current source.

1. Hotkey binding: `hotkeys/crm_hotkeys.ahk:5` maps `^!k` to `RunCrmAttemptedContactWorkflow()`.
2. Entry function: `workflows/crm_activity.ahk:28`.
3. Inputs: reads the attempted-contact note from templates and builds the last configured follow-up date.
4. Browser targeting: `FocusWorkBrowser()` activates Chrome or Edge.
5. Run-state start: `BeginAutomationRun()`.
6. Action: calls `CrmRunAttemptedContactAppointment()` at `adapters/crm_adapter.ahk:148`.
7. Scanner usage: none found.
8. Output: mutates the current Blitz/CRM lead log by adding/saving attempted-contact activity and appointment.

`Ctrl+Alt+K` can be useful as a smaller reproduction of the CRM activity sequence because it exercises the same action dropdown/history/appointment selectors as `Ctrl+Alt+H`. It does not capture fields/buttons/page text or save scan output.

The scanner hotkey actually present is `Ctrl+Alt+S` in `hotkeys/debug_hotkeys.ahk:114`, which calls `AdvisorQuoteScanCurrentPage()` at `workflows/advisor_quote_workflow.ahk:3263`. That scanner is tied to the Advisor quote JS operator (`scan_current_page`), not the Blitz CRM bridge.

## 5. Blitz page model

Current source knows these Blitz/CRM page areas:

| Page area | Selectors/evidence | Current code path | Risk |
| --- | --- | --- | --- |
| Lead list | `a[id*='lnkProspectLog']`, `a[title='View Lead Log']`; target name in anchor text or closest row text | `open_blitz_lead_log_by_name`, `assets/js/devtools_bridge/ops_result.js:114` | Medium/high: assumes link IDs/title and row text contain normalized lead name |
| Open lead log identity | document with `a#ctl00_ContentPlaceHolder1_lnkNext` or `ctl00_ContentPlaceHolder1_DDLogType_Input`; lead name in `document.title` | `get_blitz_current_lead_title`, `assets/js/devtools_bridge/ops_result.js:94` | High: if title format changes or iframe title is blank, current lead detection fails |
| Next lead navigation | `a#ctl00_ContentPlaceHolder1_lnkNext` visible | `click_blitz_next_lead`, `assets/js/devtools_bridge/ops_result.js:103` | Medium: exact legacy ID only |
| Activity dropdown | first iframe, `ctl00_ContentPlaceHolder1_DDLogType_Input` | `focus_action_dropdown`, `assets/js/devtools_bridge/ops_result.js:51` | High: `getFrameDoc()` only uses the first iframe |
| History save | first iframe, `ctl00_ContentPlaceHolder1_btnUpdate_input` | `save_history_note`, `assets/js/devtools_bridge/ops_result.js:58` | High: exact legacy ID and first iframe |
| Add appointment | first iframe, function `AppointmentInserting()` or `a.js-Lead-Log-Add-New-Appointment` | `add_new_appointment`, `assets/js/devtools_bridge/ops_result.js:65` | Medium: has a function fallback and selector fallback |
| Appointment date/time | nested first iframe inside first iframe, `ctl00_ContentPlaceHolder1_RadDateTimePicker1_dateInput` | `focus_date_time_field`, `assets/js/devtools_bridge/ops_result.js:77` | High: assumes nested iframe ordering |
| Appointment final save | nested first iframe inside first iframe, `ctl00_ContentPlaceHolder1_lnkSave_input` | `save_appointment`, `assets/js/devtools_bridge/ops_result.js:86` | High: exact legacy ID and nested iframe ordering |
| Phone/iPhone/mobile fields | no selector found in `Ctrl+Alt+H` path | none | Unknown: source does not currently update these fields in `Ctrl+Alt+H` |

The code has iframe awareness in two different styles: `walkDocs()` for title/next/open-lead-list, and `getFrameDoc()`/first nested iframe for CRM activity controls. The latter is more fragile.

## 6. Existing scan/log evidence

Relevant runtime evidence found:

- `logs/js_asset_errors.log`: recent entries at `2026-04-30 00:37` and `00:38` show `RunDevToolsJSInternal` empty result retries in `mode=work`. This is directly relevant to `Ctrl+Alt+H`/`Ctrl+Alt+K` because they use the generic work-browser DevTools bridge.
- `logs/run_state.json`: current/latest run state showed `lastAction=advisor-quote-stop` after a stop; earlier source inspection found `automation-begin` after `Ctrl+Alt+H` attempts. This can prove a hotkey reached `BeginAutomationRun()`, but it does not identify Blitz page state.
- `logs/latest_batch_ok_leads.txt`: exists and is the name-only input for `Ctrl+Alt+H`. It contains real lead names; content not reproduced here.
- `logs/batch_lead_log.csv`: exists and records batch outcomes with PII; useful to know which leads were OK, but not a DOM/page-shape source. Content not reproduced here.
- `logs/advisor_scans/*` and `logs/advisor_scan_latest.json`: many Advisor Pro scan bundles exist. They are useful for Advisor quote flow, not for Blitz lead-log DOM.

No useful Blitz-specific scan/status JSON was found. There is no current source-backed `scan_current_blitz_page` equivalent.

Needed next evidence:

- sanitized Blitz lead list scan with lead-log links visible
- sanitized open Blitz lead log scan with action dropdown, Next link, history save, add appointment
- sanitized appointment modal/frame scan showing date/time field and final save
- if the intended "auto-update leads" includes phone/iPhone/mobile/status fields, a scan of that edit panel with those fields visible

## 7. Failure mode analysis

| Failure mode | Evidence level | Notes |
| --- | --- | --- |
| Hotkey not firing | Low | `^!h` is bound once; run-state can show `automation-begin` when it fires. |
| Wrong active window/focus | Medium/high | `FocusWorkBrowser()` only activates Chrome/Edge, not a specific Blitz tab. |
| Wrong browser tab/app | High | No URL/title/page-status check before DevTools injection or mutation. |
| Clipboard/lead input missing | Medium | If `latest_batch_ok_leads.txt` is absent/empty, workflow stops. |
| Lead parser mismatch | Low for `Ctrl+Alt+H` | `Ctrl+Alt+H` uses saved names, not live clipboard parsing. Earlier batch parsing can still affect the saved list. |
| Blitz page not ready | High | No readiness/status op before activity mutation. |
| Blitz selector drift | High | Exact legacy IDs and iframe positions are assumed. |
| Phone/iPhone field not found | Unknown | `Ctrl+Alt+H` does not currently target these fields. If this is expected behavior, the workflow is missing that capability. |
| Update/save button not found | Medium/high | History and appointment save use exact IDs; failures return false/blank but logs are sparse. |
| Page state not recognized | High | Current lead identity depends on document title and specific markers. |
| `Ctrl+Alt+H` stale while scanner works | Medium | There is no Blitz scanner to compare against; Advisor scanner is unrelated. |
| Timing/race condition | Medium | Sleeps are fixed; waits exist for current lead title changes but not for all controls. |
| DevTools/clipboard bridge issue | High | `logs/js_asset_errors.log` shows empty console-copy results. |
| Unknown / needs live scan | High | No Blitz DOM scans found. |

## 8. Relationship between Ctrl+Alt+H and Ctrl+Alt+K

- `Ctrl+Alt+H` does not reuse scanner logic from `Ctrl+Alt+K`.
- `Ctrl+Alt+K` is not scanner logic in current source; it is a current-lead attempted-contact workflow.
- `Ctrl+Alt+H` and `Ctrl+Alt+K` share `CrmRunAttemptedContactAppointment()` and the same CRM/Blitz JS operators for dropdown/save/appointment.
- `Ctrl+Alt+H` adds saved-list loading, lead detection/opening, cursor matching, and Next traversal.
- A Blitz scanner/status object would help both workflows. `Ctrl+Alt+H` should call it before opening/updating/traversing; `Ctrl+Alt+K` should call it before mutating the current page.

## 9. Recommended architecture

Recommended pattern:

1. Detect current Blitz page/state.
2. Verify active browser/tab is a Blitz page before DevTools mutation.
3. Verify required controls exist for the intended action.
4. Update only when confidence is high.
5. Return structured status with explicit missing controls.
6. Log precise failure reason.
7. Capture a sanitized scan/status payload when confidence is low.
8. Avoid blind tabs/typing unless the field/control identity has been verified.

Future status op shape:

```text
result=READY|NOT_READY|WRONG_PAGE|MISSING_FIELD|ERROR
page=lead-list|lead-log|appointment-frame|unknown
hasLeadName=1|0
leadName=
hasNextLead=1|0
hasActionDropdown=1|0
hasHistorySave=1|0
hasAddAppointment=1|0
hasAppointmentDate=1|0
hasAppointmentSave=1|0
hasPhone=1|0
hasMobileOrIPhone=1|0
hasStatus=1|0
hasSaveButton=1|0
frameCount=
accessibleFrameCount=
evidence=
missing=
url=
title=
```

This should live in the CRM/Blitz JS operator (`assets/js/devtools_bridge/ops_result.js`) as a read-only op, with an AHK wrapper in `adapters/devtools_bridge.ahk`. Business decisions should remain in AHK.

## 10. Recommended patch phases

| Phase | Patch | Likely files | Risk | Tests/live validation |
| --- | --- | --- | --- | --- |
| 1 | Add read-only Blitz page/status scanner | `assets/js/devtools_bridge/ops_result.js`, `adapters/devtools_bridge.ahk`, docs | Low/medium | AHK toolchain; live Blitz lead list/log scan |
| 2 | Make `Ctrl+Alt+H` call status before replay | `adapters/crm_adapter.ahk` | Medium | Live `Ctrl+Alt+H` on lead list and open lead log |
| 3 | Make `Ctrl+Alt+K` call status before current-lead update | `workflows/crm_activity.ahk` or `adapters/crm_adapter.ahk` | Medium | Live current lead update |
| 4 | Fix selectors/iframe targeting from current scans | `assets/js/devtools_bridge/ops_result.js` | Medium/high | Live sanitized Blitz scans before/after |
| 5 | Add safe update/save behavior if phone/mobile/status update is required | TBD after scan | High | Requires exact field scans |
| 6 | Improve batch traversal diagnostics | `adapters/crm_adapter.ahk`, logs/run_state | Medium | Live partial replay and stop/retry |
| 7 | Add helper validation where practical | `tests/*` only if a testable helper is extracted | Low | AHK checker and any targeted helper tests |

## 11. Exact recommended next patch

Recommended next patch: add a read-only Blitz page/status scanner.

Reason: current failures can be DevTools bridge, wrong tab, lead list vs lead log mismatch, iframe selector drift, or missing controls. Patching `Ctrl+Alt+H` selectors directly without a current Blitz status payload would be guesswork. A status op gives a safe proof point before any mutation and can be reused by both `Ctrl+Alt+H` and `Ctrl+Alt+K`.

Do not replace the workflow yet. Add a read-only op first, then run it on:

- Blitz lead list
- open Blitz lead log
- appointment modal/frame
- any page containing phone/iPhone/mobile/status fields if that is part of the intended auto-update

## 12. Questions for Pablo

1. When you say `Ctrl+Alt+H` should "auto-update leads in Blitz," is the intended update only the attempted-contact CRM note/appointment, or should it also update phone/iPhone/mobile/status fields?
2. Is the correct live starting page for `Ctrl+Alt+H` usually the Blitz lead list, an already-open lead log, or either one?
3. Should the next patch treat `Ctrl+Alt+K` as the current-lead attempted-contact workflow, or is there another scanner hotkey/script outside this repo that you mean by `Ctrl+Alt+K`?

## 13. Implementation note: Blitz page status op

A read-only `blitz_page_status` op has been added to the CRM/Blitz DevTools operator. The live manual scan showed the top page can be a lead list while an accessible iframe contains an open lead-log context with the attempted-contact controls. The new status op preserves that mixed state as `page=lead-list-with-open-lead-log`, `topPage=lead-list`, `actionPage=lead-log`, and returns the `actionFramePath`.

Initial status-op implementation did not change `Ctrl+Alt+H` or `Ctrl+Alt+K`. Section 15 supersedes this note: both workflows now call the status op before mutation and fail closed on wrong-page or missing-control evidence.

Bridge-level return diagnostics are now logged to `logs/devtools_bridge_returns.log`. Collect that file after `Ctrl+Alt+H` or `Ctrl+Alt+K` failures; it records the CRM/Blitz op name, empty/stale/timeout flags, and a capped/redacted result preview without logging the full rendered JS.

## 14. Bridge probe stale-clipboard finding

Current evidence shows a `Ctrl+Alt+H` run failing at `bridge_probe` before Blitz workflow logic or Blitz selector code executed. The return log showed the clipboard after the attempt still matched the rendered JavaScript payload, so the script was placed on the clipboard but did not return through `copy(String(...))`.

That failure layer is DevTools Console submission/focus: the prompt may not have received the paste, Enter may not have submitted it, or focus may have landed in a DevTools filter/search/editor instead of the Console prompt. The next diagnosis after a repeat failure should use `logs/devtools_bridge_returns.log`, especially the `DEVTOOLS_BRIDGE_PROBE_FAILED_STALE`, `consoleSubmissionStale`, `panelFocusMethod`, and `submitMethod` fields. This evidence points to bridge execution before Blitz selector drift.

Follow-up bridge evidence showed `bridge_probe` reaching Console focus but not reaching submit: `consoleFocusAttempted=1`, `consoleSubmitAttempted=0`, and the clipboard still contained the rendered JavaScript. The bridge now focuses the Console before putting rendered JS on the clipboard and logs stop checkpoints around focus, paste, and submit. The current blocker remains generic DevTools bridge submission/stop handling, not Blitz selectors or `Ctrl+Alt+H` business logic.

## 15. Guarded attempted-contact architecture implemented

`Ctrl+Alt+K` is now the canonical guarded single-lead attempted-contact workflow. It starts a fresh automation run, verifies the DevTools bridge with `bridge_probe`, calls `blitz_page_status`, requires a ready lead-log action context, and then runs the existing attempted-contact sequence unchanged.

`Ctrl+Alt+H` is now a batch orchestrator over `logs/latest_batch_ok_leads.txt`. It loads the saved OK lead list, opens or matches the target Blitz lead, waits for a ready lead-log context, and calls the same shared single-lead engine for each target. It still means "replay attempted-contact CRM activity for latest-batch OK leads"; the business activity sequence and hotkey binding are unchanged.

The shared AHK engine is:

```text
CrmRunAttemptedContactAppointmentGuarded(noteText, dtText, context)
```

Ready mutation contexts:

- `page=lead-log`, `actionPage=lead-log`, `result=READY`
- `page=lead-list-with-open-lead-log`, `actionPage=lead-log`, `result=READY`

Required controls:

- `hasActionDropdown=1`
- `hasHistorySave=1`
- `hasAddAppointment=1`

`lead-list` alone is now used only to find/open leads. It is not accepted as a mutation context unless an open lead-log iframe is present.

CRM/Blitz DevTools action ops now find controls across accessible top/frame documents by their known targets rather than assuming the first iframe. Existing return strings are preserved.

New CRM/Blitz workflow diagnostics are written to:

```text
logs/crm_blitz_workflow.log
```

Collect this alongside `logs/devtools_bridge_returns.log`, `logs/js_asset_errors.log`, and `logs/run_state.json` after `Ctrl+Alt+H` or `Ctrl+Alt+K` failures.

## 16. DevTools bridge Esc-stop fix

Bridge regression evidence showed `bridge_probe` failing before Blitz-specific selectors ran. The failure coincided with `manual-esc` stop entries because the generic DevTools bridge sent a bare `Esc` while preparing the Console prompt, and `Esc::` is the global emergency-stop hotkey.

The bridge prompt-prep path no longer sends bare `Esc`. Human Esc stop remains unchanged. Blitz selectors, iframe detection, lead matching, and attempted-contact business behavior were not changed in this patch.

After a live Ctrl+Alt+H or Ctrl+Alt+K attempt, `logs/devtools_bridge_returns.log` should be checked first. For a healthy `bridge_probe`, expect `consolePrepSucceeded=1`, `consolePasteAttempted=1`, `consoleSubmitAttempted=1`, `submitMethod=enter`, and `rootCauseHint=ok`.
