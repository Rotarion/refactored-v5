RunDevToolsJS(jsCode, context := "") {
    result := RunDevToolsJSInternal(jsCode, "work", false, context)
    return result = true
}

RunDevToolsJSGetResult(jsCode, context := "") {
    result := RunDevToolsJSInternal(jsCode, "work", true, context)
    return (Type(result) = "String") ? result : ""
}

RunDevToolsJSEdge(jsCode, context := "") {
    result := RunDevToolsJSInternal(jsCode, "edge", false, context)
    return result = true
}

RunDevToolsJSGetResultEdge(jsCode, context := "") {
    result := RunDevToolsJSInternal(jsCode, "edge", true, context)
    return (Type(result) = "String") ? result : ""
}

RunDevToolsJSInternal(jsCode, mode := "work", expectResult := false, context := "") {
    attempts := expectResult ? 2 : 1
    Loop attempts {
        result := RunDevToolsJSInternalOnce(jsCode, mode, expectResult, context, A_Index)
        if !expectResult
            return result
        if (Trim(String(result ?? "")) != "")
            return result
        if (A_Index < attempts) {
            LogJsAssetFailure("RunDevToolsJSInternal", "Empty result; retrying console injection. mode=" mode)
            if !SafeSleep(250)
                return ""
        }
    }
    LogJsAssetFailure("RunDevToolsJSInternal", "Empty result after retry. mode=" mode)
    return ""
}

