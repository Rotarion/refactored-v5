Esc:: {
    global StopFlag, running
    StopFlag := true
    running := false
    SetTimer(SpamLoop, 0)
    PersistRunState("stop-requested")
    try AdvisorQuoteLogStop("manual-esc")
    step := ""
    try step := AdvisorQuoteGetLastStep()
    ToolTip(step != "" ? ("STOPPED - " step) : "STOPPED")
    SetTimer(ClearStopToolTip, -700)
}

F1::ExitApp

^!g:: {
    global tagSymbol

    BeginAutomationRun()
    result := RunQuoTagSelector()
    if (result = "") {
        MsgBox("Selector JS returned blank result.")
        return
    }

    finalStatus := HandleQuoTagSelectorResult(result, tagSymbol)
    MsgBox(
        "Selector result: " result "`n"
        . "Final status: " finalStatus "`n"
        . "Tag used: " tagSymbol,
        "Quo Tag Selector Test"
    )
}

^!c:: {
    hwnd := WinGetID("A")
    controls := WinGetControls("ahk_id " hwnd)

    out := ""
    for c in controls
        out .= c "`n"

    MsgBox(out = "" ? "No controls found." : out)
}

^!`:: {
    OpenConfigEditor(1)
}

^!m:: {
    raw := Trim(A_Clipboard)
    if (raw = "") {
        MsgBox("Clipboard empty.")
        return
    }

    data := ParseLabeledLeadRaw(raw)
    dobRaw := data.Has("Date of Birth") ? data["Date of Birth"] : ""
    zipRaw := data.Has("Zip Code") ? data["Zip Code"] : ""

    MsgBox(
        "DOB RAW:`n" dobRaw
        . "`n`nDOB NORMALIZED:`n" NormalizeDOB(dobRaw)
        . "`n`nZIP RAW:`n" zipRaw
        . "`n`nZIP NORMALIZED:`n" NormalizeZip(zipRaw),
        "DOB / ZIP Debug"
    )
}

^!p:: {
    raw := Trim(A_Clipboard)
    fields := NormalizeProspectInput(raw)
    msg := ""
    for k, v in fields
        msg .= k ": " v "`n"
    MsgBox(msg, "Parsed Prospect")
}

^!]:: {
    raw := Trim(A_Clipboard)
    if (raw = "") {
        MsgBox("Clipboard empty.")
        return
    }
    data := ParseLabeledLeadRaw(raw)
    msg := ""
    for k, v in data
        msg .= "[" k "] = " v "`n"
    MsgBox(msg, "Labeled Lead Raw Map")
}

^!l:: {
    global batchLeadHolder
    raw := Trim(A_Clipboard)
    if (raw = "") {
        MsgBox("Clipboard empty.")
        return
    }

    batchLeadHolder := BuildBatchLeadHolder(raw)

    msg := "Leads found: " batchLeadHolder.Length "`n`n"
    for i, lead in batchLeadHolder {
        previewPrice := ResolveQuotePrice(lead["VEHICLE_COUNT"], lead["VEHICLES"], true)
        msg .= i ". " lead["FULL_NAME"]
            . " | Phone: " lead["PHONE"]
            . " | Cars: " lead["VEHICLE_COUNT"]
            . " | Price: " previewPrice
            . "`n"
    }
    MsgBox(msg, "Batch Lead Holder Preview")
}

^!s:: {
    if !FocusEdge() {
        MsgBox("Edge not focused. Open Advisor Pro in Edge and try again.")
        return
    }

    BeginAutomationRun()
    scan := AdvisorQuoteScanCurrentPage()
    if (scan = "") {
        MsgBox("Scanner returned empty output.")
        return
    }

    MsgBox(
        "Scanner complete.`n`nCopied to clipboard and saved to:`n"
        . "C:\\Users\\sflzsl7k\\Documents\\Codex\\Final_V5.5_refactored\\logs\\advisor_scan_latest.json",
        "Advisor Scanner"
    )
}

^!+s:: {
    BeginAutomationRun()
    result := AdvisorQuoteCaptureStateSnapshotDebug("Ctrl+Alt+Shift+S")
    status := AdvisorQuoteStatusValue(result, "result")
    route := AdvisorQuoteStatusValue(result, "route")
    confidence := AdvisorQuoteStatusValue(result, "confidence")
    errorText := AdvisorQuoteStatusValue(result, "error")
    latestPath := AdvisorQuoteStatusValue(result, "latestPath")

    message := "Advisor snapshot " status
    if (route != "")
        message .= "`nroute=" route
    if (confidence != "")
        message .= " confidence=" confidence
    if (errorText != "")
        message .= "`n" errorText
    message .= "`n" latestPath
    ToolTip(message)
    SetTimer(ClearStopToolTip, -1800)
}

^!+r:: {
    BeginAutomationRun()
    result := AdvisorQuoteRunReadOnlyRunnerPilotSelfTest()
    MsgBox(
        "Read-only runner pilot self-test complete."
            . "`n`nResult: " AdvisorQuoteStatusValue(result, "result")
            . "`nEnv visible: " AdvisorQuoteStatusValue(result, "envVisible")
            . "`nPilot resolved: " AdvisorQuoteStatusValue(result, "pilotResolved")
            . "`nGate allowed: " AdvisorQuoteStatusValue(result, "gateAllowed")
            . "`nRunner result: " AdvisorQuoteStatusValue(result, "runnerResult")
            . "`nFallback reason: " AdvisorQuoteStatusValue(result, "fallbackReason")
            . "`nTiny attempt delta: " AdvisorQuoteStatusValue(result, "runnerTinyAttemptDelta"),
        "Advisor Runner Pilot Self-Test"
    )
}

F8:: {
    global running
    running := !running

    if running {
        BeginAutomationRun()
        ToolTip("RUNNING (F8 to stop)")
        SetTimer(SpamLoop, 200)
    } else {
        SetTimer(SpamLoop, 0)
        PersistRunState("spamloop-stopped")
        ToolTip("STOPPED")
        Sleep 800
        ToolTip()
    }
}

SpamLoop() {
    global running
    if !running || StopRequested()
        return

    Click
    if !SafeSleep(20)
        return
    if StopRequested()
        return
    Send "{Enter}"
}
