RunDevToolsJS(jsCode) {
    result := RunDevToolsJSInternal(jsCode, "work", false)
    return result = true
}

RunDevToolsJSGetResult(jsCode) {
    result := RunDevToolsJSInternal(jsCode, "work", true)
    return (Type(result) = "String") ? result : ""
}

RunDevToolsJSEdge(jsCode) {
    result := RunDevToolsJSInternal(jsCode, "edge", false)
    return result = true
}

RunDevToolsJSGetResultEdge(jsCode) {
    result := RunDevToolsJSInternal(jsCode, "edge", true)
    return (Type(result) = "String") ? result : ""
}

RunDevToolsJSInternal(jsCode, mode := "work", expectResult := false) {
    if StopRequested()
        return expectResult ? "" : false

    if !DevToolsFocusByMode(mode)
        return expectResult ? "" : false

    savedClip := ClipboardAll()

    try {
        A_Clipboard := ""
        if !SafeSleep(30)
            return expectResult ? "" : false
        if StopRequested()
            return expectResult ? "" : false
        A_Clipboard := jsCode
        if !WaitForClip(1000)
            return expectResult ? "" : false

        sentCode := A_Clipboard

        if StopRequested()
            return expectResult ? "" : false
        Send "^+j"
        if !SafeSleep(500)
            return expectResult ? "" : false

        if StopRequested()
            return expectResult ? "" : false
        Send "^a"
        if !SafeSleep(80)
            return expectResult ? "" : false
        if StopRequested()
            return expectResult ? "" : false
        Send "^v"
        if !SafeSleep(120)
            return expectResult ? "" : false
        if StopRequested()
            return expectResult ? "" : false
        Send "{Enter}"
        if !SafeSleep(expectResult ? 300 : 180)
            return expectResult ? "" : false

        if expectResult {
            result := ""
            Loop 25 {
                if !SafeSleep(100)
                    return ""
                if (A_Clipboard != sentCode && Trim(A_Clipboard) != "") {
                    result := Trim(A_Clipboard)
                    break
                }
            }

            if StopRequested()
                return ""
            Send "^+j"
            if !SafeSleep(220)
                return ""
            DevToolsFocusByMode(mode)
            if !SafeSleep(150)
                return ""
            return result
        }

        if StopRequested()
            return false
        Send "^+j"
        if !SafeSleep(180)
            return false
        return true
    } finally {
        A_Clipboard := savedClip
    }
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

    return expectResult ? RunDevToolsJSGetResult(rendered) : RunDevToolsJS(rendered)
}

RunDevToolsJsAssetEdge(assetPath, params := Map(), expectResult := true) {
    jsText := LoadJsAsset(assetPath, true)
    if (jsText = "")
        return expectResult ? "" : false

    rendered := RenderJsTemplate(jsText, params)
    if (rendered = "")
        return expectResult ? "" : false

    return expectResult ? RunDevToolsJSGetResultEdge(rendered) : RunDevToolsJSEdge(rendered)
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