RunDevToolsJSInternalOnce(jsCode, mode := "work", expectResult := false, context := "", attempt := 1) {
    startTick := A_TickCount
    clipboardBefore := A_Clipboard
    clipboardAfter := ""
    sentCode := ""
    result := expectResult ? "" : false
    timeout := false
    errorMessage := ""
    consoleFocusAttempted := false
    focusSucceeded := "0"
    consolePasteAttempted := false
    consolePasteSucceeded := "0"
    consoleSubmitAttempted := false
    panelFocusMethod := ""
    submitMethod := ""
    stopRequestedBeforeFocus := false
    stopRequestedBeforePaste := false
    stopRequestedBeforeSubmit := false
    stoppedBeforeSubmit := false
    stoppedWhileWaiting := false
    stoppedBeforeConsolePrep := false
    stoppedDuringConsolePrep := false
    stoppedBeforeClipboard := false
    stoppedAfterClipboardBeforePaste := false
    stoppedAfterPasteBeforeSubmit := false
    internalEscSuppressed := false
    consolePrepMethod := ""
    consolePrepSucceeded := "0"
    savedClipCaptured := false
    savedClip := ""

    try {
        if StopRequested() {
            stopRequestedBeforeFocus := true
            stoppedBeforeSubmit := true
            stoppedBeforeConsolePrep := true
            errorMessage := "stop-requested-before-focus"
            return result
        }

        if !DevToolsFocusByMode(mode) {
            errorMessage := "browser-focus-failed"
            return result
        }

        if StopRequested() {
            stopRequestedBeforeFocus := true
            stoppedBeforeSubmit := true
            stoppedBeforeConsolePrep := true
            errorMessage := "stop-requested-before-console-open"
            return result
        }
        Send "^+j"
        if !SafeSleep(2000) {
            stopRequestedBeforeFocus := StopRequested()
            stoppedBeforeSubmit := stopRequestedBeforeFocus
            stoppedBeforeConsolePrep := stopRequestedBeforeFocus
            errorMessage := "console-open-wait-interrupted"
            return result
        }

        consoleFocusAttempted := true
        panelFocusMethod := "ctrl-shift-j|no-esc"
        consolePrepMethod := "settle-without-esc"
        if !DevToolsBridgePrepareConsolePrompt() {
            stopRequestedBeforeFocus := StopRequested()
            stoppedBeforeSubmit := stopRequestedBeforeFocus
            stoppedDuringConsolePrep := stopRequestedBeforeFocus
            errorMessage := stopRequestedBeforeFocus ? "console-prompt-prep-stopped" : "console-prompt-prep-failed"
            return result
        }
        focusSucceeded := "1"
        consolePrepSucceeded := "1"

        savedClip := ClipboardAll()
        savedClipCaptured := true

        if StopRequested() {
            stopRequestedBeforePaste := true
            stoppedBeforeSubmit := true
            stoppedBeforeClipboard := true
            errorMessage := "stop-requested-before-console-select"
            return result
        }
        Send "^a"
        if !SafeSleep(80) {
            stopRequestedBeforePaste := StopRequested()
            stoppedBeforeSubmit := stopRequestedBeforePaste
            stoppedBeforeClipboard := stopRequestedBeforePaste
            errorMessage := "console-select-wait-interrupted"
            return result
        }

        if StopRequested() {
            stopRequestedBeforePaste := true
            stoppedBeforeSubmit := true
            stoppedBeforeClipboard := true
            errorMessage := "stop-requested-before-js-clipboard"
            return result
        }
        A_Clipboard := ""
        if !SafeSleep(30) {
            stopRequestedBeforePaste := StopRequested()
            stoppedBeforeSubmit := stopRequestedBeforePaste
            stoppedBeforeClipboard := stopRequestedBeforePaste
            errorMessage := "sleep-interrupted-before-js-clipboard"
            return result
        }
        if StopRequested() {
            stopRequestedBeforePaste := true
            stoppedBeforeSubmit := true
            stoppedBeforeClipboard := true
            errorMessage := "stop-requested-before-js-clipboard"
            return result
        }
        A_Clipboard := jsCode
        if !WaitForClip(1000) {
            timeout := true
            stopRequestedBeforePaste := StopRequested()
            stoppedBeforeSubmit := stopRequestedBeforePaste
            stoppedBeforeClipboard := stopRequestedBeforePaste
            errorMessage := stoppedBeforeSubmit ? "stop-requested-before-js-clipboard-ready" : "js-clipboard-set-timeout"
            return result
        }

        sentCode := A_Clipboard

        if StopRequested() {
            stopRequestedBeforeSubmit := true
            stoppedBeforeSubmit := true
            stoppedAfterClipboardBeforePaste := true
            errorMessage := "stop-requested-before-console-paste"
            return result
        }
        consolePasteAttempted := true
        Send "^v"
        if !SafeSleep(120) {
            stopRequestedBeforeSubmit := StopRequested()
            stoppedBeforeSubmit := stopRequestedBeforeSubmit
            stoppedAfterClipboardBeforePaste := stopRequestedBeforeSubmit
            consolePasteSucceeded := stoppedBeforeSubmit ? "unknown" : "0"
            errorMessage := "console-paste-wait-interrupted"
            return result
        }
        consolePasteSucceeded := "unknown"
        if StopRequested() {
            stopRequestedBeforeSubmit := true
            stoppedBeforeSubmit := true
            stoppedAfterPasteBeforeSubmit := true
            errorMessage := "stop-requested-before-console-enter"
            return result
        }
        consoleSubmitAttempted := true
        submitMethod := "enter"
        Send "{Enter}"
        if !SafeSleep(expectResult ? 300 : 180) {
            stoppedWhileWaiting := StopRequested()
            errorMessage := "console-enter-wait-interrupted"
            return result
        }

        if expectResult {
            result := ""
            Loop 25 {
                if !SafeSleep(100) {
                    stoppedWhileWaiting := StopRequested()
                    errorMessage := "result-wait-interrupted"
                    return ""
                }
                clipboardAfter := A_Clipboard
                if (A_Clipboard != sentCode && Trim(A_Clipboard) != "") {
                    result := Trim(A_Clipboard)
                    break
                }
            }
            if (result = "") {
                timeout := true
                clipboardAfter := A_Clipboard
            }

            if StopRequested() {
                stoppedWhileWaiting := true
                errorMessage := "stop-requested-before-console-close"
                return ""
            }
            Send "^+j"
            if !SafeSleep(220) {
                stoppedWhileWaiting := StopRequested()
                errorMessage := "console-close-wait-interrupted"
                return ""
            }
            DevToolsFocusByMode(mode)
            if !SafeSleep(150) {
                stoppedWhileWaiting := StopRequested()
                errorMessage := "browser-refocus-wait-interrupted"
                return ""
            }
            return result
        }

        if StopRequested() {
            stoppedWhileWaiting := true
            errorMessage := "stop-requested-before-console-close"
            return false
        }
        Send "^+j"
        if !SafeSleep(180) {
            stoppedWhileWaiting := StopRequested()
            errorMessage := "console-close-wait-interrupted"
            return false
        }
        clipboardAfter := A_Clipboard
        result := true
        return true
    } catch Error as err {
        errorMessage := err.Message
        result := expectResult ? "" : false
        return result
    } finally {
        if (clipboardAfter = "")
            clipboardAfter := A_Clipboard
        DevToolsBridgeLogReturn(mode, context, attempt, A_TickCount - startTick, StrLen(String(jsCode ?? "")), result, expectResult, clipboardBefore, clipboardAfter, sentCode, timeout, errorMessage, consoleFocusAttempted, focusSucceeded, consolePasteAttempted, consolePasteSucceeded, consoleSubmitAttempted, panelFocusMethod, submitMethod, stopRequestedBeforeFocus, stopRequestedBeforePaste, stopRequestedBeforeSubmit, stoppedBeforeSubmit, stoppedWhileWaiting, stoppedBeforeConsolePrep, stoppedDuringConsolePrep, stoppedBeforeClipboard, stoppedAfterClipboardBeforePaste, stoppedAfterPasteBeforeSubmit, internalEscSuppressed, consolePrepMethod, consolePrepSucceeded)
        if savedClipCaptured
            A_Clipboard := savedClip
    }
}

