# DevTools Bridge Return Logging

## Purpose

The generic DevTools bridge is clipboard-backed: AHK pastes rendered JavaScript into the browser DevTools Console and expects the script to return through `copy(String(...))`.

`logs/devtools_bridge_returns.log` records what AHK receives at that bridge boundary. The log is diagnostic, while the bridge submission path itself now fails closed with explicit focus/paste/submit/stop evidence. JS operator output and the `copy(String(...))` return contract are unchanged.

## Log Path

```text
logs/devtools_bridge_returns.log
```

## Logged Fields

Each console execution attempt writes one compact line with:

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
- `staleRenderedClipboard`
- `rootCauseHint`
- `consoleFocusAttempted`
- `focusSucceeded`
- `consolePrepMethod`
- `consolePrepSucceeded`
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
- `stoppedBeforeConsolePrep`
- `stoppedDuringConsolePrep`
- `stoppedBeforeClipboard`
- `stoppedAfterClipboardBeforePaste`
- `stoppedAfterPasteBeforeSubmit`
- `stoppedBeforeSubmit`
- `stoppedWhileWaiting`
- `internalEscSuppressed`
- `timeout`
- `error`

`assetPath` and `op` are populated when calls go through `RunDevToolsJsAssetWork()` or `RunDevToolsJsAssetEdge()`. This includes CRM/Blitz ops such as:

- `bridge_probe`
- `blitz_page_status`
- `get_blitz_current_lead_title`
- `open_blitz_lead_log_by_name`
- `focus_action_dropdown`
- `save_history_note`
- `add_new_appointment`
- `focus_date_time_field`
- `save_appointment`
- `click_blitz_next_lead`

## Event Values

- `DEVTOOLS_RETURN_OK`: non-empty return observed and no error shape detected.
- `DEVTOOLS_RETURN_EMPTY`: return was empty without a stronger stale/timeout signal.
- `DEVTOOLS_RETURN_STALE`: clipboard after execution still matched the rendered JS or pre-call clipboard text.
- `DEVTOOLS_CONSOLE_SUBMISSION_STALE`: AHK pasted/submitted rendered JS, but the clipboard still matched that rendered JS afterward. This points to Console focus/submission failure before the JS operator returned.
- `DEVTOOLS_BRIDGE_PROBE_FAILED_STALE`: the stale rendered-JS condition happened for `bridge_probe`. The workflow should stop before Blitz mutation ops because the bridge itself did not prove execution.
- `DEVTOOLS_RETURN_STOPPED_BEFORE_CONSOLE_PREP`: a stop request was already active before Console prompt preparation.
- `DEVTOOLS_RETURN_STOPPED_DURING_CONSOLE_PREP`: a stop request happened while preparing the Console prompt.
- `DEVTOOLS_RETURN_STOPPED_BEFORE_CLIPBOARD`: a stop request happened before rendered JS was placed on the clipboard.
- `DEVTOOLS_RETURN_STOPPED_AFTER_CLIPBOARD_BEFORE_PASTE`: a stop request happened after clipboard setup but before paste.
- `DEVTOOLS_RETURN_STOPPED_AFTER_PASTE_BEFORE_SUBMIT`: a stop request happened after paste but before Enter.
- `DEVTOOLS_RETURN_STOPPED_BEFORE_SUBMIT`: a stop request interrupted the bridge before the rendered JS was submitted.
- `DEVTOOLS_RETURN_STOPPED_WAITING_RESULT`: the rendered JS was submitted, but a stop request interrupted result wait, console close, or browser refocus.
- `DEVTOOLS_RETURN_TIMEOUT`: AHK timed out waiting for clipboard set/result change or an action wait was interrupted.
- `DEVTOOLS_RETURN_ERROR_PAYLOAD`: return looked like a JS error payload, such as `result=ERROR`.

## Empty, Stale, And Timeout Interpretation

An empty result means AHK did not receive a usable value from the console attempt.

