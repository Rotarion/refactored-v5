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

RunCrmAttemptedContactForLatestBatchOkLeads() {
    leadNames := LoadLatestBatchOkLeadNames()
    if (leadNames.Length = 0) {
        MsgBox("No saved OK leads were found. Run a batch with the updated script first.")
        return
    }

    if !FocusWorkBrowser() {
        MsgBox("Browser not detected.")
        return
    }

    currentName := GetCurrentBlitzLeadName()
    if (currentName = "") {
        currentName := BlitzOpenLeadLogByName(leadNames[1])
        if (currentName = "") {
            MsgBox("Could not detect the current Blitz lead or open the first saved lead. Keep Blitz on the lead list or an open lead log.")
            return
        }
    }

    noteText := TemplateRead("CrmNotes", "AttemptedContact", "txt")
    dtText := BuildLastConfiguredFollowupDateText()
    cursor := FindBlitzLeadNameIndex(leadNames, currentName)
    if (cursor = 0) {
        currentName := BlitzOpenLeadLogByName(leadNames[1])
        if (currentName = "")
            cursor := 1
        else
            cursor := 1
    }

    processed := []
    stopped := false
    failReason := ""
    startName := currentName

    BeginAutomationRun()

    while (cursor <= leadNames.Length) {
        if StopRequested() {
            stopped := true
            break
        }

        currentName := GetCurrentBlitzLeadName()
        if (currentName = "") {
            failReason := "Could not read the current Blitz lead name."
            break
        }

        expectedName := leadNames[cursor]
        if BlitzLeadNamesMatch(currentName, expectedName) {
            if !CrmRunAttemptedContactAppointment(noteText, dtText) {
                failReason := "CRM attempted-contact failed for " currentName "."
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
        }

        nextName := BlitzGoToNextLead(currentName)
        if (nextName = "") {
            failReason := "Could not move to the next lead from " currentName "."
            break
        }
    }

    msg := "Start lead: " startName "`n"
        . "Processed: " processed.Length " of " leadNames.Length "`n"

    if (cursor > leadNames.Length)
        msg .= "Result: Complete"
    else if stopped
        msg .= "Result: Stopped by ESC"
    else
        msg .= "Result: " failReason

    if (processed.Length > 0) {
        msg .= "`n`nMatched leads:`n"
        for _, line in processed
            msg .= line "`n"
    }

    MsgBox(msg, "Batch OK -> CRM")
}