DevToolsBridgePrepareConsolePrompt() {
    if StopRequested()
        return false
    ; Do not send Esc here: Esc is the global emergency-stop hotkey.
    ; DevTools is expected to focus the Console prompt after Ctrl+Shift+J; the
    ; following Ctrl+A in the caller clears the prompt without invoking stop.
    return SafeSleep(80)
}

DevToolsBridgeContext(assetPath := "", params := "") {
    context := Map("assetPath", assetPath, "op", "", "caller", "")
    if IsObject(params) {
        if params.Has("OP")
            context["op"] := String(params["OP"])
        if params.Has("CALLER")
            context["caller"] := String(params["CALLER"])
    }
    return context
}

DevToolsBridgeLogReturn(mode, context, attempt, elapsedMs, renderedLength, result, expectResult, clipboardBefore, clipboardAfter, sentCode, timeout, errorMessage := "", consoleFocusAttempted := false, focusSucceeded := "unknown", consolePasteAttempted := false, consolePasteSucceeded := "unknown", consoleSubmitAttempted := false, panelFocusMethod := "", submitMethod := "", stopRequestedBeforeFocus := false, stopRequestedBeforePaste := false, stopRequestedBeforeSubmit := false, stoppedBeforeSubmit := false, stoppedWhileWaiting := false, stoppedBeforeConsolePrep := false, stoppedDuringConsolePrep := false, stoppedBeforeClipboard := false, stoppedAfterClipboardBeforePaste := false, stoppedAfterPasteBeforeSubmit := false, internalEscSuppressed := false, consolePrepMethod := "", consolePrepSucceeded := "unknown") {
    global logsRoot

    assetPath := ""
    opName := ""
    caller := ""
    if IsObject(context) {
        if context.Has("assetPath")
            assetPath := context["assetPath"]
        if context.Has("op")
            opName := context["op"]
        if context.Has("caller")
            caller := context["caller"]
    }

    resultText := expectResult ? String(result ?? "") : ((result = true) ? "true" : "false")
    resultEmpty := expectResult ? (Trim(resultText) = "") : false
    resultLooksError := RegExMatch(resultText, "im)^\s*result=ERROR\b|^\s*(?:Error|TypeError|ReferenceError|SyntaxError)\b") ? true : false
    resultLooksKeyValue := RegExMatch(resultText, "m)^\s*[A-Za-z][A-Za-z0-9_]*=") ? true : false
    staleRenderedClipboard := expectResult && (sentCode != "") && (clipboardAfter = sentCode)
    staleClipboardSuspected := expectResult && (sentCode != "") && (staleRenderedClipboard || (clipboardBefore != "" && clipboardAfter = clipboardBefore))
    consoleSubmissionStale := expectResult && consoleSubmitAttempted && staleRenderedClipboard
    consolePasteFailed := consolePasteAttempted && (String(consolePasteSucceeded) = "0")
    probeFailedStale := consoleSubmissionStale && (opName = "bridge_probe")
    possiblePasteProtection := RegExMatch(String(resultText . "`n" . clipboardAfter), "i)allow\s+pasting|paste\s+protection") ? true : false
    if stoppedBeforeConsolePrep
        event := "DEVTOOLS_RETURN_STOPPED_BEFORE_CONSOLE_PREP"
    else if stoppedDuringConsolePrep
        event := "DEVTOOLS_RETURN_STOPPED_DURING_CONSOLE_PREP"
    else if stoppedBeforeClipboard
        event := "DEVTOOLS_RETURN_STOPPED_BEFORE_CLIPBOARD"
    else if stoppedAfterClipboardBeforePaste
        event := "DEVTOOLS_RETURN_STOPPED_AFTER_CLIPBOARD_BEFORE_PASTE"
    else if stoppedAfterPasteBeforeSubmit
        event := "DEVTOOLS_RETURN_STOPPED_AFTER_PASTE_BEFORE_SUBMIT"
    else if stoppedBeforeSubmit
        event := "DEVTOOLS_RETURN_STOPPED_BEFORE_SUBMIT"
    else if stoppedWhileWaiting
        event := "DEVTOOLS_RETURN_STOPPED_WAITING_RESULT"
    else if probeFailedStale
        event := "DEVTOOLS_BRIDGE_PROBE_FAILED_STALE"
    else if consoleSubmissionStale
        event := "DEVTOOLS_CONSOLE_SUBMISSION_STALE"
    else if timeout
        event := "DEVTOOLS_RETURN_TIMEOUT"
    else if staleClipboardSuspected
        event := "DEVTOOLS_RETURN_STALE"
    else if resultLooksError
        event := "DEVTOOLS_RETURN_ERROR_PAYLOAD"
    else if resultEmpty
        event := "DEVTOOLS_RETURN_EMPTY"
    else
        event := "DEVTOOLS_RETURN_OK"

    if stoppedBeforeSubmit
        rootCauseHint := "stopped-before-submit"
    else if staleRenderedClipboard && !consoleSubmitAttempted
        rootCauseHint := "submit-not-attempted"
    else if staleRenderedClipboard && consoleSubmitAttempted
        rootCauseHint := "copy-result-not-received"
    else if stoppedWhileWaiting
        rootCauseHint := "stopped-while-waiting"
    else if timeout
        rootCauseHint := "timeout"
    else if resultLooksError
        rootCauseHint := "error-payload"
    else if resultEmpty
        rootCauseHint := "empty-result"
    else
        rootCauseHint := "ok"

    fields := [
        "timestamp=" FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
        "event=" event,
        "mode=" DevToolsBridgeLogValue(mode),
        "assetPath=" DevToolsBridgeLogValue(assetPath),
        "op=" DevToolsBridgeLogValue(opName),
        "caller=" DevToolsBridgeLogValue(caller),
        "attempt=" attempt,
        "elapsedMs=" elapsedMs,
        "renderedLength=" renderedLength,
        "resultLength=" StrLen(resultText),
        "resultEmpty=" (resultEmpty ? "1" : "0"),
        "resultLooksError=" (resultLooksError ? "1" : "0"),
        "resultLooksKeyValue=" (resultLooksKeyValue ? "1" : "0"),
        "resultPreview=" DevToolsBridgeLogValue(DevToolsBridgeRedact(resultText, 1200)),
        "clipboardBeforeLength=" StrLen(String(clipboardBefore ?? "")),
        "clipboardBeforeHash=" DevToolsBridgeTextHash(clipboardBefore),
        "clipboardAfterLength=" StrLen(String(clipboardAfter ?? "")),
        "clipboardAfterHash=" DevToolsBridgeTextHash(clipboardAfter),
        "staleClipboardSuspected=" (staleClipboardSuspected ? "1" : "0"),
        "staleRenderedClipboard=" (staleRenderedClipboard ? "1" : "0"),
        "rootCauseHint=" DevToolsBridgeLogValue(rootCauseHint),
        "consoleFocusAttempted=" (consoleFocusAttempted ? "1" : "0"),
        "focusSucceeded=" DevToolsBridgeLogValue(focusSucceeded),
        "consolePrepMethod=" DevToolsBridgeLogValue(consolePrepMethod),
        "consolePrepSucceeded=" DevToolsBridgeLogValue(consolePrepSucceeded),
        "consolePasteAttempted=" (consolePasteAttempted ? "1" : "0"),
        "consolePasteSucceeded=" DevToolsBridgeLogValue(consolePasteSucceeded),
        "consolePasteFailed=" (consolePasteFailed ? "1" : "0"),
        "consoleSubmitAttempted=" (consoleSubmitAttempted ? "1" : "0"),
        "consoleSubmissionStale=" (consoleSubmissionStale ? "1" : "0"),
        "probeFailedStale=" (probeFailedStale ? "1" : "0"),
        "panelFocusMethod=" DevToolsBridgeLogValue(panelFocusMethod),
        "submitMethod=" DevToolsBridgeLogValue(submitMethod),
        "possiblePasteProtection=" (possiblePasteProtection ? "1" : "0"),
        "stopRequestedBeforeFocus=" (stopRequestedBeforeFocus ? "1" : "0"),
        "stopRequestedBeforePaste=" (stopRequestedBeforePaste ? "1" : "0"),
        "stopRequestedBeforeSubmit=" (stopRequestedBeforeSubmit ? "1" : "0"),
        "stoppedBeforeConsolePrep=" (stoppedBeforeConsolePrep ? "1" : "0"),
        "stoppedDuringConsolePrep=" (stoppedDuringConsolePrep ? "1" : "0"),
        "stoppedBeforeClipboard=" (stoppedBeforeClipboard ? "1" : "0"),
        "stoppedAfterClipboardBeforePaste=" (stoppedAfterClipboardBeforePaste ? "1" : "0"),
        "stoppedAfterPasteBeforeSubmit=" (stoppedAfterPasteBeforeSubmit ? "1" : "0"),
        "stoppedBeforeSubmit=" (stoppedBeforeSubmit ? "1" : "0"),
        "stoppedWhileWaiting=" (stoppedWhileWaiting ? "1" : "0"),
        "internalEscSuppressed=" (internalEscSuppressed ? "1" : "0"),
        "timeout=" (timeout ? "1" : "0"),
        "error=" DevToolsBridgeLogValue(errorMessage)
    ]

    try FileAppend(JoinArray(fields, " | ") "`n", logsRoot "\devtools_bridge_returns.log", "UTF-8")
}

