BuildLastConfiguredFollowupDateText() {
    global configDays, holidays

    lastDay := GetMaxConfiguredDay(configDays)
    lastDate := BusinessDateForDay(lastDay, holidays)
    return lastDate . " 3:00 PM"
}

BuildTomorrowMorningDateText() {
    global holidays

    tomorrow := BusinessDateForDay(1, holidays)
    return tomorrow . " 10:00 AM"
}

RunPasteLastConfiguredDatePreset() {
    dtText := BuildLastConfiguredFollowupDateText()
    BeginAutomationRun()
    CrmApplyAppointmentPreset(dtText, ["e"])
}

RunPasteTomorrowPhonePreset() {
    dtText := BuildTomorrowMorningDateText()
    BeginAutomationRun()
    CrmApplyAppointmentPreset(dtText, ["P", "P"])
}

RunCrmAttemptedContactWorkflow() {
    BeginAutomationRun()

    noteText := TemplateRead("CrmNotes", "AttemptedContact", "txt")
    dtText := BuildLastConfiguredFollowupDateText()

    if !FocusWorkBrowser() {
        MsgBox("Browser not detected.")
        return
    }

    bridgeProbe := JS_DevToolsBridgeProbe()
    if (bridgeProbe != "OK_BRIDGE") {
        CrmBlitzLog("CRM_ATTEMPTED_CONTACT_FAILED", "context=ctrl-alt-k;reason=bridge-probe-failed;result=" bridgeProbe)
        MsgBox("The CRM JavaScript operator did not execute in the DevTools Console. Open the Blitz tab, make sure the Console accepts pasted scripts, then try Ctrl+Alt+K again.")
        return
    }

    if !CrmRunAttemptedContactAppointmentGuarded(noteText, dtText, "ctrl-alt-k-current-lead")
        MsgBox("Blitz is not ready for attempted-contact, or the attempted-contact sequence failed. Check logs\crm_blitz_workflow.log.")
}

RunCrmQuoteCallWorkflow() {
    noteText := TemplateRead("CrmNotes", "QuoteCall", "qt")
    dtText := BuildTomorrowMorningDateText()

    if !FocusWorkBrowser() {
        MsgBox("Browser not detected.")
        return
    }

    BeginAutomationRun()
    CrmRunQuoteCallAppointment(noteText, dtText)
}
