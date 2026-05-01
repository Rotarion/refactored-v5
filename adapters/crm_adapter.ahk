FillNewProspectForm(fields) {
    global FORM_FIELD_DELAY, FORM_TAB_DELAY, FORM_PASTE_DELAY, FORM_PASTE_TAB_DELAY, FORM_CITY_TAB_DELAY

    ReplaceFieldText(fields["FIRST_NAME"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    ReplaceFieldText(fields["LAST_NAME"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    PasteField(fields["DOB"])
    Sleep FORM_PASTE_DELAY
    Send "{Tab}"
    Sleep FORM_PASTE_TAB_DELAY

    SelectDropdownValue(fields["GENDER"])

    ReplaceFieldText(fields["ADDRESS_1"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    ReplaceFieldText(fields["APT_SUITE"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    ReplaceFieldText(fields["BUILDING"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    ReplaceFieldText(fields["RR_NUMBER"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    ReplaceFieldText(fields["LOT_NUMBER"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    ReplaceFieldText(fields["CITY"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_CITY_TAB_DELAY

    SelectDropdownValue(fields["STATE"])

    ReplaceFieldText(fields["ZIP"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    ReplaceFieldText(fields["PHONE"])
}

FillNationalGeneralForm(fields) {
    global FORM_FIELD_DELAY, FORM_TAB_DELAY, FORM_PASTE_DELAY, FORM_PASTE_TAB_DELAY, FORM_CITY_TAB_DELAY

    FastType(fields["FIRST_NAME"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    FastType(fields["LAST_NAME"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    Loop 5 {
        Send "{Tab}"
        Sleep FORM_TAB_DELAY
    }

    PasteField(fields["DOB"])
    Sleep FORM_PASTE_DELAY
    Send "{Tab}"
    Sleep FORM_PASTE_TAB_DELAY

    Loop 3 {
        Send "{Tab}"
        Sleep FORM_TAB_DELAY
    }

    FastType(fields["ADDRESS_1"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    FastType(fields["APT_SUITE"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY

    FastType(fields["CITY"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_CITY_TAB_DELAY

    SelectDropdownValue(fields["STATE"])

    FastType(fields["ZIP"])
    Sleep FORM_FIELD_DELAY
    Send "{Tab}"
    Sleep FORM_TAB_DELAY
}

CrmApplyAppointmentPreset(dtText, postDateKeys) {
    global CRM_KEYSTEP_DELAY, CRM_MEDIUM_DELAY

    if !SetClip(dtText) {
        MsgBox("Clipboard failed (date).")
        return false
    }

    Sleep 80
    SendEvent "^v"
    Sleep 220

    if !SendTabs(6)
        return false
    Sleep CRM_KEYSTEP_DELAY
    for _, key in postDateKeys {
        SendEvent key
        Sleep CRM_KEYSTEP_DELAY
    }
    if !SendTabs(3)
        return false
    Sleep CRM_KEYSTEP_DELAY
    SendEvent "c"
    Sleep CRM_MEDIUM_DELAY
    return true
}

CrmRunAttemptedContactAppointment(noteText, dtText) {
    global CRM_ACTION_FOCUS_DELAY, CRM_KEYSTEP_DELAY, CRM_SHORT_DELAY, CRM_MEDIUM_DELAY
    global CRM_SAVE_HISTORY_DELAY, CRM_ADD_APPOINTMENT_DELAY, CRM_FOCUS_DATE_DELAY, CRM_FINAL_SAVE_DELAY

    JS_FocusActionDropdown()
    Sleep CRM_ACTION_FOCUS_DELAY

    SendEvent "l"
    Sleep CRM_KEYSTEP_DELAY
    SendEvent "{Tab}"
    Sleep CRM_KEYSTEP_DELAY
    SendEvent "{Tab}"
    Sleep CRM_MEDIUM_DELAY
    SendEvent "1"
    Sleep CRM_MEDIUM_DELAY

    if !SendTabs(9)
        return false
    Sleep CRM_SHORT_DELAY

    if !SetClip(noteText) {
        MsgBox("Clipboard failed (note text).")
        return false
    }
    Sleep 80
    SendEvent "^v"
    Sleep CRM_MEDIUM_DELAY

    JS_SaveHistoryNote()
    Sleep CRM_SAVE_HISTORY_DELAY

    JS_AddNewAppointment()
    Sleep CRM_ADD_APPOINTMENT_DELAY

    JS_FocusDateTimeField()
    Sleep CRM_FOCUS_DATE_DELAY

    if !CrmApplyAppointmentPreset(dtText, ["e"])
        return false

    JS_SaveAppointment()
    Sleep CRM_FINAL_SAVE_DELAY
    return true
}

CrmBlitzLog(eventType, detail := "") {
    global logsRoot
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    safeEvent := RegExReplace(Trim(String(eventType ?? "")), "[\r\n|]+", " ")
    safeDetail := CrmBlitzLogValue(detail)
    try FileAppend(ts " | " safeEvent " | " safeDetail "`n", logsRoot "\crm_blitz_workflow.log", "UTF-8")
}

CrmBlitzLogValue(value, maxLen := 1000) {
    text := String(value ?? "")
    text := RegExReplace(text, "[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", "[email]", , , 1)
    text := RegExReplace(text, "(?<!\d)(?:\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}(?!\d)", "[phone]")
    text := RegExReplace(text, "(?<!\d)\d{3}-\d{2}-\d{4}(?!\d)", "[ssn]")
    text := RegExReplace(text, "\b(?=[A-Za-z0-9_-]{24,}\b)(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]+\b", "[id]")
    text := StrReplace(text, "`r", " ")
    text := StrReplace(text, "`n", " ")
    text := StrReplace(text, "|", "/")
    text := RegExReplace(text, "\s+", " ")
    text := Trim(text)
    if (StrLen(text) > maxLen)
        text := SubStr(text, 1, maxLen) "...[truncated]"
    return text
}

CrmParseKeyValueLines(text) {
    data := Map()
    for _, line in StrSplit(String(text ?? ""), "`n", "`r") {
        pos := InStr(line, "=")
        if (pos <= 0)
            continue
        key := Trim(SubStr(line, 1, pos - 1))
        if (key = "")
            continue
        data[key] := Trim(SubStr(line, pos + 1))
    }
    return data
}

CrmStatusValue(status, key, defaultValue := "") {
    return (IsObject(status) && status.Has(key)) ? status[key] : defaultValue
}

CrmBlitzStatusSummary(status) {
    keys := [
        "result", "page", "topPage", "actionPage", "actionFramePath",
        "hasNextLead", "hasActionDropdown", "hasHistorySave", "hasAddAppointment",
        "missing", "evidence"
    ]
    parts := []
    for _, key in keys {
        value := CrmStatusValue(status, key)
        if (value != "")
            parts.Push(key "=" value)
    }
    return JoinArray(parts, ";")
}

CrmGetBlitzPageStatus(context := "", logIt := true) {
    raw := JS_GetBlitzPageStatus()
    status := CrmParseKeyValueLines(raw)
    status["_raw"] := raw
    if !status.Has("result")
        status["result"] := (Trim(String(raw ?? "")) = "") ? "EMPTY" : "UNKNOWN"
    if logIt
        CrmBlitzLog("BLITZ_STATUS_PRECHECK", "context=" context ";rawLength=" StrLen(String(raw ?? "")) ";" CrmBlitzStatusSummary(status))
    return status
}

CrmBlitzStatusReadyForAttemptedContact(status) {
    result := CrmStatusValue(status, "result")
    page := CrmStatusValue(status, "page")
    actionPage := CrmStatusValue(status, "actionPage")
    return (
        result = "READY"
        && actionPage = "lead-log"
        && (page = "lead-log" || page = "lead-list-with-open-lead-log")
        && CrmStatusValue(status, "hasActionDropdown") = "1"
        && CrmStatusValue(status, "hasHistorySave") = "1"
        && CrmStatusValue(status, "hasAddAppointment") = "1"
    )
}

CrmWaitForBlitzAttemptedContactReady(context := "", timeoutMs := 12000) {
    endTick := A_TickCount + timeoutMs
    lastStatus := Map("result", "TIMEOUT")

    while (A_TickCount < endTick) {
        if StopRequested() {
            lastStatus["result"] := "STOPPED"
            CrmBlitzLog("BLITZ_STATUS_WAIT_STOPPED", "context=" context)
            return lastStatus
        }
        status := CrmGetBlitzPageStatus(context, false)
        lastStatus := status
        if CrmBlitzStatusReadyForAttemptedContact(status) {
            CrmBlitzLog("BLITZ_STATUS_READY", "context=" context ";" CrmBlitzStatusSummary(status))
            return status
        }
        if !SafeSleep(300)
            break
    }

    CrmBlitzLog("BLITZ_STATUS_WAIT_TIMEOUT", "context=" context ";" CrmBlitzStatusSummary(lastStatus))
    return lastStatus
}

CrmRunAttemptedContactAppointmentGuarded(noteText, dtText, context := "current-lead") {
    CrmBlitzLog("CRM_ATTEMPTED_CONTACT_START", "context=" context)
    status := CrmGetBlitzPageStatus(context)
    if !CrmBlitzStatusReadyForAttemptedContact(status) {
        CrmBlitzLog("BLITZ_PAGE_NOT_READY_FOR_ATTEMPTED_CONTACT", "context=" context ";" CrmBlitzStatusSummary(status))
        return false
    }

    ok := CrmRunAttemptedContactAppointment(noteText, dtText)
    CrmBlitzLog(ok ? "CRM_ATTEMPTED_CONTACT_DONE" : "CRM_ATTEMPTED_CONTACT_FAILED", "context=" context)
    return ok
}

CrmRunQuoteCallAppointment(noteText, dtText) {
    global CRM_ACTION_FOCUS_DELAY, CRM_KEYSTEP_DELAY, CRM_MEDIUM_DELAY
    global CRM_QUOTE_SHIFT_TAB_DELAY, CRM_SAVE_HISTORY_DELAY, CRM_ADD_APPOINTMENT_DELAY
    global CRM_FOCUS_DATE_DELAY, CRM_FINAL_SAVE_DELAY

    JS_FocusActionDropdown()
    Sleep CRM_ACTION_FOCUS_DELAY

    SendEvent "l"
    Sleep CRM_KEYSTEP_DELAY
    SendEvent "{Tab}"
    Sleep CRM_KEYSTEP_DELAY
    SendEvent "q"
    Sleep CRM_KEYSTEP_DELAY
    SendEvent "+{Tab}"
    Sleep CRM_QUOTE_SHIFT_TAB_DELAY
    SendEvent "{Tab}"
    Sleep CRM_MEDIUM_DELAY
    SendEvent "{Tab}"
    Sleep CRM_MEDIUM_DELAY
    SendEvent "3"
    Sleep CRM_MEDIUM_DELAY

    if !SendTabs(9)
        return false
    Sleep CRM_MEDIUM_DELAY

    if !SetClip(noteText) {
        MsgBox("Clipboard failed (note text).")
        return false
    }
    Sleep 80
    SendEvent "^v"
    Sleep CRM_MEDIUM_DELAY

    JS_SaveHistoryNote()
    Sleep CRM_SAVE_HISTORY_DELAY

    JS_AddNewAppointment()
    Sleep CRM_ADD_APPOINTMENT_DELAY

    JS_FocusDateTimeField()
    Sleep CRM_FOCUS_DATE_DELAY

    if !CrmApplyAppointmentPreset(dtText, ["p", "p"])
        return false

    JS_SaveAppointment()
    Sleep CRM_FINAL_SAVE_DELAY
    return true
}

NormalizeBlitzLeadName(name) {
    text := CleanName(name)
    text := RegExReplace(text, "i)^\s*(?:DUPLICATED\s+)?(?:OPPORTUNITY\s+)?PERSONAL\s+LEAD\s*-\s*", "")
    text := RegExReplace(text, "\s*\([^)]*\)\s*$", "")
    text := RegExReplace(text, "\s+", " ")
    return ProperCase(Trim(text))
}

GetCurrentBlitzLeadName() {
    return NormalizeBlitzLeadName(JS_GetBlitzCurrentLeadTitle())
}

BlitzLeadNamesMatch(leftName, rightName) {
    normalizedLeft := NormalizeBlitzLeadName(leftName)
    normalizedRight := NormalizeBlitzLeadName(rightName)
    return (normalizedLeft != "" && normalizedLeft = normalizedRight)
}

FindBlitzLeadNameIndex(leadNames, targetName) {
    normalizedTarget := NormalizeBlitzLeadName(targetName)
    if (normalizedTarget = "")
        return 0

    for index, name in leadNames {
        if BlitzLeadNamesMatch(name, normalizedTarget)
            return index
    }
    return 0
}

WaitForBlitzLeadChange(previousName, timeoutMs := 12000) {
    previousName := NormalizeBlitzLeadName(previousName)
    endTick := A_TickCount + timeoutMs

    while (A_TickCount < endTick) {
        if StopRequested()
            return ""
        if !SafeSleep(250)
            return ""

        currentName := GetCurrentBlitzLeadName()
        if (currentName != "" && currentName != previousName)
            return currentName
    }
    return ""
}

WaitForBlitzLeadMatch(targetName, timeoutMs := 12000) {
    endTick := A_TickCount + timeoutMs

    while (A_TickCount < endTick) {
        if StopRequested()
            return ""
        if !SafeSleep(250)
            return ""

        currentName := GetCurrentBlitzLeadName()
        if BlitzLeadNamesMatch(currentName, targetName)
            return currentName
    }
    return ""
}

BlitzGoToNextLead(previousName) {
    result := JS_ClickBlitzNextLead()
    if (result != "OK_NEXT")
        return ""
    return WaitForBlitzLeadChange(previousName)
}

BlitzOpenLeadLogByName(targetName) {
    result := JS_OpenBlitzLeadLogByName(targetName)
    if (result != "OK_OPEN")
        return ""
    return WaitForBlitzLeadMatch(targetName)
}

CrmEnsureBlitzLeadOpen(targetName) {
    currentName := GetCurrentBlitzLeadName()
    if BlitzLeadNamesMatch(currentName, targetName) {
        CrmBlitzLog("BLITZ_CURRENT_LEAD_MATCH_INDEX", "target=" targetName ";current=" currentName)
        return currentName
    }

    CrmBlitzLog("BLITZ_OPEN_LEAD_ATTEMPT", "target=" targetName)
    openedName := BlitzOpenLeadLogByName(targetName)
    CrmBlitzLog("BLITZ_OPEN_LEAD_RESULT", "target=" targetName ";opened=" openedName)
    if (openedName != "")
        CrmWaitForBlitzAttemptedContactReady("open-lead-" NormalizeBlitzLeadName(targetName), 12000)
    return openedName
}

RunCrmAttemptedContactForLatestBatchOkLeads() {
    ; If the previous run was stopped with ESC, clear that state before any DOM/JS probes.
    BeginAutomationRun()

    leadNames := LoadLatestBatchOkLeadNames()
    CrmBlitzLog("BATCH_OK_LIST_LOADED", "count=" leadNames.Length)
    if (leadNames.Length = 0) {
        MsgBox("No saved OK leads were found. Run a batch with the updated script first.")
        return
    }

    if !FocusWorkBrowser() {
        MsgBox("Browser not detected.")
        return
    }

    bridgeProbe := JS_DevToolsBridgeProbe()
    if (bridgeProbe != "OK_BRIDGE") {
        CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=bridge-probe-failed;result=" bridgeProbe)
        MsgBox("The CRM JavaScript operator did not execute in the DevTools Console. Open the Blitz tab, make sure the Console accepts pasted scripts, then try Ctrl+Alt+H again.")
        return
    }

    startStatus := CrmGetBlitzPageStatus("batch-start")
    currentName := GetCurrentBlitzLeadName()
    CrmBlitzLog("BLITZ_CURRENT_LEAD_TITLE", "context=batch-start;current=" currentName)
    if !CrmBlitzStatusReadyForAttemptedContact(startStatus) {
        if (CrmStatusValue(startStatus, "page") = "lead-list" && CrmStatusValue(startStatus, "hasLeadListLinks") = "1") {
            currentName := CrmEnsureBlitzLeadOpen(leadNames[1])
            startStatus := CrmWaitForBlitzAttemptedContactReady("batch-open-first", 12000)
        }
    }
    if (currentName = "") {
        currentName := CrmEnsureBlitzLeadOpen(leadNames[1])
        if (currentName = "") {
            CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=open-first-failed")
            MsgBox("Could not detect the current Blitz lead or open the first saved lead. Keep Blitz on the lead list or an open lead log.")
            return
        }
    }
    if !CrmBlitzStatusReadyForAttemptedContact(startStatus) {
        startStatus := CrmWaitForBlitzAttemptedContactReady("batch-ready-start", 12000)
        if !CrmBlitzStatusReadyForAttemptedContact(startStatus) {
            CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=not-ready-start;" CrmBlitzStatusSummary(startStatus))
            MsgBox("Blitz is not ready for attempted-contact mutation. Check logs\crm_blitz_workflow.log.")
            return
        }
    }

    noteText := TemplateRead("CrmNotes", "AttemptedContact", "txt")
    dtText := BuildLastConfiguredFollowupDateText()
    cursor := FindBlitzLeadNameIndex(leadNames, currentName)
    if (cursor = 0) {
        currentName := CrmEnsureBlitzLeadOpen(leadNames[1])
        if (currentName = "") {
            CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=current-not-in-list-open-first-failed;current=" currentName)
            MsgBox("The current Blitz lead is not in the saved OK list, and the first saved OK lead could not be opened from the visible lead list.")
            return
        }
        cursor := 1
    }

    processed := []
    stopped := false
    failReason := ""
    startName := currentName

    while (cursor <= leadNames.Length) {
        if StopRequested() {
            stopped := true
            break
        }

        expectedName := leadNames[cursor]
        CrmBlitzLog("BATCH_TARGET_LEAD", "index=" cursor ";target=" expectedName)
        currentName := GetCurrentBlitzLeadName()
        CrmBlitzLog("BLITZ_CURRENT_LEAD_TITLE", "context=batch-loop;current=" currentName)
        if !BlitzLeadNamesMatch(currentName, expectedName) {
            currentName := CrmEnsureBlitzLeadOpen(expectedName)
        }
        if !BlitzLeadNamesMatch(currentName, expectedName) {
            failReason := "Could not open expected Blitz lead " expectedName "."
            CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=open-expected-failed;target=" expectedName ";current=" currentName)
            break
        }

        readyStatus := CrmWaitForBlitzAttemptedContactReady("batch-before-mutate-" cursor, 12000)
        if !CrmBlitzStatusReadyForAttemptedContact(readyStatus) {
            failReason := "Blitz page was not ready for attempted-contact on " currentName "."
            CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=not-ready-before-mutate;target=" expectedName ";" CrmBlitzStatusSummary(readyStatus))
            break
        }

        if !CrmRunAttemptedContactAppointmentGuarded(noteText, dtText, "batch-index-" cursor) {
            failReason := "CRM attempted-contact failed for " currentName "."
            CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=attempted-contact-failed;target=" expectedName)
            break
        }

        processed.Push(cursor . ". " . expectedName)
        cursor += 1
        if (cursor > leadNames.Length)
            break
        if !SafeSleep(500) {
            stopped := true
            break
        }

        CrmBlitzLog("BLITZ_NEXT_ATTEMPT", "from=" currentName)
        nextName := BlitzGoToNextLead(currentName)
        if (nextName = "") {
            nextTarget := leadNames[cursor]
            CrmBlitzLog("BLITZ_NEXT_DONE", "result=NO_NEXT;fallbackTarget=" nextTarget)
            nextName := CrmEnsureBlitzLeadOpen(nextTarget)
            if (nextName = "") {
                failReason := "Could not move to or open the next lead from " currentName "."
                CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=next-and-open-failed;from=" currentName ";target=" nextTarget)
                break
            }
        } else {
            CrmBlitzLog("BLITZ_NEXT_DONE", "result=OK;next=" nextName)
            CrmWaitForBlitzAttemptedContactReady("batch-after-next", 12000)
        }
    }

    msg := "Start lead: " startName "`n"
        . "Processed: " processed.Length " of " leadNames.Length "`n"

    if (cursor > leadNames.Length) {
        msg .= "Result: Complete"
        CrmBlitzLog("BLITZ_BATCH_REPLAY_DONE", "processed=" processed.Length ";total=" leadNames.Length)
    } else if stopped {
        msg .= "Result: Stopped by ESC"
        CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=stopped;processed=" processed.Length)
    } else {
        msg .= "Result: " failReason
        CrmBlitzLog("BLITZ_BATCH_REPLAY_FAILED", "reason=" failReason ";processed=" processed.Length)
    }

    if (processed.Length > 0) {
        msg .= "`n`nMatched leads:`n"
        for _, line in processed
            msg .= line "`n"
    }

    MsgBox(msg, "Batch OK -> CRM")
}