DevToolsBridgeRedact(value, maxLen := 1200) {
    text := String(value ?? "")
    text := RegExReplace(text, "[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", "[email]", , , 1)
    text := RegExReplace(text, "(?<!\d)(?:\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}(?!\d)", "[phone]")
    text := RegExReplace(text, "(?<!\d)\d{3}-\d{2}-\d{4}(?!\d)", "[ssn]")
    text := RegExReplace(text, "\b(?=[A-Za-z0-9_-]{24,}\b)(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]+\b", "[id]")
    text := StrReplace(text, "`r", "\r")
    text := StrReplace(text, "`n", "\n")
    text := RegExReplace(text, "\s+", " ")
    if (StrLen(text) > maxLen)
        text := SubStr(text, 1, maxLen) "...[truncated]"
    return text
}

DevToolsBridgeTextHash(value) {
    text := String(value ?? "")
    hash := 0
    Loop Parse text
        hash := Mod((hash * 131) + Ord(A_LoopField), 2147483647)
    return Format("{:08X}", hash)
}

DevToolsBridgeLogValue(value) {
    text := DevToolsBridgeRedact(value, 1200)
    text := StrReplace(text, "|", "/")
    return text
}

DevToolsFocusByMode(mode) {
    return (mode = "edge") ? FocusEdge() : FocusWorkBrowser()
}