Stale is suspected when the clipboard after execution still matches the rendered JS payload or the pre-call clipboard text. This usually means the operator did not run, `copy(String(...))` did not execute, or DevTools was not accepting input where AHK expected.

When `clipboardAfterHash` and `clipboardAfterLength` match the rendered JS hash/length, the rendered operator stayed on the clipboard. For `bridge_probe`, that is now logged as `DEVTOOLS_BRIDGE_PROBE_FAILED_STALE`. This is a bridge submission/focus failure signal, not evidence that Blitz selectors failed.

`staleRenderedClipboard=1` means `clipboardAfter` exactly matched the rendered JS that AHK tried to submit. Read `rootCauseHint` next:

- `submit-not-attempted`: the rendered JS was put on the clipboard, but the bridge did not reach Enter.
- `stopped-before-submit`: a real stop checkpoint interrupted the bridge before submit.
- `copy-result-not-received`: Enter was sent, but the expected `copy(String(...))` result did not replace the rendered JS.

If `consoleSubmitAttempted=0`, the bridge did not reach the Enter/submit step. Check `stoppedBeforeSubmit`, `stopRequestedBeforeFocus`, `stopRequestedBeforePaste`, `stopRequestedBeforeSubmit`, and `error` first. A stop before submit is now labeled explicitly instead of being treated as a normal empty return.

The bridge focuses the Console before placing rendered JS on the clipboard. That prevents a stop request during focus from leaving the rendered operator on the clipboard without a submit attempt.

## Console Prep And Esc Stop

Earlier bridge evidence showed `bridge_probe` aborting during Console prompt prep while `logs/advisor_quote_trace.log` recorded `manual-esc` at matching timestamps. The bridge previously sent a bare `Esc` while preparing the DevTools Console prompt, but `Esc::` is also the global emergency-stop hotkey.

Current bridge prompt prep no longer sends bare `Esc`. It uses `consolePrepMethod=settle-without-esc`, waits briefly for the prompt after `Ctrl+Shift+J`, then lets the caller clear the prompt with `Ctrl+A`. Human Esc stop remains unchanged because the global hotkey was not disabled or guarded.

`internalEscSuppressed=0` is expected for the current implementation. If a future patch reintroduces a guarded internal Escape, that field should identify when the guard was active.

For live bridge-probe validation, the healthy path should show:

- `op=bridge_probe`
- `event=DEVTOOLS_RETURN_OK`
- `consolePrepSucceeded=1`
- `consolePasteAttempted=1`
- `consoleSubmitAttempted=1`
- `submitMethod=enter`
- `rootCauseHint=ok`

Timeout means one of the bounded waits expired or was interrupted before a return was observed.

`possiblePasteProtection=1` is only a diagnostic hint based on visible text patterns such as `allow pasting`; the bridge does not automatically type `allow pasting`.

After a stale bridge-probe failure, collect:

- `logs/devtools_bridge_returns.log`
- `logs/js_asset_errors.log`, if present
- `logs/run_state.json`, if present
- a screenshot or note of whether DevTools is open to Console and whether the prompt is focused

## Redaction And Capping

The log never writes the full rendered JS script.

`resultPreview` is capped and redacted:

- capped to about 1200 characters
- email-like tokens become `[email]`
- phone-like tokens become `[phone]`
- SSN-like tokens become `[ssn]`
- long id-like tokens become `[id]`
- newlines are escaped/collapsed

Clipboard hashes are simple diagnostic checksums, not cryptographic hashes. They are only meant to compare whether values changed across a bridge attempt.

## Behavior Status

The bridge submission hardening changes only how rendered JS is delivered to DevTools and how failures are diagnosed.

- `Ctrl+Alt+H` business meaning is unchanged.
- `Ctrl+Alt+K` business meaning is unchanged.
- CRM activity sequence is unchanged.
- JS op return formats are unchanged.
- Clipboard restore behavior is unchanged.