ResolveJsAssetPath(assetPath) {
    global assetsRoot
    path := Trim(String(assetPath ?? ""))
    if (path = "")
        return ""
    if InStr(path, ":\")
        return path
    relative := StrReplace(path, "/", "\")
    return assetsRoot "\js\" relative
}

LogJsAssetFailure(context, detail := "") {
    global logsRoot
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    line := ts " | " Trim(String(context)) " | " Trim(String(detail)) "`n"
    try FileAppend(line, logsRoot "\js_asset_errors.log", "UTF-8")
}

LoadJsAsset(assetPath, required := true) {
    resolved := ResolveJsAssetPath(assetPath)
    if (resolved = "") {
        LogJsAssetFailure("LoadJsAsset", "Empty path: " assetPath)
        return ""
    }
    if !FileExist(resolved) {
        if required
            LogJsAssetFailure("LoadJsAsset", "Missing asset: " resolved)
        return ""
    }
    text := Trim(FileRead(resolved, "UTF-8"))
    if (text = "") {
        LogJsAssetFailure("LoadJsAsset", "Empty asset file: " resolved)
        return ""
    }
    return text
}

JsLiteral(value) {
    if IsObject(value) {
        kind := Type(value)
        if (kind = "Map") {
            parts := []
            for k, v in value
                parts.Push(JsLiteral(String(k)) ": " JsLiteral(v))
            return "{ " JoinArray(parts, ", ") " }"
        }
        if (kind = "Array") {
            items := []
            for _, item in value
                items.Push(JsLiteral(item))
            return "[" JoinArray(items, ", ") "]"
        }
        return "null"
    }

    if (value = "")
        return "''"

    if (Type(value) = "Integer" || Type(value) = "Float")
        return String(value)

    text := String(value)
    upper := StrUpper(text)
    if (upper = "TRUE")
        return "true"
    if (upper = "FALSE")
        return "false"
    if (upper = "NULL")
        return "null"

    text := StrReplace(text, "\", "\\")
    text := StrReplace(text, "'", "\'")
    text := StrReplace(text, "`r", "\r")
    text := StrReplace(text, "`n", "\n")
    return "'" text "'"
}

RenderJsTemplate(jsText, params) {
    rendered := String(jsText ?? "")
    if !IsObject(params)
        params := Map()

    for key, value in params {
        token := "@@" String(key) "@@"
        rendered := StrReplace(rendered, token, JsLiteral(value))
    }

    if RegExMatch(rendered, "@@[A-Z0-9_]+@@", &m) {
        LogJsAssetFailure("RenderJsTemplate", "Unresolved token: " m[0])
        return ""
    }
    if (Trim(rendered) = "") {
        LogJsAssetFailure("RenderJsTemplate", "Rendered script empty")
        return ""
    }
    return rendered
}

RunDevToolsJsAssetWork(assetPath, params := Map(), expectResult := true) {
    jsText := LoadJsAsset(assetPath, true)
    if (jsText = "")
        return expectResult ? "" : false

    rendered := RenderJsTemplate(jsText, params)
    if (rendered = "")
        return expectResult ? "" : false

    context := DevToolsBridgeContext(assetPath, params)
    return expectResult ? RunDevToolsJSGetResult(rendered, context) : RunDevToolsJS(rendered, context)
}

RunDevToolsJsAssetEdge(assetPath, params := Map(), expectResult := true) {
    jsText := LoadJsAsset(assetPath, true)
    if (jsText = "")
        return expectResult ? "" : false

    rendered := RenderJsTemplate(jsText, params)
    if (rendered = "")
        return expectResult ? "" : false

    context := DevToolsBridgeContext(assetPath, params)
    return expectResult ? RunDevToolsJSGetResultEdge(rendered, context) : RunDevToolsJSEdge(rendered, context)
}

BuildParticipantInputFocusJS() {
    return LoadJsAsset("participant_input_focus.js", true)
}

RunParticipantInputFocus() {
    return RunDevToolsJsAssetWork("participant_input_focus.js", Map(), true)
}

JS_FocusActionDropdown() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "focus_action_dropdown", "ARGS", Map()), true) = "OK_ACTION"
}

JS_SaveHistoryNote() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "save_history_note", "ARGS", Map()), true) = "OK_SAVE"
}

JS_AddNewAppointment() {
    result := RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "add_new_appointment", "ARGS", Map()), true)
    return (result = "OK_FUNC" || result = "OK_APPT")
}

JS_FocusDateTimeField() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "focus_date_time_field", "ARGS", Map()), true) = "OK_TIME"
}

JS_SaveAppointment() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "save_appointment", "ARGS", Map()), true) = "OK_FINAL"
}

JS_GetBlitzCurrentLeadTitle() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "get_blitz_current_lead_title", "ARGS", Map()), true)
}

JS_DevToolsBridgeProbe() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "bridge_probe", "ARGS", Map()), true)
}

JS_GetBlitzPageStatus() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "blitz_page_status", "ARGS", Map()), true)
}

JS_ClickBlitzNextLead() {
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "click_blitz_next_lead", "ARGS", Map()), true)
}

EscapeJsSingleQuoted(text) {
    value := text ?? ""
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, "'", "\'")
    value := StrReplace(value, "`r", "\r")
    value := StrReplace(value, "`n", "\n")
    return value
}

JS_OpenBlitzLeadLogByName(targetName) {
    args := Map("targetName", targetName)
    return RunDevToolsJsAssetWork("devtools_bridge/ops_result.js", Map("OP", "open_blitz_lead_log_by_name", "ARGS", args), true)
}
