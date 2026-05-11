global advisorQuoteRunId := ""
global advisorQuoteRunStartedAt := ""
global advisorQuoteScanBundlePath := ""
global advisorQuoteScanBundleItems := []
global advisorQuoteScanCount := 0
global advisorQuoteWriteIndividualScanArchives := false
global advisorQuoteProductOverviewAutoPending := false
global advisorQuoteProductOverviewAutoVerified := false
global advisorQuoteProductTileAutoSelectedOnOverview := false
global advisorQuoteProductOverviewSaved := false
global advisorQuoteGatherAutoCommitted := false
global advisorQuoteProductTileRecoveryAttempted := false
global advisorQuoteUseResidentOperatorTransport := true
global advisorQuoteResidentTransportReadOnlyEnabled := true
global advisorQuoteResidentTransportMutationEnabled := false
global advisorQuoteResidentOperatorBootstrapped := false
global advisorQuoteResidentRunnerFeatureEnabled := false
global advisorQuoteResidentRunnerReadOnlyOnly := true
global advisorQuoteResidentRunnerUseTinyBridge := true
global advisorQuoteUseRunnerForReadOnlyPolling := true
global advisorQuoteReadOnlyRunnerBootstrapped := false
global advisorQuoteReadOnlyRunnerPilotLogged := false
global advisorQuoteJsMetrics := 0
global advisorQuoteJsMetricOps := Map()
global advisorQuoteConsoleBridgeOpen := false
global advisorQuoteConsoleBridgeFocus := "page"

RunAdvisorQuoteWorkflowFromClipboard() {
    raw := Trim(A_Clipboard)
    if (raw = "") {
        MsgBox("Clipboard empty. Copy one lead row first.")
        return AdvisorQuoteResultFail("INIT", "INIT", "Clipboard empty. Copy one lead row first.", false)
    }

    profile := BuildAdvisorQuoteLeadProfile(raw)
    if !AdvisorQuoteProfileLooksUsable(profile) {
        MsgBox("Could not parse enough lead data for Advisor quote flow.")
        return AdvisorQuoteResultFail("INIT", "INIT", "Could not parse enough lead data for Advisor quote flow.", false)
    }

    BeginAutomationRun()
    AdvisorQuoteInitTrace(profile)
    db := GetAdvisorQuoteWorkflowDb()
    result := RunAdvisorQuoteWorkflow(profile, db)

    if StopRequested() {
        AdvisorQuoteLogJsMetricsSummary("manual-stop")
        AdvisorQuoteLogStop("manual-stop-detected-after-run")
        return AdvisorQuoteResultFail(AdvisorQuoteGetLastStep(), AdvisorQuoteGetLastStep(), "Stopped manually.", false, AdvisorQuoteResultValue(result, "scanPath"))
    }

    AdvisorQuoteLogJsMetricsSummary(AdvisorQuoteResultOk(result) ? "success" : "fail")
    if !AdvisorQuoteResultOk(result) {
        AdvisorQuoteAppendLog("FAIL", AdvisorQuoteResultValue(result, "state"), AdvisorQuoteFormatResultForLog(result))
        MsgBox(AdvisorQuoteFormatResultMessage(result))
    } else {
        AdvisorQuoteAppendLog("SUCCESS", AdvisorQuoteResultValue(result, "state"), AdvisorQuoteResultValue(result, "reason"))
    }
    return result
}

RunAdvisorQuoteWorkflow(profile, db) {
    result := AdvisorQuoteRunRequiredState(profile, db, "EDGE_ACTIVATION")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "ENTRY_SEARCH")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "ENTRY_CREATE_FORM")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "DUPLICATE")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "CUSTOMER_SUMMARY_OVERVIEW")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "PRODUCT_OVERVIEW")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "RAPPORT")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "SELECT_PRODUCT")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "CONSUMER_REPORTS")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "DRIVERS_VEHICLES")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "INCIDENTS")
    if !AdvisorQuoteResultOk(result)
        return result

    result := AdvisorQuoteRunRequiredState(profile, db, "QUOTE_LANDING")
    if !AdvisorQuoteResultOk(result)
        return result

    AdvisorQuoteSetStep("DONE", "Advisor quote workflow reached quote-ready state.")
    return AdvisorQuoteResultOkValue("DONE", "DONE", "Workflow reached first quote page.")
}

AdvisorQuoteRunRequiredState(profile, db, stateName) {
    return AdvisorQuoteRunStateWithRetries(stateName, profile, db, db["timeouts"]["maxRetries"])
}

AdvisorQuoteResultOk(result) {
    return IsObject(result) && result.Has("ok") && result["ok"]
}

AdvisorQuoteResultValue(result, key) {
    if !IsObject(result)
        return ""
    return result.Has(key) ? result[key] : ""
}

AdvisorQuoteResultOkValue(state, step, reason := "", scanPath := "", observedState := "", details := 0) {
    return AdvisorQuoteMakeResult(true, state, step, reason, false, scanPath, observedState, details)
}

AdvisorQuoteResultFail(state, step, reason, retryable := false, scanPath := "", observedState := "", details := 0) {
    return AdvisorQuoteMakeResult(false, state, step, reason, retryable, scanPath, observedState, details)
}

AdvisorQuoteMakeResult(ok, state, step, reason, retryable := false, scanPath := "", observedState := "", details := 0) {
    payload := Map(
        "ok", ok,
        "state", state,
        "step", step,
        "reason", reason,
        "retryable", retryable,
        "scanPath", scanPath,
        "observedState", observedState
    )
    if IsObject(details)
        payload["details"] := details
    else
        payload["details"] := Map()
    return payload
}

AdvisorQuoteFormatResultMessage(result) {
    lines := []
    lines.Push("Advisor Quote Workflow Failed")
    lines.Push("State: " AdvisorQuoteResultValue(result, "state"))
    lines.Push("Step: " AdvisorQuoteResultValue(result, "step"))
    lines.Push("Reason: " AdvisorQuoteResultValue(result, "reason"))
    observedState := Trim(String(AdvisorQuoteResultValue(result, "observedState")))
    if (observedState != "")
        lines.Push("Observed Page State: " observedState)
    scanPath := Trim(String(AdvisorQuoteResultValue(result, "scanPath")))
    if (scanPath != "")
        lines.Push("Scan: " scanPath)
    return JoinArray(lines, "`n")
}

AdvisorQuoteFormatResultForLog(result) {
    return "ok=" AdvisorQuoteResultValue(result, "ok")
        . ", retryable=" AdvisorQuoteResultValue(result, "retryable")
        . ", reason=" AdvisorQuoteResultValue(result, "reason")
        . ", observedState=" AdvisorQuoteResultValue(result, "observedState")
        . ", scan=" AdvisorQuoteResultValue(result, "scanPath")
}

AdvisorQuoteRunStateWithRetries(stateName, profile, db, maxAttempts := 0) {
    if (maxAttempts <= 0)
        maxAttempts := 1

    lastResult := AdvisorQuoteResultFail(stateName, stateName, "State did not execute.", false)
    Loop maxAttempts {
        if StopRequested()
            return AdvisorQuoteResultFail(stateName, AdvisorQuoteGetLastStep(), "Stopped manually.", false, AdvisorQuoteResultValue(lastResult, "scanPath"))

        AdvisorQuoteSetStep(stateName, "Attempt " A_Index "/" maxAttempts)
        entryScanPath := AdvisorQuoteScanCurrentPage(stateName, "entry-attempt-" A_Index)
        AdvisorQuoteAppendLog("STATE_ATTEMPT", stateName, "attempt=" A_Index "/" maxAttempts ", scan=" entryScanPath)

        result := AdvisorQuoteCallStateHandler(stateName, profile, db, A_Index, entryScanPath)
        if !IsObject(result)
            result := AdvisorQuoteResultFail(stateName, stateName, "State handler returned a non-object result.", false, entryScanPath)
        if (Trim(String(AdvisorQuoteResultValue(result, "scanPath"))) = "" && entryScanPath != "")
            result["scanPath"] := entryScanPath

        if AdvisorQuoteResultOk(result)
            return result

        lastResult := result
        AdvisorQuoteAppendLog("STATE_RESULT", stateName, AdvisorQuoteFormatResultForLog(result))

        if !AdvisorQuoteResultValue(result, "retryable")
            return result
        if (A_Index >= maxAttempts)
            return result

        retryScanPath := AdvisorQuoteScanCurrentPage(stateName, "retry-" A_Index)
        currentObservedState := AdvisorQuoteDetectState(db)
        AdvisorQuoteAppendLog(
            "STATE_RETRY",
            stateName,
            "attempt=" A_Index "/" maxAttempts
                . ", observedState=" currentObservedState
                . ", reason=" AdvisorQuoteResultValue(result, "reason")
                . ", scan=" retryScanPath
        )
        if !SafeSleep(db["timeouts"]["shortMs"])
            return result
    }

    return lastResult
}

AdvisorQuoteCallStateHandler(stateName, profile, db, attempt := 1, entryScanPath := "") {
    switch stateName {
        case "EDGE_ACTIVATION":
            return AdvisorQuoteStateEdgeActivation(db, attempt, entryScanPath)
        case "ENTRY_SEARCH":
            return AdvisorQuoteStateEntrySearch(db, attempt, entryScanPath)
        case "ENTRY_CREATE_FORM":
            return AdvisorQuoteStateEntryCreateForm(profile, db, attempt, entryScanPath)
        case "DUPLICATE":
            return AdvisorQuoteStateDuplicate(profile, db, attempt, entryScanPath)
        case "CUSTOMER_SUMMARY_OVERVIEW":
            return AdvisorQuoteStateCustomerSummaryOverview(db, attempt, entryScanPath)
        case "PRODUCT_OVERVIEW":
            return AdvisorQuoteStateProductOverview(db, attempt, entryScanPath)
        case "RAPPORT":
            return AdvisorQuoteStateRapport(profile, db, attempt, entryScanPath)
        case "SELECT_PRODUCT":
            return AdvisorQuoteStateSelectProduct(db, attempt, entryScanPath)
        case "CONSUMER_REPORTS":
            return AdvisorQuoteStateConsumerReports(profile, db, attempt, entryScanPath)
        case "DRIVERS_VEHICLES":
            return AdvisorQuoteStateDriversVehicles(profile, db, attempt, entryScanPath)
        case "INCIDENTS":
            return AdvisorQuoteStateIncidents(db, attempt, entryScanPath)
        case "QUOTE_LANDING":
            return AdvisorQuoteStateQuoteLanding(db, attempt, entryScanPath)
        default:
            return AdvisorQuoteResultFail(stateName, stateName, "Unknown workflow state: " stateName, false, entryScanPath)
    }
}

AdvisorQuoteStateEdgeActivation(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("EDGE_ACTIVATION", "Ensuring Edge context and Advisor page detection.")
    if !FocusEdge()
        return AdvisorQuoteResultFail("EDGE_ACTIVATION", "EDGE_ACTIVATION", "Microsoft Edge not found. Open Advisor Pro first.", false, entryScanPath, "NO_EDGE")

    state := AdvisorQuoteDetectState(db)
    if (state = "NO_CONTEXT")
        return AdvisorQuoteResultFail("EDGE_ACTIVATION", "EDGE_ACTIVATION", "Could not detect an Advisor Pro or Gateway page in Edge.", false, entryScanPath, state)
    if (state = "UNKNOWN")
        return AdvisorQuoteResultFail("EDGE_ACTIVATION", "EDGE_ACTIVATION", "Edge is active but the page state is still unknown.", true, entryScanPath, state)
    return AdvisorQuoteResultOkValue("EDGE_ACTIVATION", "EDGE_ACTIVATION", "Detected page state: " state, entryScanPath, state)
}

; Extracted Advisor page-state module functions: AdvisorQuoteStateEntrySearch, AdvisorQuoteStateEntryCreateForm, AdvisorQuoteStateDuplicate, AdvisorQuoteStateCustomerSummaryOverview, AdvisorQuoteStateProductOverview

; Extracted Advisor RAPPORT module functions: AdvisorQuoteStateRapport

; Extracted Advisor page-state module functions: AdvisorQuoteStateSelectProduct, AdvisorQuoteStateConsumerReports

AdvisorQuoteStateDriversVehicles(profile, db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("DRIVERS_VEHICLES", "Resolving drivers and vehicles.")
    state := AdvisorQuoteDetectState(db)
    if (state = "INCIDENTS")
        return AdvisorQuoteResultOkValue("DRIVERS_VEHICLES", "DRIVERS_VEHICLES", "Drivers and Vehicles already completed.", entryScanPath, state)

    failureReason := ""
    failureScan := ""
    if !AdvisorQuoteHandleDriversVehicles(profile, db, &failureReason, &failureScan) {
        if (failureScan = "")
            failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "drivers-vehicles-failed")
        if (failureReason = "")
            failureReason := "Drivers and Vehicles stage did not complete."
        return AdvisorQuoteResultFail("DRIVERS_VEHICLES", "DRIVERS_VEHICLES", failureReason, true, failureScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("DRIVERS_VEHICLES", "DRIVERS_VEHICLES", "Drivers and Vehicles completed.", entryScanPath, AdvisorQuoteDetectState(db))
}

AdvisorQuoteStateIncidents(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("INCIDENTS", "Handling incidents page if present.")
    if !AdvisorQuoteHandleIncidentsIfPresent(db) {
        failScan := AdvisorQuoteScanCurrentPage("INCIDENTS", "incidents-failed")
        return AdvisorQuoteResultFail("INCIDENTS", "INCIDENTS", "Incidents stage did not complete.", true, failScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("INCIDENTS", "INCIDENTS", "Incidents stage completed or was skipped.", entryScanPath, AdvisorQuoteDetectState(db))
}

AdvisorQuoteStateQuoteLanding(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("QUOTE_LANDING", "Waiting for the first quote page to load.")
    if !AdvisorQuoteWaitForQuoteLanding(db) {
        failScan := AdvisorQuoteScanCurrentPage("QUOTE_LANDING", "quote-landing-failed")
        return AdvisorQuoteResultFail("QUOTE_LANDING", "QUOTE_LANDING", "Quote page did not load after Drivers/Incidents.", true, failScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("QUOTE_LANDING", "QUOTE_LANDING", "Workflow reached the first quote page.", entryScanPath, AdvisorQuoteDetectState(db))
}

AdvisorQuoteIsStateInList(state, states) {
    for _, candidate in states
        if (state = candidate)
            return true
    return false
}

AdvisorQuoteWaitForObservedState(db, acceptedStates, timeoutMs, pollMs := 0) {
    if (pollMs <= 0)
        pollMs := db["timeouts"]["pollMs"]
    start := A_TickCount
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return ""
        state := AdvisorQuoteDetectState(db)
        if AdvisorQuoteIsStateInList(state, acceptedStates)
            return state
        if !SafeSleep(pollMs)
            return ""
    }
    return ""
}

; Extracted Advisor page-state module functions: AdvisorQuoteOpenCreateNewProspectFromSearchResult, AdvisorQuoteClickCreateProspectPrimaryButtonDetailed, AdvisorQuoteBuildProspectInvalidReason, AdvisorQuoteIsDriversVehiclesState

AdvisorQuoteAscWaitArgs(db, extraArgs := Map()) {
    args := Map("ascProductContains", db["urls"]["ascProductContains"])
    if IsObject(extraArgs) {
        for key, value in extraArgs
            args[String(key)] := value
    }
    return args
}

; Extracted Advisor page-state module functions: AdvisorQuoteAscProductRouteIdText, AdvisorQuoteIsConsumerReportsConsentPage, AdvisorQuoteIsQuoteLandingPage, AdvisorQuoteTryRouteConsumerReportsAscProduct, AdvisorQuoteProfileLooksUsable ...

AdvisorQuoteEnsureEdgeAndDetectState(db) {
    if StopRequested()
        return false
    if !FocusEdge()
        return false

    state := AdvisorQuoteDetectState(db)
    if (state = "NO_CONTEXT")
        return false
    return true
}

AdvisorQuoteDetectState(db) {
    args := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    result := AdvisorQuoteRunOp("detect_state", args, 2, 200)
    return (result = "") ? "UNKNOWN" : result
}

AdvisorQuoteIsPastEntry(db) {
    if AdvisorQuoteIsDuplicatePage(db)
        return true
    if AdvisorQuoteIsOnRapportPage(db)
        return true
    if AdvisorQuoteIsOnSelectProductPage(db)
        return true
    if AdvisorQuoteIsOnAscProductPage(db)
        return true
    return false
}

AdvisorQuoteWaitForAnyState(db, timeoutMs) {
    start := A_TickCount
    pollMs := db["timeouts"]["pollMs"]
    nextHeartbeat := A_TickCount + 5000
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return false
        state := AdvisorQuoteDetectState(db)
        if (state = "BEGIN_QUOTING_SEARCH")
            return true
        if (state = "BEGIN_QUOTING_FORM")
            return true
        if AdvisorQuoteIsPastEntry(db)
            return true
        if (A_TickCount >= nextHeartbeat) {
            elapsed := A_TickCount - start
            AdvisorQuoteAppendLog("WAIT_STATE", AdvisorQuoteGetLastStep(), "state=" state ", elapsedMs=" elapsed)
            nextHeartbeat := A_TickCount + 5000
        }
        if !SafeSleep(pollMs)
            return false
    }
    AdvisorQuoteAppendLog("TIMEOUT_STATE", AdvisorQuoteGetLastStep(), "Timed out waiting for next state. timeoutMs=" timeoutMs)
    return false
}

; Extracted Advisor page-state module functions: AdvisorQuoteHandleProspect, AdvisorQuoteWaitForProspectFormReady, AdvisorQuotePrimeProspectFormFill, AdvisorQuoteFillProspectForm, AdvisorQuoteFocusProspectFirstInput ...

AdvisorQuoteParseKeyValueLines(raw) {
    parsed := Map()
    text := StrReplace(String(raw ?? ""), "`r", "")
    if (Trim(text) = "")
        return parsed

    for _, line in StrSplit(text, "`n") {
        line := Trim(line)
        if (line = "")
            continue
        if !InStr(line, "=")
            continue
        parts := StrSplit(line, "=", , 2)
        key := Trim(String(parts[1]))
        value := (parts.Length >= 2) ? Trim(String(parts[2])) : ""
        if (key != "")
            parsed[key] := value
    }
    return parsed
}

; Extracted Advisor page-state module functions: AdvisorQuoteProspectFormReadyToSubmit, AdvisorQuoteProspectFieldMatches, AdvisorQuoteProspectDobMatches, AdvisorQuoteProspectStateMatches, AdvisorQuoteProspectZipMatches

AdvisorQuoteStatusValue(status, key) {
    if !IsObject(status)
        return ""
    return status.Has(key) ? Trim(String(status[key])) : ""
}

AdvisorQuoteStatusInteger(status, key) {
    value := AdvisorQuoteStatusValue(status, key)
    return RegExMatch(value, "^-?\d+$") ? Integer(value) : 0
}

AdvisorQuoteSnapshotArgs() {
    db := GetAdvisorQuoteWorkflowDb()
    return Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
}

AdvisorQuoteGetActiveModalStatus() {
    status := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("advisor_active_modal_status", AdvisorQuoteSnapshotArgs(), 2, 120))
    AdvisorQuoteAppendLog("ADVISOR_ACTIVE_MODAL_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildActiveModalStatusDetail(status))
    return status
}

AdvisorQuoteBuildActiveModalStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily")
        . ", activeModalType=" AdvisorQuoteStatusValue(status, "activeModalType")
        . ", activePanelType=" AdvisorQuoteStatusValue(status, "activePanelType")
        . ", saveGate=" AdvisorQuoteStatusValue(status, "saveGate")
        . ", modalTitle=" AdvisorQuoteStatusValue(status, "modalTitle")
        . ", modalSaveButtonId=" AdvisorQuoteStatusValue(status, "modalSaveButtonId")
        . ", modalSaveButtonPresent=" AdvisorQuoteStatusValue(status, "modalSaveButtonPresent")
        . ", modalSaveButtonEnabled=" AdvisorQuoteStatusValue(status, "modalSaveButtonEnabled")
        . ", modalCancelButtonPresent=" AdvisorQuoteStatusValue(status, "modalCancelButtonPresent")
        . ", editVehiclePresent=" AdvisorQuoteStatusValue(status, "editVehiclePresent")
        . ", inlineParticipantPanelPresent=" AdvisorQuoteStatusValue(status, "inlineParticipantPanelPresent")
        . ", removeDriverModalPresent=" AdvisorQuoteStatusValue(status, "removeDriverModalPresent")
        . ", blockerCode=" AdvisorQuoteStatusValue(status, "blockerCode")
        . ", nextRecommendedReadOnlyStatus=" AdvisorQuoteStatusValue(status, "nextRecommendedReadOnlyStatus")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

; Extracted Advisor RAPPORT module functions: AdvisorQuoteGetGatherRapportSnapshot, AdvisorQuoteBuildGatherRapportSnapshotDetail

AdvisorQuoteGetAscDriversVehiclesSnapshot() {
    status := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("asc_drivers_vehicles_snapshot", AdvisorQuoteSnapshotArgs(), 2, 120))
    AdvisorQuoteAppendLog("ASC_DRIVERS_VEHICLES_SNAPSHOT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(status))
    return status
}

AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily")
        . ", ascProductRouteId=" AdvisorQuoteStatusValue(status, "ascProductRouteId")
        . ", activeModalType=" AdvisorQuoteStatusValue(status, "activeModalType")
        . ", activePanelType=" AdvisorQuoteStatusValue(status, "activePanelType")
        . ", saveGate=" AdvisorQuoteStatusValue(status, "saveGate")
        . ", driverCount=" AdvisorQuoteStatusValue(status, "driverCount")
        . ", unresolvedDriverCount=" AdvisorQuoteStatusValue(status, "unresolvedDriverCount")
        . ", addedDriverCount=" AdvisorQuoteStatusValue(status, "addedDriverCount")
        . ", removedDriverCount=" AdvisorQuoteStatusValue(status, "removedDriverCount")
        . ", vehicleCount=" AdvisorQuoteStatusValue(status, "vehicleCount")
        . ", unresolvedVehicleCount=" AdvisorQuoteStatusValue(status, "unresolvedVehicleCount")
        . ", addedVehicleCount=" AdvisorQuoteStatusValue(status, "addedVehicleCount")
        . ", removedVehicleCount=" AdvisorQuoteStatusValue(status, "removedVehicleCount")
        . ", inlineParticipantPanelPresent=" AdvisorQuoteStatusValue(status, "inlineParticipantPanelPresent")
        . ", removeDriverModalPresent=" AdvisorQuoteStatusValue(status, "removeDriverModalPresent")
        . ", removeDriverTargetName=" AdvisorQuoteStatusValue(status, "removeDriverTargetName")
        . ", removeDriverReasonSelected=" AdvisorQuoteStatusValue(status, "removeDriverReasonSelected")
        . ", removeDriverReasonCode=" AdvisorQuoteStatusValue(status, "removeDriverReasonCode")
        . ", mainSavePresent=" AdvisorQuoteStatusValue(status, "mainSavePresent")
        . ", mainSaveEnabled=" AdvisorQuoteStatusValue(status, "mainSaveEnabled")
        . ", blockerCode=" AdvisorQuoteStatusValue(status, "blockerCode")
        . ", nextRecommendedReadOnlyStatus=" AdvisorQuoteStatusValue(status, "nextRecommendedReadOnlyStatus")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

; Extracted Advisor RAPPORT module functions: AdvisorQuoteBuildRapportSnapshotRouteDetail, AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker, AdvisorQuoteGatherStaleBlockerActiveScopeSafe, AdvisorQuoteGatherStaleAddRowStatusSafeForCancel, AdvisorQuoteRapportSubModelPlaceholderFallbackEnabled ...

AdvisorQuoteStatusFieldPresent(status, valueKey, presentKey := "") {
    if (AdvisorQuoteStatusValue(status, valueKey) != "")
        return true
    return presentKey != "" && AdvisorQuoteStatusValue(status, presentKey) = "1"
}

; Extracted Advisor RAPPORT module functions: AdvisorQuoteGatherStaleAddRowStatusResumeableForSubModelFallback, AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail, AdvisorQuoteBuildGatherAddRowSubModelSelectDetail, AdvisorQuoteBuildGatherAddRowAddClickDetail, AdvisorQuoteBuildGatherStaleVehicleCancelSafetyDetail ...

AdvisorQuoteBuildAscSnapshotRouteDetail(snapshot, removeRouted := "0", inlineRouted := "0", afterModalResult := "", afterPanelResult := "") {
    return "ascSnapshotActiveModalType=" AdvisorQuoteStatusValue(snapshot, "activeModalType")
        . ", ascSnapshotActivePanelType=" AdvisorQuoteStatusValue(snapshot, "activePanelType")
        . ", ascSnapshotBlockerCode=" AdvisorQuoteStatusValue(snapshot, "blockerCode")
        . ", ascSnapshotRoutedToRemoveModal=" removeRouted
        . ", ascSnapshotRoutedToInlineParticipant=" inlineRouted
        . ", ascSnapshotAfterModalResult=" afterModalResult
        . ", ascSnapshotAfterPanelResult=" afterPanelResult
        . ", removeDriverModalPresent=" AdvisorQuoteStatusValue(snapshot, "removeDriverModalPresent")
        . ", inlineParticipantPanelPresent=" AdvisorQuoteStatusValue(snapshot, "inlineParticipantPanelPresent")
}

AdvisorQuoteResolveAscSnapshotBlockers(profile, db) {
    removeAttempts := 0
    inlineAttempts := 0
    Loop 5 {
        snapshot := AdvisorQuoteGetAscDriversVehiclesSnapshot()
        activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
        activePanelType := AdvisorQuoteStatusValue(snapshot, "activePanelType")
        AdvisorQuoteAppendLog(
            "ASC_SNAPSHOT_GATE",
            AdvisorQuoteGetLastStep(),
            AdvisorQuoteBuildAscSnapshotRouteDetail(snapshot)
                . ", ascSnapshotRemoveAttemptCount=" removeAttempts
                . ", ascSnapshotInlineAttemptCount=" inlineAttempts
        )

        result := AdvisorQuoteStatusValue(snapshot, "result")
        if (result = "NOT_ASC_DRIVERS_VEHICLES")
            return true
        if (result != "OK") {
            AdvisorQuoteAppendLog("ASC_SNAPSHOT_UNREADABLE", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(snapshot))
            return false
        }
        if ((activeModalType = "" || activeModalType = "NONE") && (activePanelType = "" || activePanelType = "NONE"))
            return true

        if (activeModalType = "ASC_REMOVE_DRIVER_MODAL") {
            removeAttempts += 1
            if (removeAttempts > 2) {
                AdvisorQuoteAppendLog("ASC_SNAPSHOT_REMOVE_MODAL_GUARD", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscSnapshotRouteDetail(snapshot, "1", "0"))
                return false
            }
            if !AdvisorQuoteHandleOpenModals(profile, db, 15000)
                return false
            afterSnapshot := AdvisorQuoteGetAscDriversVehiclesSnapshot()
            afterModalType := AdvisorQuoteStatusValue(afterSnapshot, "activeModalType")
            AdvisorQuoteAppendLog(
                "ASC_SNAPSHOT_REMOVE_MODAL_ROUTE_RESULT",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildAscSnapshotRouteDetail(snapshot, "1", "0", AdvisorQuoteStatusValue(afterSnapshot, "result"), "")
                    . ", ascSnapshotAfterActiveModalType=" afterModalType
                    . ", ascSnapshotAfterBlockerCode=" AdvisorQuoteStatusValue(afterSnapshot, "blockerCode")
            )
            if (afterModalType != "ASC_REMOVE_DRIVER_MODAL")
                continue
            if !SafeSleep(db["timeouts"]["pollMs"])
                return false
            continue
        }

        if (activePanelType = "ASC_INLINE_PARTICIPANT_PANEL" || activeModalType = "ASC_INLINE_PARTICIPANT_PANEL") {
            inlineAttempts += 1
            if (inlineAttempts > 2) {
                AdvisorQuoteAppendLog("ASC_SNAPSHOT_INLINE_PANEL_GUARD", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscSnapshotRouteDetail(snapshot, "0", "1"))
                return false
            }
            if !AdvisorQuoteHandleOpenModals(profile, db, 15000)
                return false
            afterSnapshot := AdvisorQuoteGetAscDriversVehiclesSnapshot()
            afterModalType := AdvisorQuoteStatusValue(afterSnapshot, "activeModalType")
            afterPanelType := AdvisorQuoteStatusValue(afterSnapshot, "activePanelType")
            AdvisorQuoteAppendLog(
                "ASC_SNAPSHOT_INLINE_PANEL_ROUTE_RESULT",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildAscSnapshotRouteDetail(snapshot, "0", "1", "", AdvisorQuoteStatusValue(afterSnapshot, "result"))
                    . ", ascSnapshotAfterActiveModalType=" afterModalType
                    . ", ascSnapshotAfterActivePanelType=" afterPanelType
                    . ", ascSnapshotAfterBlockerCode=" AdvisorQuoteStatusValue(afterSnapshot, "blockerCode")
            )
            if (afterModalType != "ASC_INLINE_PARTICIPANT_PANEL" && afterPanelType != "ASC_INLINE_PARTICIPANT_PANEL")
                continue
            if !SafeSleep(db["timeouts"]["pollMs"])
                return false
            continue
        }

        AdvisorQuoteAppendLog("ASC_SNAPSHOT_BLOCKER_UNHANDLED", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscSnapshotRouteDetail(snapshot))
        return false
    }

    AdvisorQuoteAppendLog(
        "ASC_SNAPSHOT_ROUTE_GUARD",
        AdvisorQuoteGetLastStep(),
        "ascSnapshotRemoveAttemptCount=" removeAttempts ", ascSnapshotInlineAttemptCount=" inlineAttempts
    )
    return false
}

; Extracted Advisor page-state module functions: AdvisorQuotePostProspectSubmitStates, AdvisorQuoteShouldCheckCustomerSummaryOverviewFallback, AdvisorQuoteGetCustomerSummaryOverviewStatus, AdvisorQuoteCustomerSummaryStatusHighConfidence, AdvisorQuoteCustomerSummaryStatusForwardConfidence ...

; Extracted Advisor RAPPORT module functions: AdvisorQuoteHandleGatherData, AdvisorQuoteFillGatherDefaults, AdvisorQuoteGetGatherDefaultsStatus, AdvisorQuoteBuildGatherDefaultsStatusDetail, AdvisorQuoteGatherDefaultsValid ...

AdvisorQuoteClassifyAscVehicles(profile) {
    vehicles := (IsObject(profile) && profile.Has("vehicles")) ? profile["vehicles"] : []
    complete := []
    partial := []
    deferred := []

    for _, vehicle in vehicles {
        if AdvisorQuoteVehicleHasActionableFields(vehicle) {
            complete.Push(vehicle)
        } else if AdvisorQuoteVehicleHasPartialYearMakeFields(vehicle) {
            partial.Push(vehicle)
        } else {
            deferred.Push(vehicle)
        }
    }

    return Map(
        "completeVehicles", complete,
        "partialYearMakeVehicles", partial,
        "deferredVehicles", deferred
    )
}

; Extracted Advisor RAPPORT module functions: AdvisorQuoteRapportVehicleLedgerMaxIterations, AdvisorQuoteRapportVehicleTerminalStatus, AdvisorQuoteRapportVehicleLedgerCreate, AdvisorQuoteRapportVehicleLedgerItemDetail, AdvisorQuoteRapportVehicleLedgerFindItem ...

AdvisorQuoteBuildAscPartialVehiclesArgList(vehicles) {
    result := []
    if !IsObject(vehicles)
        return result
    for _, vehicle in vehicles {
        year := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
        make := IsObject(vehicle) && vehicle.Has("make") ? Trim(String(vehicle["make"])) : ""
        if (year = "" || make = "")
            continue
        result.Push(Map(
            "year", year,
            "make", make,
            "model", "",
            "allowedMakeLabels", AdvisorVehicleAllowedMakeLabelsText(make, "", year)
        ))
    }
    return result
}

; Extracted Advisor RAPPORT module functions: AdvisorQuoteLogGatherVehiclePolicy, AdvisorQuoteBuildExpectedVehiclesTextFromList, AdvisorQuoteBuildExpectedVehiclesArgList, AdvisorQuoteBuildGatherFinalExpectedVehicles, AdvisorQuoteVehicleIdentityKey ...

; Extracted Advisor page-state module functions: AdvisorQuoteEnsureAutoStartQuotingState, AdvisorQuoteEnsureStartQuotingAutoCheckbox, AdvisorQuoteBuildStartQuotingAutoCheckboxDetail, AdvisorQuoteClickCreateQuotesOrderReports, AdvisorQuoteClickStartQuotingScopedAddProduct ...

AdvisorQuoteHandleDriversVehicles(profile, db, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    AdvisorQuoteSetStep("DRIVERS_VEHICLES", "Waiting for Drivers and vehicles stage.")
    AdvisorQuoteAppendLog("ASC_DRIVERS_VEHICLES_HANDLER_INVOKED", AdvisorQuoteGetLastStep(), "ascDriversVehiclesHandlerInvoked=1")
    if !AdvisorQuoteWaitForCondition("drivers_or_incidents", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], AdvisorQuoteAscWaitArgs(db)) {
        failureReason := "ASC_DRIVERS_VEHICLES_WAIT_TIMEOUT"
        return false
    }

    if AdvisorQuoteIsIncidentsPage(db)
        return true

    return AdvisorQuoteRunAscDriversVehiclesLedgerLoop(profile, db, &failureReason, &failureScan)
}

AdvisorQuoteGetAscParticipantDetailStatus() {
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("asc_participant_detail_status", Map(), 2, 120))
}

AdvisorQuoteLogAscParticipantDetailStatus(status, eventType) {
    AdvisorQuoteAppendLog(eventType, AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscParticipantDetailStatusDetail(status))
}

AdvisorQuoteBuildAscParticipantDetailStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", ascProductRouteId=" AdvisorQuoteStatusValue(status, "ascProductRouteId")
        . ", panelPresent=" AdvisorQuoteStatusValue(status, "panelPresent")
        . ", savePresent=" AdvisorQuoteStatusValue(status, "savePresent")
        . ", saveEnabled=" AdvisorQuoteStatusValue(status, "saveEnabled")
        . ", genderControlPresent=" AdvisorQuoteStatusValue(status, "genderControlPresent")
        . ", genderAlreadySelected=" AdvisorQuoteStatusValue(status, "genderAlreadySelected")
        . ", maritalControlPresent=" AdvisorQuoteStatusValue(status, "maritalControlPresent")
        . ", maritalAlreadySelected=" AdvisorQuoteStatusValue(status, "maritalAlreadySelected")
        . ", ownershipQuestionPresent=" AdvisorQuoteStatusValue(status, "ownershipQuestionPresent")
        . ", ownershipSelected=" AdvisorQuoteStatusValue(status, "ownershipSelected")
        . ", ageFirstLicensedPresent=" AdvisorQuoteStatusValue(status, "ageFirstLicensedPresent")
        . ", ageFirstLicensedFilled=" AdvisorQuoteStatusValue(status, "ageFirstLicensedFilled")
        . ", movingViolationsControlPresent=" AdvisorQuoteStatusValue(status, "movingViolationsControlPresent")
        . ", defensiveDrivingControlPresent=" AdvisorQuoteStatusValue(status, "defensiveDrivingControlPresent")
        . ", emailPresent=" AdvisorQuoteStatusValue(status, "emailPresent")
        . ", phonePresent=" AdvisorQuoteStatusValue(status, "phonePresent")
        . ", missingRequiredControls=" AdvisorQuoteStatusValue(status, "missingRequiredControls")
        . ", optionalMissingControls=" AdvisorQuoteStatusValue(status, "optionalMissingControls")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

AdvisorQuoteResolveAscParticipantMaritalAndSpouse(profile, db, ledger := "") {
    person := (IsObject(profile) && profile.Has("person")) ? profile["person"] : Map()
    selectedSpouseName := IsObject(ledger) ? AdvisorQuoteStatusValue(ledger, "selectedSpouseName") : ""
    spouseOverrideApplied := IsObject(ledger) ? AdvisorQuoteStatusValue(ledger, "spouseOverrideApplied") : "0"
    args := Map(
        "leadMaritalStatus", AdvisorQuoteLeadMaritalStatus(profile),
        "primaryName", AdvisorQuoteProfileFullName(profile),
        "primaryAge", "",
        "leadSpouseName", AdvisorQuoteLeadSpouseName(profile),
        "selectedSpouseName", selectedSpouseName,
        "forceMarriedSpouseSelection", (selectedSpouseName != "") ? "1" : "0",
        "ascSpouseOverrideSingleEnabled", AdvisorQuoteAscSpouseOverrideSingleEnabled(db) ? "1" : "0",
        "ascSpouseAgeWindowYears", AdvisorQuoteAscSpouseAgeWindowYears(db),
        "ascSpousePreferClosestAge", AdvisorQuoteAscSpousePreferClosestAge(db) ? "1" : "0",
        "spouseOverrideApplied", spouseOverrideApplied,
        "maxSpouseAgeDifference", AdvisorQuoteAscSpouseAgeWindowYears(db),
        "expectedPropertyOwnership", AdvisorQuoteResolveParticipantPropertyOwnership(profile, db)
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("asc_resolve_participant_marital_and_spouse", args))
}

AdvisorQuoteBuildAscMaritalStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", selectedMaritalStatus=" AdvisorQuoteStatusValue(status, "selectedMaritalStatus")
        . ", selectedSpouseText=" AdvisorQuoteStatusValue(status, "selectedSpouseText")
        . ", selectedAgeDiff=" AdvisorQuoteStatusValue(status, "selectedAgeDiff")
        . ", candidateCount=" AdvisorQuoteStatusValue(status, "candidateCount")
        . ", spouseCandidateCount=" AdvisorQuoteStatusValue(status, "spouseCandidateCount")
        . ", spouseCandidateWithinWindowCount=" AdvisorQuoteStatusValue(status, "spouseCandidateWithinWindowCount")
        . ", spouseOverrideApplied=" AdvisorQuoteStatusValue(status, "spouseOverrideApplied")
        . ", spouseOverrideReason=" AdvisorQuoteStatusValue(status, "spouseOverrideReason")
        . ", spouseCandidateSelectedText=" AdvisorQuoteStatusValue(status, "spouseCandidateSelectedText")
        . ", spouseCandidateSelectedAge=" AdvisorQuoteStatusValue(status, "spouseCandidateSelectedAge")
        . ", spouseDriverYesSelected=" AdvisorQuoteStatusValue(status, "spouseDriverYesSelected")
        . ", spouseSelectionMethod=" AdvisorQuoteStatusValue(status, "spouseSelectionMethod")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
}

AdvisorQuoteRunAscDriversVehiclesLedgerLoop(profile, db, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    lastActionKey := ""
    sameActionCount := 0
    driverActionCount := 0
    vehicleActionCount := 0
    inlineSaveCount := 0
    removeAttemptsByTarget := Map()

    Loop 20 {
        iteration := A_Index
        snapshot := AdvisorQuoteGetAscDriversVehiclesSnapshot()
        participantStatus := Map()
        driverStatus := Map()
        vehicleStatus := Map()

        if (AdvisorQuoteStatusValue(snapshot, "result") = "NOT_ASC_DRIVERS_VEHICLES") {
            if AdvisorQuoteIsIncidentsPage(db)
                return true
            failureReason := "ASC_LEDGER_NOT_ON_DRIVERS_VEHICLES"
            failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-wrong-page")
            return false
        }

        activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
        activePanelType := AdvisorQuoteStatusValue(snapshot, "activePanelType")
        hasActiveBlocker := !AdvisorQuoteAscModalPanelClear(activeModalType) || !AdvisorQuoteAscModalPanelClear(activePanelType)
        if !hasActiveBlocker {
            AdvisorQuoteAppendLog("ASC_PARTICIPANT_STATUS_CALL", AdvisorQuoteGetLastStep(), "ascParticipantStatusCalled=1, source=ledger")
            participantStatus := AdvisorQuoteGetAscParticipantDetailStatus()
            AdvisorQuoteLogAscParticipantDetailStatus(participantStatus, "ASC_PARTICIPANT_DETAIL_STATUS")
            driverStatus := AdvisorQuoteGetAscDriverRowsStatus()
            AdvisorQuoteAppendLog("ASC_DRIVER_ROWS_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriverRowsStatusDetail(driverStatus))
            vehicleStatus := AdvisorQuoteGetAscVehicleRowsStatus()
            AdvisorQuoteAppendLog("ASC_VEHICLE_ROWS_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscVehicleRowsStatusDetail(vehicleStatus))
        }

        ledger := AdvisorQuoteBuildAscDriversVehiclesLedger(profile, snapshot, driverStatus, vehicleStatus, participantStatus)
        AdvisorQuoteAppendLog("ASC_LEDGER_STATUS", AdvisorQuoteGetLastStep(), "iteration=" iteration ", " AdvisorQuoteBuildAscLedgerDetail(ledger))
        nextAction := AdvisorQuoteStatusValue(ledger, "nextAction")
        nextActionTarget := AdvisorQuoteStatusValue(ledger, "nextActionTarget")
        actionKey := nextAction "|" nextActionTarget
        if (actionKey = lastActionKey)
            sameActionCount += 1
        else {
            sameActionCount := 1
            lastActionKey := actionKey
        }
        if AdvisorQuoteAscLedgerLoopGuardHit(sameActionCount) {
            failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: repeated nextAction=" nextAction ", target=" nextActionTarget ", ledger=" AdvisorQuoteBuildAscLedgerDetail(ledger)
            failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-repeat-guard")
            AdvisorQuoteAppendLog("ASC_LEDGER_LOOP_GUARD_HIT", AdvisorQuoteGetLastStep(), failureReason)
            return false
        }

        Switch nextAction {
            Case "done":
                return true
            Case "fail":
                failureReason := AdvisorQuoteStatusValue(ledger, "reason")
                if (failureReason = "")
                    failureReason := "ASC_LEDGER_FAILED"
                failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-failed")
                return false
            Case "handle_remove_driver_modal":
                targetKey := (nextActionTarget != "") ? nextActionTarget : "unknown"
                attempts := removeAttemptsByTarget.Has(targetKey) ? removeAttemptsByTarget[targetKey] : 0
                attempts += 1
                removeAttemptsByTarget[targetKey] := attempts
                if (attempts > 2) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: remove modal repeated for target=" targetKey
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-remove-modal-guard")
                    return false
                }
                if !AdvisorQuoteHandleAscRemoveDriverModalLedger(profile, db, snapshot, &failureReason, &failureScan)
                    return false
            Case "handle_inline_participant_panel":
                inlineSaveCount += 1
                if (inlineSaveCount > 2) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: inline participant panel repeated."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-inline-panel-guard")
                    return false
                }
                if !AdvisorQuoteHandleAscInlineParticipantPanelLedger(profile, db, snapshot, &failureReason, &failureScan)
                    return false
            Case "handle_vehicle_modal":
                vehicleActionCount += 1
                if (vehicleActionCount > 10) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: vehicle modal/action count exceeded."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-vehicle-action-guard")
                    return false
                }
                if !AdvisorQuoteHandleAscVehicleModalLedger(profile, db, snapshot, &failureReason, &failureScan)
                    return false
            Case "resolve_participant_policy", "resolve_spouse_marital_panel":
                inlineSaveCount += 1
                if (inlineSaveCount > 2) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: participant policy resolution repeated."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-participant-policy-guard")
                    return false
                }
                maritalStatus := AdvisorQuoteResolveAscParticipantMaritalAndSpouse(profile, db, ledger)
                AdvisorQuoteAppendLog("ASC_PARTICIPANT_MARITAL_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscMaritalStatusDetail(maritalStatus))
                maritalResult := AdvisorQuoteStatusValue(maritalStatus, "result")
                if !AdvisorQuoteIsStateInList(maritalResult, ["SINGLE_CONFIRMED", "SINGLE_SET", "SELECTED", "ALREADY_SELECTED", "NO_DROPDOWN"]) {
                    failureReason := "ASC_PARTICIPANT_POLICY_RESOLVE_FAILED: " AdvisorQuoteBuildAscMaritalStatusDetail(maritalStatus)
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-participant-policy-failed")
                    return false
                }
            Case "add_primary_driver":
                driverActionCount += 1
                if (driverActionCount > 10) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: driver row action count exceeded."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-driver-action-guard")
                    return false
                }
                selectedSpouseName := AdvisorQuoteStatusValue(ledger, "selectedSpouseName")
                result := AdvisorQuoteRunAscDriverReconcile(profile, selectedSpouseName)
                AdvisorQuoteAppendLog("ASC_DRIVER_RECONCILE_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriverReconcileDetail(result) ", ledgerAction=" nextAction)
                if !AdvisorQuoteVerifyAscLedgerRowActionProgress("driver", nextAction, snapshot, result, db, &failureReason, &failureScan)
                    return false
            Case "add_spouse_driver":
                driverActionCount += 1
                if (driverActionCount > 10) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: driver row action count exceeded."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-driver-action-guard")
                    return false
                }
                selectedSpouseName := AdvisorQuoteStatusValue(ledger, "selectedSpouseName")
                result := AdvisorQuoteRunAscDriverReconcile(profile, selectedSpouseName)
                AdvisorQuoteAppendLog("ASC_DRIVER_RECONCILE_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriverReconcileDetail(result) ", ledgerAction=" nextAction)
                if !AdvisorQuoteVerifyAscLedgerRowActionProgress("driver", nextAction, snapshot, result, db, &failureReason, &failureScan)
                    return false
            Case "remove_extra_driver":
                driverActionCount += 1
                if (driverActionCount > 10) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: driver row action count exceeded."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-driver-action-guard")
                    return false
                }
                selectedSpouseName := AdvisorQuoteStatusValue(ledger, "selectedSpouseName")
                result := AdvisorQuoteRunAscDriverReconcile(profile, selectedSpouseName)
                AdvisorQuoteAppendLog("ASC_DRIVER_RECONCILE_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriverReconcileDetail(result) ", ledgerAction=" nextAction)
                if !AdvisorQuoteVerifyAscLedgerRowActionProgress("driver", nextAction, snapshot, result, db, &failureReason, &failureScan)
                    return false
            Case "add_vehicle_row":
                vehicleActionCount += 1
                if (vehicleActionCount > 10) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: vehicle row action count exceeded."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-vehicle-action-guard")
                    return false
                }
                policy := AdvisorQuoteClassifyAscVehicles(profile)
                result := AdvisorQuoteRunAscVehicleReconcile(policy)
                AdvisorQuoteAppendLog("ASC_VEHICLE_RECONCILE_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscVehicleReconcileDetail(result) ", ledgerAction=" nextAction)
                if !AdvisorQuoteVerifyAscLedgerRowActionProgress("vehicle", nextAction, snapshot, result, db, &failureReason, &failureScan)
                    return false
            Case "remove_vehicle_row":
                vehicleActionCount += 1
                if (vehicleActionCount > 10) {
                    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: vehicle row action count exceeded."
                    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-vehicle-action-guard")
                    return false
                }
                policy := AdvisorQuoteClassifyAscVehicles(profile)
                result := AdvisorQuoteRunAscVehicleReconcile(policy)
                AdvisorQuoteAppendLog("ASC_VEHICLE_RECONCILE_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscVehicleReconcileDetail(result) ", ledgerAction=" nextAction)
                if !AdvisorQuoteVerifyAscLedgerRowActionProgress("vehicle", nextAction, snapshot, result, db, &failureReason, &failureScan)
                    return false
            Case "save":
                if !AdvisorQuoteAscSaveAndContinueFromLedger(ledger, db, &failureReason, &failureScan)
                    return false
                return AdvisorQuoteWaitForCondition("after_driver_vehicle_continue", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], AdvisorQuoteAscWaitArgs(db))
            Default:
                failureReason := "ASC_LEDGER_UNKNOWN_ACTION: " nextAction
                failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-unknown-action")
                return false
        }

        if !SafeSleep(db["timeouts"]["pollMs"]) {
            failureReason := "ASC_LEDGER_WAIT_FAILED"
            return false
        }
    }

    failureReason := "ASC_LEDGER_LOOP_GUARD_HIT: max total ASC ledger iterations reached."
    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-total-guard")
    AdvisorQuoteAppendLog("ASC_LEDGER_LOOP_GUARD_HIT", AdvisorQuoteGetLastStep(), failureReason)
    return false
}

AdvisorQuoteBuildAscDriversVehiclesLedger(profile, snapshot, driverStatus := "", vehicleStatus := "", participantStatus := "", dbOverride := "") {
    db := IsObject(dbOverride) ? dbOverride : GetAdvisorQuoteWorkflowDb()
    ledger := Map(
        "result", "OK",
        "routeFamily", AdvisorQuoteStatusValue(snapshot, "routeFamily"),
        "ascProductRouteId", AdvisorQuoteStatusValue(snapshot, "ascProductRouteId"),
        "activeModalType", AdvisorQuoteStatusValue(snapshot, "activeModalType"),
        "activePanelType", AdvisorQuoteStatusValue(snapshot, "activePanelType"),
        "blockerCode", AdvisorQuoteStatusValue(snapshot, "blockerCode"),
        "primaryDriverStatus", "ambiguous",
        "spousePolicy", AdvisorQuoteAscSpousePolicyName(profile, db),
        "spouseStatus", "not_applicable",
        "selectedSpouseName", "",
        "spouseOverrideApplied", "0",
        "spouseOverrideReason", "",
        "spouseCandidateCount", "0",
        "spouseCandidateWithinWindowCount", "0",
        "spouseCandidateSelectedText", "",
        "spouseCandidateSelectedAge", "",
        "ascSpouseOverrideSingleEnabled", AdvisorQuoteAscSpouseOverrideSingleEnabled(db) ? "1" : "0",
        "ascSpouseAgeWindowYears", String(AdvisorQuoteAscSpouseAgeWindowYears(db)),
        "ascSpousePreferClosestAge", AdvisorQuoteAscSpousePreferClosestAge(db) ? "1" : "0",
        "extraDriverCount", "0",
        "extraDriversToRemove", "",
        "unresolvedDriverCount", AdvisorQuoteStatusValue(snapshot, "unresolvedDriverCount"),
        "expectedVehicleCount", "0",
        "vehiclesAdded", AdvisorQuoteStatusValue(snapshot, "addedVehicleCount"),
        "vehiclesToAdd", "",
        "unresolvedVehicleCount", AdvisorQuoteStatusValue(snapshot, "unresolvedVehicleCount"),
        "mainSavePresent", AdvisorQuoteStatusValue(snapshot, "mainSavePresent"),
        "mainSaveEnabled", AdvisorQuoteStatusValue(snapshot, "mainSaveEnabled"),
        "nextAction", "",
        "nextActionType", "",
        "nextActionTarget", "",
        "reason", "",
        "evidence", ""
    )

    snapshotResult := AdvisorQuoteStatusValue(snapshot, "result")
    if (snapshotResult != "OK")
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_LEDGER_SNAPSHOT_NOT_OK:" snapshotResult, "snapshot")

    activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
    activePanelType := AdvisorQuoteStatusValue(snapshot, "activePanelType")
    if (activeModalType = "ASC_REMOVE_DRIVER_MODAL")
        return AdvisorQuoteAscLedgerNext(ledger, "BLOCKED", "handle_remove_driver_modal", "modal", AdvisorQuoteStatusValue(snapshot, "removeDriverTargetName"), "ASC_REMOVE_DRIVER_MODAL_OPEN", "snapshot")
    if (activePanelType = "ASC_INLINE_PARTICIPANT_PANEL" || activeModalType = "ASC_INLINE_PARTICIPANT_PANEL")
        return AdvisorQuoteAscLedgerNext(ledger, "BLOCKED", "handle_inline_participant_panel", "panel", "inline-participant", "ASC_INLINE_PARTICIPANT_PANEL_OPEN", "snapshot")
    if (activeModalType = "ASC_VEHICLE_MODAL")
        return AdvisorQuoteAscLedgerNext(ledger, "BLOCKED", "handle_vehicle_modal", "modal", "vehicle-modal", "ASC_VEHICLE_MODAL_OPEN", "snapshot")
    if !AdvisorQuoteAscModalPanelClear(activeModalType)
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_ACTIVE_MODAL_UNHANDLED:" activeModalType, "snapshot")
    if !AdvisorQuoteAscModalPanelClear(activePanelType)
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_ACTIVE_PANEL_UNHANDLED:" activePanelType, "snapshot")

    if (!IsObject(participantStatus) || AdvisorQuoteStatusValue(participantStatus, "result") != "FOUND")
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_PARTICIPANT_DETAIL_NOT_FOUND", "participant")

    driverRows := AdvisorQuoteAscParseDriverRows(driverStatus)
    vehicleRows := AdvisorQuoteAscParseVehicleRows(vehicleStatus)
    primaryName := AdvisorQuoteProfileFullName(profile)
    leadMarital := AdvisorQuoteLeadMaritalStatus(profile)
    primaryRow := AdvisorQuoteAscFindDriverRow(driverRows, primaryName)
    if IsObject(primaryRow) {
        if (AdvisorQuoteStatusValue(primaryRow, "added") = "1")
            ledger["primaryDriverStatus"] := "added"
        else if (AdvisorQuoteStatusValue(primaryRow, "add") = "1")
            ledger["primaryDriverStatus"] := "needs_add"
        else
            ledger["primaryDriverStatus"] := "ambiguous"
    } else {
        ledger["primaryDriverStatus"] := (primaryName = "") ? "ambiguous" : "missing"
    }

    spouseEval := AdvisorQuoteAscEvaluateSpouse(profile, participantStatus, driverRows, db)
    ledger["spousePolicy"] := spouseEval["policy"]
    ledger["spouseStatus"] := spouseEval["status"]
    ledger["selectedSpouseName"] := spouseEval["selectedSpouseName"]
    ledger["spouseOverrideApplied"] := spouseEval.Has("overrideApplied") ? spouseEval["overrideApplied"] : "0"
    ledger["spouseOverrideReason"] := spouseEval.Has("overrideReason") ? spouseEval["overrideReason"] : ""
    ledger["spouseCandidateCount"] := spouseEval.Has("candidateCount") ? spouseEval["candidateCount"] : "0"
    ledger["spouseCandidateWithinWindowCount"] := spouseEval.Has("withinWindowCount") ? spouseEval["withinWindowCount"] : "0"
    ledger["spouseCandidateSelectedText"] := spouseEval.Has("selectedCandidateText") ? spouseEval["selectedCandidateText"] : ""
    ledger["spouseCandidateSelectedAge"] := spouseEval.Has("selectedCandidateAge") ? spouseEval["selectedCandidateAge"] : ""
    if (spouseEval["reason"] != "")
        ledger["reason"] := spouseEval["reason"]

    if (ledger["spouseStatus"] = "ambiguous")
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_SPOUSE_CANDIDATE_AMBIGUOUS:" spouseEval["reason"], spouseEval["evidence"])
    if (ledger["spouseStatus"] = "blocked")
        return AdvisorQuoteAscLedgerFail(ledger, spouseEval["reason"], spouseEval["evidence"])
    if AdvisorQuoteAscParticipantPolicyNeedsAction(profile, participantStatus, ledger, db) {
        participantAction := (ledger["spouseOverrideApplied"] = "1") ? "resolve_spouse_marital_panel" : "resolve_participant_policy"
        return AdvisorQuoteAscLedgerNext(ledger, "OK", participantAction, "panel", ledger["selectedSpouseName"], "participant-policy-not-resolved", spouseEval["evidence"])
    }

    if (ledger["primaryDriverStatus"] = "needs_add")
        return AdvisorQuoteAscLedgerNext(ledger, "OK", "add_primary_driver", "driver", primaryName, "primary-driver-needs-add", AdvisorQuoteStatusValue(driverStatus, "driverSummaries"))
    if (ledger["primaryDriverStatus"] != "added")
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_PRIMARY_DRIVER_ROW_" StrUpper(ledger["primaryDriverStatus"]), AdvisorQuoteStatusValue(driverStatus, "driverSummaries"))

    expectedNames := AdvisorQuoteAscExpectedDriverNames(profile, ledger["selectedSpouseName"])
    if (ledger["selectedSpouseName"] != "" && ledger["spouseStatus"] != "not_applicable") {
        spouseRow := AdvisorQuoteAscFindDriverRow(driverRows, ledger["selectedSpouseName"])
        if IsObject(spouseRow) {
            if (AdvisorQuoteStatusValue(spouseRow, "added") = "1")
                ledger["spouseStatus"] := "added"
            else if (AdvisorQuoteStatusValue(spouseRow, "add") = "1") {
                ledger["spouseStatus"] := "needs_add"
                return AdvisorQuoteAscLedgerNext(ledger, "OK", "add_spouse_driver", "driver", ledger["selectedSpouseName"], "spouse-driver-needs-add", AdvisorQuoteStatusValue(driverStatus, "driverSummaries"))
            } else
                return AdvisorQuoteAscLedgerFail(ledger, "ASC_SPOUSE_ROW_AMBIGUOUS", AdvisorQuoteStatusValue(driverStatus, "driverSummaries"))
        }
    }

    extras := []
    for _, row in driverRows {
        if AdvisorQuoteAscRowMatchesAnyDriver(row, expectedNames)
            continue
        if (AdvisorQuoteStatusValue(row, "remove") = "1")
            extras.Push(AdvisorQuoteStatusValue(row, "name"))
    }
    ledger["extraDriverCount"] := String(extras.Length)
    ledger["extraDriversToRemove"] := JoinArray(extras, "||")
    if (extras.Length > 0)
        return AdvisorQuoteAscLedgerNext(ledger, "OK", "remove_extra_driver", "driver", extras[1], "extra-driver-remove-candidate", AdvisorQuoteStatusValue(driverStatus, "driverSummaries"))

    unresolvedDrivers := AdvisorQuoteStatusInteger(driverStatus, "unresolvedDriverCount")
    ledger["unresolvedDriverCount"] := String(unresolvedDrivers)
    if (unresolvedDrivers > 0)
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_DRIVER_ROW_AMBIGUOUS", AdvisorQuoteStatusValue(driverStatus, "driverSummaries"))

    vehiclePolicy := AdvisorQuoteClassifyAscVehicles(profile)
    expectedVehicleCount := vehiclePolicy["completeVehicles"].Length
    addedVehicles := AdvisorQuoteStatusInteger(vehicleStatus, "addedVehicleCount")
    unresolvedVehicles := AdvisorQuoteStatusInteger(vehicleStatus, "unresolvedVehicleCount")
    ledger["expectedVehicleCount"] := String(expectedVehicleCount)
    ledger["vehiclesAdded"] := String(addedVehicles)
    ledger["unresolvedVehicleCount"] := String(unresolvedVehicles)
    if (expectedVehicleCount > 0 && addedVehicles < expectedVehicleCount) {
        ledger["vehiclesToAdd"] := AdvisorQuoteVehicleListSummary(vehiclePolicy["completeVehicles"])
        if (unresolvedVehicles > 0)
            return AdvisorQuoteAscLedgerNext(ledger, "OK", "add_vehicle_row", "vehicle", ledger["vehiclesToAdd"], "expected-vehicle-row-needs-add", AdvisorQuoteStatusValue(vehicleStatus, "vehicleSummaries"))
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_VEHICLE_ROW_VERIFY_FAILED", AdvisorQuoteStatusValue(vehicleStatus, "vehicleSummaries"))
    }
    if (expectedVehicleCount = 0 && addedVehicles < 1)
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_VEHICLE_ROW_VERIFY_FAILED:no-expected-or-added-vehicle", AdvisorQuoteStatusValue(vehicleStatus, "vehicleSummaries"))
    if (unresolvedVehicles > 0)
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_VEHICLE_ROW_AMBIGUOUS", AdvisorQuoteStatusValue(vehicleStatus, "vehicleSummaries"))

    ledger["mainSavePresent"] := AdvisorQuoteStatusValue(snapshot, "mainSavePresent")
    ledger["mainSaveEnabled"] := AdvisorQuoteStatusValue(snapshot, "mainSaveEnabled")
    if (ledger["mainSavePresent"] != "1")
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_SAVE_MISSING_AFTER_LEDGER_RESOLUTION", AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(snapshot))
    if (ledger["mainSaveEnabled"] != "1")
        return AdvisorQuoteAscLedgerFail(ledger, "ASC_SAVE_DISABLED_AFTER_LEDGER_RESOLUTION", AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(snapshot))
    return AdvisorQuoteAscLedgerNext(ledger, "OK", "save", "save", "profile-summary-submitBtn", "ledger-resolved-save-enabled", AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(snapshot))
}

AdvisorQuoteAscLedgerNext(ledger, result, action, actionType, target, reason, evidence := "") {
    ledger["result"] := result
    ledger["nextAction"] := action
    ledger["nextActionType"] := actionType
    ledger["nextActionTarget"] := target
    ledger["reason"] := reason
    ledger["evidence"] := evidence
    return ledger
}

AdvisorQuoteAscLedgerFail(ledger, reason, evidence := "") {
    return AdvisorQuoteAscLedgerNext(ledger, "ERROR", "fail", "fail", "", reason, evidence)
}

AdvisorQuoteAscLedgerLoopGuardHit(sameActionCount, maxSameActionCount := 2) {
    return sameActionCount > maxSameActionCount
}

AdvisorQuoteBuildAscLedgerDetail(ledger) {
    return "result=" AdvisorQuoteStatusValue(ledger, "result")
        . ", routeFamily=" AdvisorQuoteStatusValue(ledger, "routeFamily")
        . ", ascProductRouteId=" AdvisorQuoteStatusValue(ledger, "ascProductRouteId")
        . ", activeModalType=" AdvisorQuoteStatusValue(ledger, "activeModalType")
        . ", activePanelType=" AdvisorQuoteStatusValue(ledger, "activePanelType")
        . ", blockerCode=" AdvisorQuoteStatusValue(ledger, "blockerCode")
        . ", primaryDriverStatus=" AdvisorQuoteStatusValue(ledger, "primaryDriverStatus")
        . ", spousePolicy=" AdvisorQuoteStatusValue(ledger, "spousePolicy")
        . ", spouseStatus=" AdvisorQuoteStatusValue(ledger, "spouseStatus")
        . ", selectedSpouseName=" AdvisorQuoteStatusValue(ledger, "selectedSpouseName")
        . ", ascSpouseOverrideSingleEnabled=" AdvisorQuoteStatusValue(ledger, "ascSpouseOverrideSingleEnabled")
        . ", ascSpouseAgeWindowYears=" AdvisorQuoteStatusValue(ledger, "ascSpouseAgeWindowYears")
        . ", ascSpousePreferClosestAge=" AdvisorQuoteStatusValue(ledger, "ascSpousePreferClosestAge")
        . ", spouseOverrideApplied=" AdvisorQuoteStatusValue(ledger, "spouseOverrideApplied")
        . ", spouseOverrideReason=" AdvisorQuoteStatusValue(ledger, "spouseOverrideReason")
        . ", spouseCandidateCount=" AdvisorQuoteStatusValue(ledger, "spouseCandidateCount")
        . ", spouseCandidateWithinWindowCount=" AdvisorQuoteStatusValue(ledger, "spouseCandidateWithinWindowCount")
        . ", spouseCandidateSelectedText=" AdvisorQuoteStatusValue(ledger, "spouseCandidateSelectedText")
        . ", spouseCandidateSelectedAge=" AdvisorQuoteStatusValue(ledger, "spouseCandidateSelectedAge")
        . ", extraDriverCount=" AdvisorQuoteStatusValue(ledger, "extraDriverCount")
        . ", extraDriversToRemove=" AdvisorQuoteStatusValue(ledger, "extraDriversToRemove")
        . ", unresolvedDriverCount=" AdvisorQuoteStatusValue(ledger, "unresolvedDriverCount")
        . ", expectedVehicleCount=" AdvisorQuoteStatusValue(ledger, "expectedVehicleCount")
        . ", vehiclesAdded=" AdvisorQuoteStatusValue(ledger, "vehiclesAdded")
        . ", vehiclesToAdd=" AdvisorQuoteStatusValue(ledger, "vehiclesToAdd")
        . ", unresolvedVehicleCount=" AdvisorQuoteStatusValue(ledger, "unresolvedVehicleCount")
        . ", mainSavePresent=" AdvisorQuoteStatusValue(ledger, "mainSavePresent")
        . ", mainSaveEnabled=" AdvisorQuoteStatusValue(ledger, "mainSaveEnabled")
        . ", nextAction=" AdvisorQuoteStatusValue(ledger, "nextAction")
        . ", nextActionType=" AdvisorQuoteStatusValue(ledger, "nextActionType")
        . ", nextActionTarget=" AdvisorQuoteStatusValue(ledger, "nextActionTarget")
        . ", reason=" AdvisorQuoteStatusValue(ledger, "reason")
        . ", evidence=" AdvisorQuoteStatusValue(ledger, "evidence")
}

AdvisorQuoteAscModalPanelClear(value) {
    value := Trim(String(value))
    return value = "" || value = "NONE"
}

AdvisorQuoteAscSpouseOverrideSingleEnabled(db) {
    defaults := IsObject(db) && db.Has("defaults") ? db["defaults"] : Map()
    value := defaults.Has("ascSpouseOverrideSingleEnabled") ? defaults["ascSpouseOverrideSingleEnabled"] : "false"
    text := StrLower(Trim(String(value)))
    return text = "true" || text = "1" || text = "yes"
}

AdvisorQuoteAscSpouseAgeWindowYears(db) {
    defaults := IsObject(db) && db.Has("defaults") ? db["defaults"] : Map()
    value := defaults.Has("ascSpouseAgeWindowYears") ? defaults["ascSpouseAgeWindowYears"] : 14
    return RegExMatch(String(value), "^\d+$") ? Integer(value) : 14
}

AdvisorQuoteAscSpousePreferClosestAge(db) {
    defaults := IsObject(db) && db.Has("defaults") ? db["defaults"] : Map()
    value := defaults.Has("ascSpousePreferClosestAge") ? defaults["ascSpousePreferClosestAge"] : "true"
    text := StrLower(Trim(String(value)))
    return text = "true" || text = "1" || text = "yes"
}

AdvisorQuoteAscRemoveReasonCode(db) {
    defaults := IsObject(db) && db.Has("defaults") ? db["defaults"] : Map()
    if (defaults.Has("ascDriverRemoveReasonCode"))
        return Trim(String(defaults["ascDriverRemoveReasonCode"]))
    return defaults.Has("driverRemoveReasonCode") ? Trim(String(defaults["driverRemoveReasonCode"])) : "0006"
}

AdvisorQuoteAscRemoveReasonText(db) {
    defaults := IsObject(db) && db.Has("defaults") ? db["defaults"] : Map()
    return defaults.Has("ascDriverRemoveReasonText") ? Trim(String(defaults["ascDriverRemoveReasonText"])) : "This driver has their own car insurance"
}

AdvisorQuoteAscSpousePolicyName(profile, db) {
    leadMarital := AdvisorQuoteLeadMaritalStatus(profile)
    if (leadMarital = "Single" && !AdvisorQuoteAscSpouseOverrideSingleEnabled(db))
        return "single-wins"
    if (leadMarital = "Married")
        return "married-required"
    return AdvisorQuoteAscSpouseOverrideSingleEnabled(db) ? "override-enabled" : "override-disabled"
}

AdvisorQuoteAscEvaluateSpouse(profile, participantStatus, driverRows, db) {
    policy := AdvisorQuoteAscSpousePolicyName(profile, db)
    leadMarital := AdvisorQuoteLeadMaritalStatus(profile)
    leadSingleOrUnknown := leadMarital = "" || leadMarital = "Single"
    overrideAllowed := AdvisorQuoteAscSpouseOverrideSingleEnabled(db) && leadSingleOrUnknown
    selectedSpouse := AdvisorQuoteStatusValue(participantStatus, "spouseDropdownText")
    options := AdvisorQuoteAscParseSpouseOptions(AdvisorQuoteStatusValue(participantStatus, "spouseOptions"))
    primaryName := AdvisorQuoteProfileFullName(profile)
    primaryRow := AdvisorQuoteAscFindDriverRow(driverRows, primaryName)
    primaryAge := IsObject(primaryRow) ? AdvisorQuoteStatusInteger(primaryRow, "age") : 0
    ageWindow := AdvisorQuoteAscSpouseAgeWindowYears(db)
    candidates := AdvisorQuoteAscBuildSpouseCandidates(driverRows, options, primaryName, primaryAge, ageWindow)
    inWindow := candidates["inWindow"]
    selectedCandidate := AdvisorQuoteAscFindCandidateByName(inWindow, selectedSpouse)
    result := Map(
        "policy", policy,
        "status", "not_applicable",
        "selectedSpouseName", selectedSpouse,
        "reason", "",
        "evidence", candidates["summary"],
        "overrideApplied", "0",
        "overrideReason", "",
        "candidateCount", String(candidates["candidateCount"]),
        "withinWindowCount", String(inWindow.Length),
        "selectedCandidateText", "",
        "selectedCandidateAge", ""
    )

    if (leadMarital = "Single" && !AdvisorQuoteAscSpouseOverrideSingleEnabled(db))
        return result
    if (leadMarital != "Married" && !overrideAllowed)
        return result

    leadSpouseName := AdvisorQuoteLeadSpouseName(profile)
    if (leadSpouseName != "") {
        if (selectedSpouse != "" && AdvisorQuoteAscSpouseNameMatches(selectedSpouse, leadSpouseName)) {
            result["status"] := "candidate_selected"
            result["selectedSpouseName"] := selectedSpouse
            AdvisorQuoteAscSetSpouseEvalSelection(result, selectedSpouse, AdvisorQuoteAscFindDriverRow(driverRows, selectedSpouse), "exact-spouse-selected")
            return result
        }
        matches := []
        for _, option in options
            if AdvisorQuoteAscSpouseNameMatches(option["text"], leadSpouseName)
                matches.Push(option)
        if (matches.Length = 1) {
            result["status"] := "needs_select"
            result["selectedSpouseName"] := matches[1]["text"]
            result["reason"] := "exact-spouse-needs-select"
            AdvisorQuoteAscSetSpouseEvalSelection(result, matches[1]["text"], AdvisorQuoteAscFindDriverRow(driverRows, matches[1]["text"]), "exact-spouse-name")
            return result
        }
        result["status"] := (matches.Length > 1) ? "ambiguous" : "blocked"
        result["reason"] := (matches.Length > 1) ? "exact-spouse-ambiguous" : "ASC_SPOUSE_DROPDOWN_OPTION_NOT_FOUND:exact-spouse"
        return result
    }

    if IsObject(selectedCandidate) {
        result["status"] := "candidate_selected"
        result["selectedSpouseName"] := selectedSpouse
        if overrideAllowed {
            result["policy"] := "override-single-by-unique-age-window"
            result["overrideApplied"] := "1"
            result["overrideReason"] := "selected-spouse-within-age-window"
        }
        AdvisorQuoteAscSetSpouseEvalSelection(result, selectedCandidate["optionText"], selectedCandidate["row"], selectedCandidate["method"])
        return result
    }
    if (inWindow.Length = 1) {
        candidate := inWindow[1]
        if (candidate["optionText"] = "") {
            result["status"] := "blocked"
            result["reason"] := "ASC_SPOUSE_DROPDOWN_OPTION_NOT_FOUND:unique-age-window"
            AdvisorQuoteAscSetSpouseEvalSelection(result, candidate["name"], candidate["row"], candidate["method"])
            return result
        }
        result["status"] := "needs_select"
        result["selectedSpouseName"] := candidate["optionText"]
        result["reason"] := "unique-age-window-spouse-needs-select"
        if overrideAllowed {
            result["policy"] := "override-single-by-unique-age-window"
            result["overrideApplied"] := "1"
            result["overrideReason"] := "unique-advisor-candidate-within-age-window"
        }
        AdvisorQuoteAscSetSpouseEvalSelection(result, candidate["optionText"], candidate["row"], candidate["method"])
        return result
    }
    if (inWindow.Length > 1) {
        result["status"] := "ambiguous"
        result["reason"] := "age-window-spouse-ambiguous"
        return result
    }
    if overrideAllowed {
        result["status"] := "not_applicable"
        result["reason"] := "no-qualifying-spouse-candidate"
        result["overrideReason"] := "no-qualifying-spouse-candidate"
        return result
    }
    result["status"] := "blocked"
    result["reason"] := "ASC_SPOUSE_BLOCKED:no-safe-spouse-candidate"
    return result
}

AdvisorQuoteAscParticipantPolicyNeedsAction(profile, participantStatus, ledger, db) {
    leadMarital := AdvisorQuoteLeadMaritalStatus(profile)
    selectedMarital := AdvisorQuoteStatusValue(participantStatus, "maritalStatusSelected")
    if (leadMarital = "Single" && !AdvisorQuoteAscSpouseOverrideSingleEnabled(db))
        return !AdvisorQuoteAscMaritalTextMatches(selectedMarital, "Single")
    selectedSpouseName := AdvisorQuoteStatusValue(ledger, "selectedSpouseName")
    if (leadMarital = "Married" || selectedSpouseName != "") {
        if !AdvisorQuoteAscMaritalTextMatches(selectedMarital, "Married")
            return true
        return AdvisorQuoteStatusValue(ledger, "spouseStatus") = "needs_select"
    }
    if ((leadMarital = "" || leadMarital = "Single") && AdvisorQuoteAscSpouseOverrideSingleEnabled(db))
        return !AdvisorQuoteAscMaritalTextMatches(selectedMarital, "Single")
    return false
}

AdvisorQuoteAscMaritalTextMatches(actual, wanted) {
    value := AdvisorNormalizeLooseToken(actual)
    target := AdvisorNormalizeLooseToken(wanted)
    if (target = "SINGLE")
        return value = "SINGLE" || value = "UNMARRIED"
    if (target = "MARRIED")
        return value = "MARRIED"
    return value = target
}

AdvisorQuoteAscParseDriverRows(status) {
    rows := []
    summaries := AdvisorQuoteStatusValue(status, "driverSummaries")
    for _, record in AdvisorQuoteAscSplitSummaryRecords(summaries) {
        row := AdvisorQuoteAscParseSummaryRecord(record)
        if !row.Has("name")
            row["name"] := row.Has("__label") ? row["__label"] : ""
        rows.Push(row)
    }
    return rows
}

AdvisorQuoteAscParseVehicleRows(status) {
    rows := []
    summaries := AdvisorQuoteStatusValue(status, "vehicleSummaries")
    for _, record in AdvisorQuoteAscSplitSummaryRecords(summaries)
        rows.Push(AdvisorQuoteAscParseSummaryRecord(record))
    return rows
}

AdvisorQuoteAscSplitSummaryRecords(text) {
    records := []
    for _, record in StrSplit(String(text ?? ""), "||") {
        value := Trim(record)
        if (value != "")
            records.Push(value)
    }
    return records
}

AdvisorQuoteAscParseSummaryRecord(record) {
    row := Map("__label", "")
    parts := StrSplit(String(record), "|")
    if (parts.Length >= 1) {
        row["__label"] := Trim(parts[1])
        row["name"] := Trim(parts[1])
    }
    remainingParts := parts.Length - 1
    Loop remainingParts {
        part := Trim(parts[A_Index + 1])
        if RegExMatch(part, "^([^=]+)=(.*)$", &m)
            row[Trim(m[1])] := Trim(m[2])
    }
    return row
}

AdvisorQuoteAscParseSpouseOptions(optionsText) {
    options := []
    for _, record in AdvisorQuoteAscSplitSummaryRecords(optionsText) {
        value := record
        text := record
        pos := InStr(record, ":")
        if (pos > 0) {
            value := SubStr(record, 1, pos - 1)
            text := SubStr(record, pos + 1)
        }
        text := Trim(text)
        normalizedText := AdvisorNormalizeLooseToken(text)
        normalizedValue := AdvisorNormalizeLooseToken(value)
        if (text = "" || normalizedText = "" || normalizedText = "NEWDRIVER" || normalizedValue = "NEWDRIVER")
            continue
        if InStr(normalizedText, "SELECT ONE") || InStr(normalizedText, "CHOOSE") || InStr(normalizedText, "ADD ANOTHER PERSON")
            continue
        optionAge := ""
        if RegExMatch(text, "i)\bAge\s*(\d{1,3})\b", &m)
            optionAge := m[1]
        options.Push(Map("value", Trim(value), "text", text, "age", optionAge))
    }
    return options
}

AdvisorQuoteAscBuildSpouseCandidates(driverRows, spouseOptions, primaryName, primaryAge, ageWindow) {
    candidateRows := []
    inWindow := []
    summaryParts := []
    if !IsObject(driverRows)
        driverRows := []
    for _, row in driverRows {
        rowName := AdvisorQuoteStatusValue(row, "name")
        if (rowName = "" || AdvisorQuoteAscSpouseNameMatches(rowName, primaryName))
            continue
        rowAge := AdvisorQuoteStatusInteger(row, "age")
        option := AdvisorQuoteAscFindSpouseOptionForCandidate(spouseOptions, rowName, rowAge)
        ageDiff := (primaryAge > 0 && rowAge > 0) ? Abs(primaryAge - rowAge) : ""
        optionText := IsObject(option) ? option["text"] : ""
        candidateRows.Push(row)
        summaryParts.Push(rowName ":age=" rowAge ":ageDiff=" ageDiff ":option=" optionText)
        if (primaryAge > 0 && rowAge > 0 && ageDiff <= ageWindow) {
            inWindow.Push(Map(
                "name", rowName,
                "age", rowAge,
                "ageDiff", ageDiff,
                "row", row,
                "optionText", optionText,
                "optionValue", IsObject(option) ? option["value"] : "",
                "method", "age-window"
            ))
        }
    }
    return Map(
        "candidateCount", candidateRows.Length,
        "inWindow", inWindow,
        "summary", JoinArray(summaryParts, "||")
    )
}

AdvisorQuoteAscFindSpouseOptionForCandidate(spouseOptions, candidateName, candidateAge := 0) {
    matches := []
    if !IsObject(spouseOptions)
        return ""
    for _, option in spouseOptions {
        optionText := option.Has("text") ? option["text"] : ""
        if !AdvisorQuoteAscSpouseNameMatches(optionText, candidateName)
            continue
        optionAge := option.Has("age") ? Integer("0" option["age"]) : 0
        if (candidateAge > 0 && optionAge > 0 && candidateAge != optionAge)
            continue
        matches.Push(option)
    }
    return (matches.Length = 1) ? matches[1] : ""
}

AdvisorQuoteAscFindCandidateByName(candidates, name) {
    if (Trim(String(name)) = "" || !IsObject(candidates))
        return ""
    for _, candidate in candidates {
        if AdvisorQuoteAscSpouseNameMatches(candidate["name"], name) || AdvisorQuoteAscSpouseNameMatches(candidate["optionText"], name)
            return candidate
    }
    return ""
}

AdvisorQuoteAscSetSpouseEvalSelection(result, selectedText, row := "", method := "") {
    result["selectedCandidateText"] := selectedText
    result["selectedCandidateAge"] := IsObject(row) ? AdvisorQuoteStatusValue(row, "age") : ""
    if (method != "")
        result["overrideReason"] := method
}

AdvisorQuoteAscExpectedDriverNames(profile, selectedSpouseName := "") {
    names := []
    primary := AdvisorQuoteProfileFullName(profile)
    if (primary != "")
        names.Push(primary)
    if (Trim(String(selectedSpouseName)) != "")
        names.Push(Trim(String(selectedSpouseName)))
    return names
}

AdvisorQuoteAscFindDriverRow(rows, name) {
    if !IsObject(rows)
        return ""
    for _, row in rows
        if AdvisorQuoteLedgerPersonNameMatches(AdvisorQuoteStatusValue(row, "name"), name)
            return row
    return ""
}

AdvisorQuoteAscRowMatchesAnyDriver(row, expectedNames) {
    for _, name in expectedNames
        if AdvisorQuoteLedgerPersonNameMatches(AdvisorQuoteStatusValue(row, "name"), name)
            return true
    return false
}

AdvisorQuoteNormalizeLedgerPersonName(value) {
    text := StrUpper(Trim(String(value ?? "")))
    text := RegExReplace(text, "\bAGE\s+\d+\b", " ")
    text := RegExReplace(text, "\b(ADD|REMOVE|EDIT|ADDED|QUOTE|TO|DO|YOU|WANT|DRIVER|SPOUSE)\b", " ")
    text := RegExReplace(text, "[^A-Z0-9 ]", " ")
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

AdvisorQuoteLedgerPersonNameMatches(actual, expected) {
    a := AdvisorQuoteNormalizeLedgerPersonName(actual)
    e := AdvisorQuoteNormalizeLedgerPersonName(expected)
    return a != "" && e != "" && (a = e || InStr(a, e) > 0 || InStr(e, a) > 0)
}

AdvisorQuoteAscNameTokens(value) {
    tokens := []
    normalized := AdvisorQuoteNormalizeLedgerPersonName(value)
    for _, token in StrSplit(normalized, " ") {
        token := Trim(token)
        if (token != "")
            tokens.Push(token)
    }
    return tokens
}

AdvisorQuoteAscSpouseNameMatches(actual, expected) {
    a := AdvisorQuoteNormalizeLedgerPersonName(actual)
    e := AdvisorQuoteNormalizeLedgerPersonName(expected)
    if (a = "" || e = "")
        return false
    if (a = e)
        return true
    aTokens := AdvisorQuoteAscNameTokens(a)
    eTokens := AdvisorQuoteAscNameTokens(e)
    if (aTokens.Length < 2 || eTokens.Length < 2)
        return false
    if (InStr(a, e) > 0 || InStr(e, a) > 0)
        return true
    return aTokens[1] = eTokens[1] && aTokens[aTokens.Length] = eTokens[eTokens.Length]
}

AdvisorQuoteVerifyAscLedgerRowActionProgress(kind, action, beforeSnapshot, result, db, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    outcome := AdvisorQuoteStatusValue(result, "result")
    if (outcome = "OK")
        return true
    if (outcome != "PARTIAL") {
        failureReason := (kind = "driver") ? "ASC_DRIVER_ROW_VERIFY_FAILED: " : "ASC_VEHICLE_ROW_VERIFY_FAILED: "
        failureReason .= (kind = "driver") ? AdvisorQuoteBuildAscDriverReconcileDetail(result) : AdvisorQuoteBuildAscVehicleReconcileDetail(result)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-row-action-failed")
        return false
    }
    if !SafeSleep(db["timeouts"]["pollMs"]) {
        failureReason := "ASC_LEDGER_ROW_ACTION_WAIT_FAILED"
        return false
    }
    afterSnapshot := AdvisorQuoteGetAscDriversVehiclesSnapshot()
    afterModal := AdvisorQuoteStatusValue(afterSnapshot, "activeModalType")
    afterPanel := AdvisorQuoteStatusValue(afterSnapshot, "activePanelType")
    if !AdvisorQuoteAscModalPanelClear(afterModal) || !AdvisorQuoteAscModalPanelClear(afterPanel)
        return true
    if (kind = "driver" && AdvisorQuoteStatusInteger(afterSnapshot, "unresolvedDriverCount") < AdvisorQuoteStatusInteger(beforeSnapshot, "unresolvedDriverCount"))
        return true
    if (kind = "vehicle" && AdvisorQuoteStatusInteger(afterSnapshot, "unresolvedVehicleCount") < AdvisorQuoteStatusInteger(beforeSnapshot, "unresolvedVehicleCount"))
        return true
    if (kind = "vehicle" && AdvisorQuoteStatusInteger(afterSnapshot, "addedVehicleCount") > AdvisorQuoteStatusInteger(beforeSnapshot, "addedVehicleCount"))
        return true
    failureReason := (kind = "driver") ? "ASC_DRIVER_ROW_VERIFY_FAILED" : "ASC_VEHICLE_ROW_VERIFY_FAILED"
    failureReason .= ": action=" action ", before=" AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(beforeSnapshot) ", after=" AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(afterSnapshot)
    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-ledger-row-action-no-progress")
    return false
}

AdvisorQuoteHandleAscRemoveDriverModalLedger(profile, db, beforeSnapshot, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    reasonCode := AdvisorQuoteAscRemoveReasonCode(db)
    reasonText := AdvisorQuoteAscRemoveReasonText(db)
    selectStatus := Map()
    if !AdvisorQuoteSelectRemoveReason(reasonCode, &selectStatus, reasonText) {
        result := AdvisorQuoteStatusValue(selectStatus, "result")
        failureReason := (result = "NO_REASON") ? "ASC_REMOVE_REASON_NOT_FOUND" : "ASC_REMOVE_REASON_SELECT_FAILED"
        failureReason .= ": reasonCode=" reasonCode ", result=" result
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-remove-reason-failed")
        return false
    }
    if (AdvisorQuoteStatusValue(selectStatus, "reasonSelected") != "1") {
        failureReason := "ASC_REMOVE_REASON_SELECT_FAILED: reasonCode=" reasonCode ", " AdvisorQuoteBuildRemoveReasonStatusDetail(selectStatus)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-remove-reason-not-selected")
        return false
    }
    if !AdvisorQuoteClickById(db["selectors"]["removeParticipantSaveId"], db["timeouts"]["actionMs"]) {
        failureReason := "ASC_REMOVE_DRIVER_SAVE_DID_NOT_COMMIT: remove save click failed."
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-remove-save-click-failed")
        return false
    }
    if !SafeSleep(db["timeouts"]["pollMs"]) {
        failureReason := "ASC_REMOVE_DRIVER_SAVE_DID_NOT_COMMIT: wait interrupted."
        return false
    }
    afterSnapshot := AdvisorQuoteGetAscDriversVehiclesSnapshot()
    if (AdvisorQuoteStatusValue(afterSnapshot, "activeModalType") != "ASC_REMOVE_DRIVER_MODAL")
        return true
    if (AdvisorQuoteStatusInteger(afterSnapshot, "unresolvedDriverCount") < AdvisorQuoteStatusInteger(beforeSnapshot, "unresolvedDriverCount"))
        return true
    failureReason := "ASC_REMOVE_DRIVER_SAVE_DID_NOT_COMMIT: before=" AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(beforeSnapshot) ", after=" AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(afterSnapshot)
    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-remove-save-did-not-commit")
    return false
}

AdvisorQuoteHandleAscInlineParticipantPanelLedger(profile, db, beforeSnapshot, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    if !AdvisorQuoteFillParticipantModal(profile, db) {
        participantStatus := AdvisorQuoteGetAscParticipantDetailStatus()
        statusResult := AdvisorQuoteStatusValue(participantStatus, "result")
        if (statusResult = "ASC_INLINE_PARTICIPANT_SAVE_DISABLED")
            failureReason := "ASC_INLINE_PARTICIPANT_SAVE_DISABLED: " AdvisorQuoteBuildAscParticipantDetailStatusDetail(participantStatus)
        else
            failureReason := "ASC_INLINE_PARTICIPANT_SAVE_FAILED: fill failed. " AdvisorQuoteBuildAscParticipantDetailStatusDetail(participantStatus)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-inline-fill-failed")
        return false
    }
    participantStatus := AdvisorQuoteGetAscParticipantDetailStatus()
    if (AdvisorQuoteStatusValue(participantStatus, "saveEnabled") != "1" && AdvisorQuoteStatusValue(participantStatus, "saveButtonEnabled") != "1") {
        failureReason := "ASC_INLINE_PARTICIPANT_SAVE_DISABLED: " AdvisorQuoteBuildAscParticipantDetailStatusDetail(participantStatus)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-inline-save-disabled")
        return false
    }
    if !AdvisorQuoteClickById(db["selectors"]["participantSaveId"], db["timeouts"]["actionMs"]) {
        failureReason := "ASC_INLINE_PARTICIPANT_SAVE_FAILED: save click failed. " AdvisorQuoteBuildAscParticipantDetailStatusDetail(participantStatus)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-inline-save-click-failed")
        return false
    }
    if !SafeSleep(db["timeouts"]["pollMs"]) {
        failureReason := "ASC_INLINE_PARTICIPANT_SAVE_FAILED: wait interrupted."
        return false
    }
    afterSnapshot := AdvisorQuoteGetAscDriversVehiclesSnapshot()
    if (AdvisorQuoteStatusValue(afterSnapshot, "activePanelType") != "ASC_INLINE_PARTICIPANT_PANEL" && AdvisorQuoteStatusValue(afterSnapshot, "activeModalType") != "ASC_INLINE_PARTICIPANT_PANEL")
        return true
    participantStatus := AdvisorQuoteGetAscParticipantDetailStatus()
    if AdvisorQuoteAscParticipantRequiredSatisfied(participantStatus)
        return true
    failureReason := "ASC_INLINE_PARTICIPANT_VERIFY_FAILED: before=" AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(beforeSnapshot) ", after=" AdvisorQuoteBuildAscDriversVehiclesSnapshotDetail(afterSnapshot) ", participant=" AdvisorQuoteBuildAscParticipantDetailStatusDetail(participantStatus)
    failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-inline-verify-failed")
    return false
}

AdvisorQuoteAscParticipantRequiredSatisfied(participantStatus) {
    result := AdvisorQuoteStatusValue(participantStatus, "result")
    if (result != "FOUND" && result != "READY")
        return false
    if (AdvisorQuoteStatusValue(participantStatus, "missingRequiredControls") != "")
        return false
    if (AdvisorQuoteStatusValue(participantStatus, "ageFirstLicensedPresent") = "1" && AdvisorQuoteStatusValue(participantStatus, "ageFirstLicensedFilled") != "1")
        return false
    if (AdvisorQuoteStatusValue(participantStatus, "ownershipQuestionPresent") = "1" && AdvisorQuoteStatusValue(participantStatus, "ownershipSelected") != "1")
        return false
    return true
}

AdvisorQuoteHandleAscVehicleModalLedger(profile, db, beforeSnapshot, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    if !AdvisorQuoteFillVehicleModal(profile, db) {
        failureReason := "ASC_VEHICLE_ROW_VERIFY_FAILED: vehicle modal fill failed."
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-vehicle-modal-fill-failed")
        return false
    }
    if !AdvisorQuoteClickById(db["selectors"]["addAssetSaveId"], db["timeouts"]["actionMs"]) {
        failureReason := "ASC_VEHICLE_ROW_VERIFY_FAILED: vehicle modal save click failed."
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-vehicle-modal-save-click-failed")
        return false
    }
    waitArgs := Map("addAssetSaveId", db["selectors"]["addAssetSaveId"])
    if !AdvisorQuoteWaitForCondition("add_asset_modal_closed", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
        failureReason := "ASC_VEHICLE_ROW_VERIFY_FAILED: vehicle modal did not close."
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-vehicle-modal-close-failed")
        return false
    }
    return true
}

AdvisorQuoteAscSaveAndContinueFromLedger(ledger, db, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    if (AdvisorQuoteStatusValue(ledger, "mainSavePresent") != "1") {
        failureReason := "ASC_SAVE_DISABLED_AFTER_LEDGER_RESOLUTION: main save missing. " AdvisorQuoteBuildAscLedgerDetail(ledger)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-save-missing")
        return false
    }
    if (AdvisorQuoteStatusValue(ledger, "mainSaveEnabled") != "1") {
        failureReason := "ASC_SAVE_DISABLED_AFTER_LEDGER_RESOLUTION: main save disabled. " AdvisorQuoteBuildAscLedgerDetail(ledger)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-save-disabled")
        return false
    }
    if !AdvisorQuoteClickById(db["selectors"]["driverVehicleContinueId"], db["timeouts"]["actionMs"]) {
        failureReason := "ASC_SAVE_DISABLED_AFTER_LEDGER_RESOLUTION: main save click failed. " AdvisorQuoteBuildAscLedgerDetail(ledger)
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-save-click-failed")
        return false
    }
    AdvisorQuoteAppendLog("ASC_LEDGER_SAVE_AND_CONTINUE_CLICKED", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscLedgerDetail(ledger))
    return true
}

AdvisorQuoteReconcileAscDrivers(profile, db, selectedSpouseName := "") {
    Loop 8 {
        status := AdvisorQuoteGetAscDriverRowsStatus()
        AdvisorQuoteAppendLog("ASC_DRIVER_ROWS_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriverRowsStatusDetail(status))
        if (AdvisorQuoteStatusValue(status, "result") = "NONE")
            return true

        result := AdvisorQuoteRunAscDriverReconcile(profile, selectedSpouseName)
        AdvisorQuoteAppendLog("ASC_DRIVER_RECONCILE_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriverReconcileDetail(result))
        outcome := AdvisorQuoteStatusValue(result, "result")
        if (outcome = "OK")
            return true
        if AdvisorQuoteIsStateInList(outcome, ["AMBIGUOUS", "FAILED", "ERROR", ""])
            return false

        clickedCount := AdvisorQuoteStatusInteger(result, "addClickedCount") + AdvisorQuoteStatusInteger(result, "removeClickedCount")
        if (clickedCount <= 0)
            return false
        if !AdvisorQuoteHandleOpenModals(profile, db, 15000)
            return false
        if !SafeSleep(db["timeouts"]["pollMs"])
            return false
    }
    AdvisorQuoteAppendLog("ASC_DRIVER_RECONCILE_FAILED", AdvisorQuoteGetLastStep(), "reason=max-iterations")
    return false
}

AdvisorQuoteGetAscDriverRowsStatus() {
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("asc_driver_rows_status", Map(), 2, 120))
}

AdvisorQuoteRunAscDriverReconcile(profile, selectedSpouseName := "") {
    args := Map(
        "primaryName", AdvisorQuoteProfileFullName(profile),
        "primaryAge", "",
        "leadMaritalStatus", AdvisorQuoteLeadMaritalStatus(profile),
        "selectedSpouseName", selectedSpouseName,
        "expectedDriverNames", AdvisorQuoteExpectedDriverNamesText(profile, selectedSpouseName)
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("asc_reconcile_driver_rows", args))
}

AdvisorQuoteBuildAscDriverRowsStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", driverCount=" AdvisorQuoteStatusValue(status, "driverCount")
        . ", unresolvedDriverCount=" AdvisorQuoteStatusValue(status, "unresolvedDriverCount")
        . ", addedDriverCount=" AdvisorQuoteStatusValue(status, "addedDriverCount")
        . ", removedDriverCount=" AdvisorQuoteStatusValue(status, "removedDriverCount")
        . ", saveButtonEnabled=" AdvisorQuoteStatusValue(status, "saveButtonEnabled")
        . ", driverSummaries=" AdvisorQuoteStatusValue(status, "driverSummaries")
}

AdvisorQuoteBuildAscDriverReconcileDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", primaryAction=" AdvisorQuoteStatusValue(status, "primaryAction")
        . ", spouseAction=" AdvisorQuoteStatusValue(status, "spouseAction")
        . ", removedDrivers=" AdvisorQuoteStatusValue(status, "removedDrivers")
        . ", unresolvedDrivers=" AdvisorQuoteStatusValue(status, "unresolvedDrivers")
        . ", addClickedCount=" AdvisorQuoteStatusValue(status, "addClickedCount")
        . ", removeClickedCount=" AdvisorQuoteStatusValue(status, "removeClickedCount")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
}

AdvisorQuoteReconcileAscVehicles(profile, db) {
    policy := AdvisorQuoteClassifyAscVehicles(profile)
    AdvisorQuoteAppendLog(
        "ASC_VEHICLE_POLICY",
        AdvisorQuoteGetLastStep(),
        "completeVehicleCount=" policy["completeVehicles"].Length
            . ", partialVehicleCount=" policy["partialYearMakeVehicles"].Length
            . ", deferredVehicleCount=" policy["deferredVehicles"].Length
            . ", completeVehicles=" AdvisorQuoteVehicleListSummary(policy["completeVehicles"])
            . ", partialVehicles=" AdvisorQuoteVehicleListSummary(policy["partialYearMakeVehicles"])
            . ", deferredVehicles=" AdvisorQuoteVehicleListSummary(policy["deferredVehicles"])
    )

    Loop 10 {
        status := AdvisorQuoteGetAscVehicleRowsStatus()
        AdvisorQuoteAppendLog("ASC_VEHICLE_ROWS_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscVehicleRowsStatusDetail(status))
        result := AdvisorQuoteRunAscVehicleReconcile(policy)
        AdvisorQuoteAppendLog("ASC_VEHICLE_RECONCILE_RESULT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscVehicleReconcileDetail(result))
        outcome := AdvisorQuoteStatusValue(result, "result")
        if (outcome = "OK")
            return true
        if AdvisorQuoteIsStateInList(outcome, ["AMBIGUOUS", "FAILED", "ERROR", ""])
            return false

        clickedEvidence := AdvisorQuoteStatusValue(result, "addedVehicles")
            . AdvisorQuoteStatusValue(result, "removedVehicles")
            . AdvisorQuoteStatusValue(result, "promotedPartialVehicles")
        if (Trim(clickedEvidence) = "" && AdvisorQuoteStatusValue(result, "method") != "partial-vehicle-unique-vin-add")
            return false
        if !AdvisorQuoteHandleOpenModals(profile, db, 15000)
            return false
        if !SafeSleep(db["timeouts"]["pollMs"])
            return false
    }
    AdvisorQuoteAppendLog("ASC_VEHICLE_RECONCILE_FAILED", AdvisorQuoteGetLastStep(), "reason=max-iterations")
    return false
}

AdvisorQuoteGetAscVehicleRowsStatus() {
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("asc_vehicle_rows_status", Map(), 2, 120))
}

AdvisorQuoteRunAscVehicleReconcile(policy) {
    args := Map(
        "expectedVehicles", AdvisorQuoteBuildExpectedVehiclesArgList(policy["completeVehicles"]),
        "partialVehicles", AdvisorQuoteBuildAscPartialVehiclesArgList(policy["partialYearMakeVehicles"])
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("asc_reconcile_vehicle_rows", args))
}

AdvisorQuoteBuildAscVehicleRowsStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", vehicleCount=" AdvisorQuoteStatusValue(status, "vehicleCount")
        . ", unresolvedVehicleCount=" AdvisorQuoteStatusValue(status, "unresolvedVehicleCount")
        . ", addedVehicleCount=" AdvisorQuoteStatusValue(status, "addedVehicleCount")
        . ", confirmedOrAddedVehicleCount=" AdvisorQuoteStatusValue(status, "confirmedOrAddedVehicleCount")
        . ", saveButtonEnabled=" AdvisorQuoteStatusValue(status, "saveButtonEnabled")
        . ", vehicleSummaries=" AdvisorQuoteStatusValue(status, "vehicleSummaries")
}

AdvisorQuoteBuildAscVehicleReconcileDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", addedVehicles=" AdvisorQuoteStatusValue(status, "addedVehicles")
        . ", removedVehicles=" AdvisorQuoteStatusValue(status, "removedVehicles")
        . ", promotedPartialVehicles=" AdvisorQuoteStatusValue(status, "promotedPartialVehicles")
        . ", deferredPartialVehicles=" AdvisorQuoteStatusValue(status, "deferredPartialVehicles")
        . ", confirmedVehicleCount=" AdvisorQuoteStatusValue(status, "confirmedVehicleCount")
        . ", unresolvedVehicles=" AdvisorQuoteStatusValue(status, "unresolvedVehicles")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
}

AdvisorQuoteAscSaveAndContinueIfReady(profile, db) {
    participantStatus := AdvisorQuoteGetAscParticipantDetailStatus()
    driverStatus := AdvisorQuoteGetAscDriverRowsStatus()
    vehicleStatus := AdvisorQuoteGetAscVehicleRowsStatus()
    AdvisorQuoteAppendLog("ASC_SAVE_GATE_PARTICIPANT_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscParticipantDetailStatusDetail(participantStatus))
    AdvisorQuoteAppendLog("ASC_SAVE_GATE_DRIVER_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscDriverRowsStatusDetail(driverStatus))
    AdvisorQuoteAppendLog("ASC_SAVE_GATE_VEHICLE_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildAscVehicleRowsStatusDetail(vehicleStatus))

    unresolvedDrivers := AdvisorQuoteStatusInteger(driverStatus, "unresolvedDriverCount")
    unresolvedVehicles := AdvisorQuoteStatusInteger(vehicleStatus, "unresolvedVehicleCount")
    confirmedOrAddedVehicles := AdvisorQuoteStatusInteger(vehicleStatus, "confirmedOrAddedVehicleCount")
    saveEnabled := AdvisorQuoteStatusValue(participantStatus, "saveButtonEnabled")

    if (unresolvedDrivers > 0 || unresolvedVehicles > 0 || confirmedOrAddedVehicles < 1 || saveEnabled != "1") {
        AdvisorQuoteAppendLog(
            "ASC109_SAVE_DISABLED_AFTER_RECONCILIATION",
            AdvisorQuoteGetLastStep(),
            "unresolvedDrivers=" unresolvedDrivers
                . ", unresolvedVehicles=" unresolvedVehicles
                . ", confirmedOrAddedVehicles=" confirmedOrAddedVehicles
                . ", saveButtonEnabled=" saveEnabled
        )
        return false
    }

    if !AdvisorQuoteClickById(db["selectors"]["driverVehicleContinueId"], db["timeouts"]["actionMs"])
        return false
    AdvisorQuoteAppendLog("ASC_SAVE_AND_CONTINUE_CLICKED", AdvisorQuoteGetLastStep(), "result=OK")
    return true
}

AdvisorQuoteResolveDrivers(profile, db) {
    leadSlug := AdvisorQuoteToSlug(profile["person"]["fullName"])
    if (leadSlug = "")
        leadSlug := AdvisorQuoteToSlug(profile["person"]["firstName"] . " " . profile["person"]["lastName"])

    driverSlugs := AdvisorQuoteListDriverSlugs()
    if (driverSlugs.Length = 0)
        return true

    keep := Map()
    keep[leadSlug] := true

    if (driverSlugs.Length = 2) {
        for _, slug in driverSlugs
            if (slug != leadSlug)
                keep[slug] := true
    }

    for _, slug in driverSlugs {
        if StopRequested()
            return false
        if (slug = "")
            continue
        if keep.Has(slug) {
            if !AdvisorQuoteEnsureDriverAdded(slug, profile, db)
                return false
        } else {
            if !AdvisorQuoteRemoveDriverWithOwnInsuranceReason(slug, profile, db)
                return false
        }
    }

    return true
}

AdvisorQuoteListDriverSlugs() {
    result := AdvisorQuoteRunOp("list_driver_slugs", Map())
    if (Trim(result) = "")
        return []
    return StrSplit(result, "||")
}

AdvisorQuoteEnsureDriverAdded(slug, profile, db) {
    if AdvisorQuoteDriverIsAlreadyAdded(slug)
        return AdvisorQuoteHandleOpenModals(profile, db, 10000)

    addIds := [slug "-addToQuote", slug "-add"]
    for _, addId in addIds {
        if AdvisorQuoteClickById(addId, db["timeouts"]["actionMs"]) {
            if !AdvisorQuoteHandleOpenModals(profile, db, 15000)
                return false
            return true
        }
    }
    return true
}

AdvisorQuoteDriverIsAlreadyAdded(slug) {
    return AdvisorQuoteRunOp("driver_is_already_added", Map("slug", slug)) = "1"
}

AdvisorQuoteRemoveDriverWithOwnInsuranceReason(slug, profile, db) {
    if !AdvisorQuoteClickById(slug "-remove", db["timeouts"]["actionMs"])
        return true

    if !AdvisorQuoteHandleOpenModals(profile, db, 15000)
        return false
    return true
}

AdvisorQuoteResolveVehicles(profile, db) {
    vehicles := profile["vehicles"]
    if (vehicles.Length = 0)
        return true

    addedAny := false
    for _, vehicle in vehicles {
        if StopRequested()
            return false

        if AdvisorQuoteVehicleMarkedAdded(vehicle) {
            addedAny := true
            continue
        }

        addButtonId := AdvisorQuoteFindVehicleAddButton(vehicle)
        if (addButtonId = "")
            continue

        if AdvisorQuoteClickById(addButtonId, db["timeouts"]["actionMs"]) {
            if !AdvisorQuoteHandleOpenModals(profile, db, 15000)
                return false
            addedAny := true
        }
    }

    return addedAny || AdvisorQuoteAnyVehicleAlreadyAdded()
}

AdvisorQuoteVehicleMarkedAdded(vehicle) {
    args := Map(
        "year", vehicle["year"],
        "make", vehicle["make"],
        "model", vehicle["model"]
    )
    return AdvisorQuoteRunOp("vehicle_marked_added", args) = "1"
}

AdvisorQuoteFindVehicleAddButton(vehicle) {
    result := AdvisorQuoteRunOp("find_vehicle_add_button", AdvisorQuoteBuildVehicleJsArgs(vehicle))
    if (result = "AMBIGUOUS") {
        AdvisorQuoteAppendLog("VEHICLE_ADD_AMBIGUOUS", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"])
        return ""
    }
    return result
}

AdvisorQuoteAnyVehicleAlreadyAdded() {
    return AdvisorQuoteRunOp("any_vehicle_already_added", Map()) = "1"
}

AdvisorQuoteHandleOpenModals(profile, db, timeoutMs := 15000) {
    start := A_TickCount
    finalResult := false
    finalReason := "timeout"
    lastModalType := "none"
    lastAction := "none"
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
        {
            finalReason := "stop-requested"
            break
        }

        if AdvisorQuoteModalExists(db["selectors"]["participantSaveId"]) {
            lastModalType := "participant"
            AdvisorQuoteAppendLog("MODAL_DETECTED", AdvisorQuoteGetLastStep(), "type=" lastModalType)
            lastAction := "fill_participant_modal"
            AdvisorQuoteAppendLog("MODAL_ACTION", AdvisorQuoteGetLastStep(), "type=" lastModalType ", action=" lastAction)
            if !AdvisorQuoteFillParticipantModal(profile, db)
            {
                finalReason := "participant-fill-failed"
                break
            }
            lastAction := "click_participant_save"
            AdvisorQuoteAppendLog("MODAL_ACTION", AdvisorQuoteGetLastStep(), "type=" lastModalType ", action=" lastAction)
            if !AdvisorQuoteClickById(db["selectors"]["participantSaveId"], db["timeouts"]["actionMs"])
            {
                finalReason := "participant-save-click-failed"
                break
            }
            if !SafeSleep(350)
            {
                finalReason := "participant-save-wait-failed"
                break
            }
            continue
        }

        if AdvisorQuoteModalExists(db["selectors"]["removeParticipantSaveId"]) {
            lastModalType := "remove_participant"
            AdvisorQuoteAppendLog("MODAL_DETECTED", AdvisorQuoteGetLastStep(), "type=" lastModalType)
            lastAction := "select_remove_reason"
            AdvisorQuoteAppendLog("MODAL_ACTION", AdvisorQuoteGetLastStep(), "type=" lastModalType ", action=" lastAction)
            if !AdvisorQuoteSelectRemoveReason(db["defaults"]["driverRemoveReasonCode"])
            {
                finalReason := "remove-reason-select-failed"
                break
            }
            lastAction := "click_remove_participant_save"
            AdvisorQuoteAppendLog("MODAL_ACTION", AdvisorQuoteGetLastStep(), "type=" lastModalType ", action=" lastAction)
            if !AdvisorQuoteClickById(db["selectors"]["removeParticipantSaveId"], db["timeouts"]["actionMs"])
            {
                finalReason := "remove-participant-save-click-failed"
                break
            }
            if !SafeSleep(350)
            {
                finalReason := "remove-participant-save-wait-failed"
                break
            }
            continue
        }

        if AdvisorQuoteModalExists(db["selectors"]["addAssetSaveId"]) {
            lastModalType := "add_asset"
            AdvisorQuoteAppendLog("MODAL_DETECTED", AdvisorQuoteGetLastStep(), "type=" lastModalType)
            lastAction := "fill_vehicle_modal"
            AdvisorQuoteAppendLog("MODAL_ACTION", AdvisorQuoteGetLastStep(), "type=" lastModalType ", action=" lastAction)
            if !AdvisorQuoteFillVehicleModal(profile, db)
            {
                finalReason := "add-asset-fill-failed"
                break
            }
            lastAction := "click_add_asset_save"
            AdvisorQuoteAppendLog("MODAL_ACTION", AdvisorQuoteGetLastStep(), "type=" lastModalType ", action=" lastAction)
            if !AdvisorQuoteClickById(db["selectors"]["addAssetSaveId"], db["timeouts"]["actionMs"])
            {
                finalReason := "add-asset-save-click-failed"
                break
            }
            lastAction := "wait_add_asset_modal_closed"
            AdvisorQuoteAppendLog("MODAL_ACTION", AdvisorQuoteGetLastStep(), "type=" lastModalType ", action=" lastAction)
            waitArgs := Map("addAssetSaveId", db["selectors"]["addAssetSaveId"])
            if !AdvisorQuoteWaitForCondition("add_asset_modal_closed", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
                finalReason := "add-asset-close-wait-failed"
                break
            }
            continue
        }

        finalResult := true
        finalReason := (lastModalType = "none") ? "no-open-modal-detected" : "modal-sequence-cleared"
        break
    }
    elapsedMs := A_TickCount - start
    if (!finalResult && (finalReason = "timeout")) {
        AdvisorQuoteAppendLog(
            "MODAL_TIMEOUT",
            AdvisorQuoteGetLastStep(),
            "timeoutMs=" timeoutMs ", elapsedMs=" elapsedMs ", lastType=" lastModalType ", lastAction=" lastAction
        )
    }
    AdvisorQuoteAppendLog(
        "MODAL_RESULT",
        AdvisorQuoteGetLastStep(),
        "result=" (finalResult ? "true" : "false") ", reason=" finalReason ", elapsedMs=" elapsedMs ", lastType=" lastModalType ", lastAction=" lastAction
    )
    return finalResult
}

AdvisorQuoteModalExists(saveButtonId) {
    return AdvisorQuoteRunOp("modal_exists", Map("saveButtonId", saveButtonId)) = "1"
}

AdvisorQuoteFillParticipantModal(profile, db) {
    person := profile["person"]
    leadGender := StrUpper(Trim(String(person["gender"])))
    oppositeGenderValue := (leadGender = "F") ? "1002" : "1001"
    propertyOwnership := AdvisorQuoteResolveParticipantPropertyOwnership(profile, db)
    args := Map(
        "ageFirstLicensed", db["defaults"]["ageFirstLicensed"],
        "email", person["email"],
        "military", db["defaults"]["military"],
        "violations", db["defaults"]["violations"],
        "defensiveDriving", db["defaults"]["defensiveDriving"],
        "propertyOwnership", propertyOwnership,
        "oppositeGenderValue", oppositeGenderValue,
        "leadMaritalStatus", AdvisorQuoteLeadMaritalStatus(profile),
        "leadSpouseName", AdvisorQuoteLeadSpouseName(profile),
        "primaryName", AdvisorQuoteProfileFullName(profile),
        "ascSpouseOverrideSingleEnabled", AdvisorQuoteAscSpouseOverrideSingleEnabled(db) ? "1" : "0",
        "ascSpouseAgeWindowYears", AdvisorQuoteAscSpouseAgeWindowYears(db),
        "ascSpousePreferClosestAge", AdvisorQuoteAscSpousePreferClosestAge(db) ? "1" : "0",
        "maxSpouseAgeDifference", AdvisorQuoteAscSpouseAgeWindowYears(db),
        "spouseSelectId", db["texts"]["spouseSelectId"]
    )
    raw := AdvisorQuoteRunOp("fill_participant_modal", args)
    status := AdvisorQuoteParseKeyValueLines(raw)
    if (status.Count = 0)
        return raw = "OK"
    AdvisorQuoteAppendLog(
        "PARTICIPANT_MODAL_FILL",
        AdvisorQuoteGetLastStep(),
        "result=" AdvisorQuoteStatusValue(status, "result")
            . ", method=" AdvisorQuoteStatusValue(status, "method")
            . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
            . ", ageFirstLicensedSet=" AdvisorQuoteStatusValue(status, "ageFirstLicensedSet")
            . ", emailSet=" AdvisorQuoteStatusValue(status, "emailSet")
            . ", militarySet=" AdvisorQuoteStatusValue(status, "militarySet")
            . ", violationsSet=" AdvisorQuoteStatusValue(status, "violationsSet")
            . ", defensiveDrivingSet=" AdvisorQuoteStatusValue(status, "defensiveDrivingSet")
            . ", propertyOwnershipSet=" AdvisorQuoteStatusValue(status, "propertyOwnershipSet")
            . ", genderFallbackSet=" AdvisorQuoteStatusValue(status, "genderFallbackSet")
            . ", spouseSelectionSet=" AdvisorQuoteStatusValue(status, "spouseSelectionSet")
    )
    return AdvisorQuoteStatusValue(status, "result") = "OK"
}

AdvisorQuoteResolveParticipantPropertyOwnership(profile, db) {
    residence := (IsObject(profile) && profile.Has("residence")) ? profile["residence"] : Map()
    if (IsObject(residence) && residence.Has("participantPropertyOwnershipKey")) {
        key := Trim(String(residence["participantPropertyOwnershipKey"]))
        if (key = "RENT")
            return db["defaults"]["propertyOwnershipRent"]
    }
    return db["defaults"]["propertyOwnershipOwnHome"]
}

AdvisorQuoteSelectRemoveReason(reasonCode, &status := "", reasonText := "") {
    args := Map("reasonCode", reasonCode)
    if (Trim(String(reasonText)) != "")
        args["reasonText"] := reasonText
    raw := AdvisorQuoteRunOp("select_remove_reason", args)
    status := AdvisorQuoteParseKeyValueLines(raw)
    if (status.Count = 0) {
        status := Map(
            "result", raw,
            "reasonSelected", raw = "OK" ? "1" : "0",
            "reasonCode", reasonCode,
            "method", "legacy"
        )
    }
    AdvisorQuoteAppendLog("ASC_REMOVE_REASON_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildRemoveReasonStatusDetail(status))
    return AdvisorQuoteStatusValue(status, "result") = "OK" && AdvisorQuoteStatusValue(status, "reasonSelected") = "1"
}

AdvisorQuoteBuildRemoveReasonStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", reasonCode=" AdvisorQuoteStatusValue(status, "reasonCode")
        . ", reasonSelected=" AdvisorQuoteStatusValue(status, "reasonSelected")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", method=" AdvisorQuoteStatusValue(status, "method")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
}

AdvisorQuoteFillVehicleModal(profile, db) {
    threshold := Integer(db["defaults"]["vehicleFinanceYearThreshold"])
    raw := AdvisorQuoteRunOp("fill_vehicle_modal", Map("threshold", threshold))
    status := AdvisorQuoteParseKeyValueLines(raw)
    if (status.Count = 0)
        return raw = "OK"
    AdvisorQuoteAppendLog(
        "VEHICLE_MODAL_FILL",
        AdvisorQuoteGetLastStep(),
        "result=" AdvisorQuoteStatusValue(status, "result")
            . ", method=" AdvisorQuoteStatusValue(status, "method")
            . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
            . ", detectedYear=" AdvisorQuoteStatusValue(status, "detectedYear")
            . ", garagingAddressSameAsOtherClicked=" AdvisorQuoteStatusValue(status, "garagingAddressSameAsOtherClicked")
            . ", purchaseDateFalseClicked=" AdvisorQuoteStatusValue(status, "purchaseDateFalseClicked")
            . ", ownershipClicked=" AdvisorQuoteStatusValue(status, "ownershipClicked")
    )
    return AdvisorQuoteStatusValue(status, "result") = "OK"
}

AdvisorQuoteWaitForContinueEnabled(buttonId, timeoutMs) {
    return AdvisorQuoteWaitForCondition("continue_enabled", timeoutMs, 300, Map("buttonId", buttonId))
}

AdvisorQuoteHandleIncidentsIfPresent(db) {
    if !AdvisorQuoteIsIncidentsPage(db)
        return true

    args := Map(
        "reasonText", db["defaults"]["incidentReasonText"],
        "incidentContinueId", db["selectors"]["incidentContinueId"]
    )
    result := AdvisorQuoteRunOp("handle_incidents", args)
    if (result != "OK")
        return false

    return AdvisorQuoteWaitForCondition("incidents_done", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], AdvisorQuoteAscWaitArgs(db))
}

AdvisorQuoteWaitForQuoteLanding(db) {
    args := Map("ascProductContains", db["urls"]["ascProductContains"])
    return AdvisorQuoteWaitForCondition("quote_landing", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], args)
}

AdvisorQuoteToSlug(text) {
    slug := StrLower(Trim(String(text ?? "")))
    slug := RegExReplace(slug, "[^a-z0-9]+", "-")
    slug := RegExReplace(slug, "^-+|-+$", "")
    return slug
}

AdvisorQuoteIsDuplicatePage(db) {
    args := Map("duplicateHeading", db["texts"]["duplicateHeading"])
    return AdvisorQuoteWaitForCondition("is_duplicate", 350, 150, args)
}

AdvisorQuoteIsOnRapportPage(db) {
    args := Map("rapportContains", db["urls"]["rapportContains"])
    return AdvisorQuoteWaitForCondition("is_rapport", 350, 150, args)
}

AdvisorQuoteIsOnSelectProductPage(db) {
    args := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    return AdvisorQuoteWaitForCondition("is_select_product", 350, 150, args)
}

AdvisorQuoteIsOnAscProductPage(db) {
    args := Map("ascProductContains", db["urls"]["ascProductContains"])
    return AdvisorQuoteWaitForCondition("is_asc", 350, 150, args)
}

AdvisorQuoteIsIncidentsPage(db) {
    args := AdvisorQuoteAscWaitArgs(db, Map("incidentsHeading", db["texts"]["incidentsHeading"]))
    return AdvisorQuoteWaitForCondition("is_incidents", 500, 150, args)
}

AdvisorQuoteRunOp(op, args := Map(), retries := 1, retryDelayMs := 200) {
    return AdvisorQuoteRunJsOp(op, args, retries, retryDelayMs)
}

AdvisorQuoteMergeArgs(baseArgs, extraArgs := Map()) {
    merged := Map()
    if IsObject(baseArgs) {
        for k, v in baseArgs
            merged[String(k)] := v
    }
    if IsObject(extraArgs) {
        for k, v in extraArgs
            merged[String(k)] := v
    }
    return merged
}

AdvisorQuoteWaitForCondition(name, timeoutMs, pollMs := 350, args := Map()) {
    if AdvisorQuoteResidentRunnerEnabled() && AdvisorQuoteRunnerAllowedWaitCondition(name) {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_WAIT_ATTEMPT", AdvisorQuoteGetLastStep(), "conditionName=" name ", timeoutMs=" timeoutMs ", pollMs=" pollMs)
        runnerWait := AdvisorQuoteRunnerWaitCondition(name, args, timeoutMs, pollMs)
        if (AdvisorQuoteStatusValue(runnerWait, "used") = "1") {
            result := AdvisorQuoteStatusValue(runnerWait, "result")
            steps := AdvisorQuoteStatusValue(runnerWait, "steps")
            elapsedMs := AdvisorQuoteStatusValue(runnerWait, "elapsedMs")
            AdvisorQuoteAppendLog("ADVISOR_RUNNER_WAIT_USED", AdvisorQuoteGetLastStep(), "conditionName=" name ", result=" result ", steps=" steps ", elapsedMs=" elapsedMs)
            AdvisorQuoteAppendLog("ADVISOR_RUNNER_WAIT_RESULT", AdvisorQuoteGetLastStep(), "conditionName=" name ", result=" result ", matched=" AdvisorQuoteStatusValue(runnerWait, "matched") ", steps=" steps ", elapsedMs=" elapsedMs)
            return runnerWait["value"] = true
        }
        AdvisorQuoteAppendLog(
            "ADVISOR_RUNNER_WAIT_FALLBACK",
            AdvisorQuoteGetLastStep(),
            "conditionName=" name
                . ", timeoutMs=" timeoutMs
                . ", pollMs=" pollMs
                . ", result=" AdvisorQuoteStatusValue(runnerWait, "result")
                . ", fallbackReason=" AdvisorQuoteStatusValue(runnerWait, "fallbackReason")
        )
    }

    start := A_TickCount
    nextHeartbeat := A_TickCount + 5000
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return false
        opArgs := AdvisorQuoteMergeArgs(Map("name", name), args)
        result := AdvisorQuoteRunOp("wait_condition", opArgs, 2, 120)
        if (result = "1")
            return true
        if (A_TickCount >= nextHeartbeat) {
            elapsed := A_TickCount - start
            AdvisorQuoteAppendLog("WAIT_CONDITION", AdvisorQuoteGetLastStep(), "condition=" name ", elapsedMs=" elapsed)
            nextHeartbeat := A_TickCount + 5000
        }
        if !SafeSleep(pollMs)
            return false
    }
    AdvisorQuoteAppendLog("TIMEOUT_CONDITION", AdvisorQuoteGetLastStep(), "condition=" name ", timeoutMs=" timeoutMs)
    return false
}

AdvisorQuoteInitTrace(profile) {
    global advisorQuoteProductOverviewAutoPending, advisorQuoteProductOverviewAutoVerified
    global advisorQuoteProductTileAutoSelectedOnOverview, advisorQuoteProductOverviewSaved, advisorQuoteGatherAutoCommitted, advisorQuoteProductTileRecoveryAttempted
    AdvisorQuoteResetConsoleBridge()
    AdvisorQuoteInitScanBundle()
    AdvisorQuoteResetJsMetricsCollector()
    advisorQuoteProductOverviewAutoPending := false
    advisorQuoteProductOverviewAutoVerified := false
    advisorQuoteProductTileAutoSelectedOnOverview := false
    advisorQuoteProductOverviewSaved := false
    advisorQuoteGatherAutoCommitted := false
    advisorQuoteProductTileRecoveryAttempted := false
    person := (IsObject(profile) && profile.Has("person")) ? profile["person"] : Map()
    fullName := person.Has("fullName") ? Trim(String(person["fullName"])) : ""
    if (fullName = "")
        fullName := Trim(String((person.Has("firstName") ? person["firstName"] : "") . " " . (person.Has("lastName") ? person["lastName"] : "")))
    vehicleCount := (IsObject(profile) && profile.Has("vehicles")) ? profile["vehicles"].Length : 0

    AdvisorQuoteAppendLog("RUN_START", "INIT", "lead=" fullName ", vehicles=" vehicleCount)
    AdvisorQuoteSetStep("INIT", "Workflow triggered from clipboard.")
}

AdvisorQuoteGetLastStep() {
    global advisorQuoteLastStep
    step := Trim(String(advisorQuoteLastStep ?? ""))
    return (step = "") ? "UNKNOWN" : step
}

AdvisorQuoteSetStep(step, detail := "") {
    global advisorQuoteLastStep, advisorQuoteLastStepAt
    safeStep := Trim(String(step ?? ""))
    if (safeStep = "")
        safeStep := "UNKNOWN"

    advisorQuoteLastStep := safeStep
    advisorQuoteLastStepAt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    AdvisorQuoteAppendLog("STEP", safeStep, detail)

    action := "advisor-quote-step-" . RegExReplace(StrLower(safeStep), "[^a-z0-9]+", "-")
    try PersistRunState(action)
}

AdvisorQuoteLogStop(reason := "stop-requested") {
    global advisorQuoteLastStepAt
    step := AdvisorQuoteGetLastStep()
    at := Trim(String(advisorQuoteLastStepAt ?? ""))
    suffix := (at != "") ? ", lastStepAt=" at : ""
    AdvisorQuoteAppendLog("STOP", step, reason suffix)
    try PersistRunState("advisor-quote-stop")
}

AdvisorQuoteAppendLog(eventType, step := "", detail := "") {
    global advisorQuoteTraceFile

    safeEvent := Trim(String(eventType ?? ""))
    if (safeEvent = "")
        safeEvent := "INFO"
    safeStep := Trim(String(step ?? ""))
    safeDetail := Trim(String(detail ?? ""))
    safeDetail := RegExReplace(safeDetail, "[`r`n]+", " ")

    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    line := ts . " | " . safeEvent
    if (safeStep != "")
        line .= " | " . safeStep
    if (safeDetail != "")
        line .= " | " . safeDetail
    line .= "`n"

    try FileAppend(line, advisorQuoteTraceFile, "UTF-8")
}

AdvisorQuoteScanCurrentPage(label := "", reason := "") {
    args := Map(
        "label", label,
        "reason", reason
    )
    scan := AdvisorQuoteRunOp("scan_current_page", args, 2, 200)
    if (scan = "")
        return ""
    return AdvisorQuoteSaveScanSnapshot(scan, label, reason)
}

AdvisorQuoteSaveScanSnapshot(scanJson, label := "", reason := "") {
    global logsRoot
    if (Trim(String(scanJson ?? "")) = "")
        return ""

    latestPath := logsRoot "\advisor_scan_latest.json"
    latestOk := AdvisorQuoteTryWriteUtf8Atomic(latestPath, scanJson, "latest-scan")

    bundlePath := AdvisorQuoteAppendScanToRunBundle(scanJson, label, reason)

    if AdvisorQuoteShouldWriteIndividualScanArchives()
        AdvisorQuoteWriteIndividualScanArchive(scanJson, label, reason)

    if (bundlePath != "")
        return bundlePath
    return latestOk ? latestPath : ""
}

AdvisorQuoteCaptureStateSnapshotDebug(sourceName := "Ctrl+Alt+Shift+S") {
    global logsRoot

    step := "ADVISOR_STATE_SNAPSHOT_TEST"
    AdvisorQuoteSetStep(step, "Read-only advisor_state_snapshot capture.")

    raw := ""
    errorCode := ""
    retryAttempted := false
    retryReason := ""
    retrySucceeded := false
    try {
        raw := Trim(String(AdvisorQuoteRunJsOpFullInjection("advisor_state_snapshot", Map("source", sourceName), 1, 0)))
    } catch as err {
        errorCode := AdvisorQuoteFormatStateSnapshotException("AdvisorQuoteCaptureStateSnapshotDebug", step, err)
    }

    retryReason := AdvisorQuoteStateSnapshotRetryReason(raw, errorCode)
    if (retryReason != "") {
        retryAttempted := true
        AdvisorQuoteResetConsoleBridge()
        try {
            raw := Trim(String(AdvisorQuoteRunJsOpFullInjection("advisor_state_snapshot", Map("source", sourceName, "retry", "1"), 1, 0)))
            retrySucceeded := AdvisorQuoteStateSnapshotEffectiveError(raw) = ""
        } catch as err {
            errorCode := AdvisorQuoteFormatStateSnapshotException("AdvisorQuoteCaptureStateSnapshotDebug", step, err)
        }
        retryFailureReason := AdvisorQuoteStateSnapshotRetryReason(raw, errorCode)
        if (retryFailureReason != "" && errorCode = "")
            errorCode := retryFailureReason
    }

    captureJson := AdvisorQuoteBuildStateSnapshotCaptureJson(raw, sourceName, errorCode, retryAttempted, retryReason, retrySucceeded)
    stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss") . "_" . Format("{:03}", A_MSec)
    latestPath := logsRoot "\advisor_state_snapshot_latest.json"
    archivePath := logsRoot "\advisor_state_snapshots\advisor_state_snapshot_" stamp ".json"
    latestOk := AdvisorQuoteTryWriteUtf8Atomic(latestPath, captureJson, "advisor-state-snapshot-latest")
    archiveOk := AdvisorQuoteTryWriteUtf8Atomic(archivePath, captureJson, "advisor-state-snapshot-archive")

    route := AdvisorQuoteExtractJsonString(raw, "route")
    confidence := AdvisorQuoteExtractJsonNumber(raw, "confidence")
    unsafeReason := AdvisorQuoteExtractJsonString(raw, "unsafeReason")
    url := AdvisorQuoteExtractJsonString(raw, "url")
    effectiveError := AdvisorQuoteStateSnapshotEffectiveError(raw, errorCode)
    result := (effectiveError = "" && latestOk && archiveOk) ? "OK" : ((effectiveError != "") ? "ERROR" : "WRITE_FAILED")

    AdvisorQuoteAppendLog(
        "ADVISOR_STATE_SNAPSHOT_CAPTURE",
        step,
        "result=" result
            . ", op=advisor_state_snapshot"
            . ", route=" route
            . ", confidence=" confidence
            . ", error=" effectiveError
            . ", retryAttempted=" (retryAttempted ? "1" : "0")
            . ", retryReason=" retryReason
            . ", retrySucceeded=" (retrySucceeded ? "1" : "0")
            . ", latestPath=" latestPath
            . ", archivePath=" archivePath
    )

    return Map(
        "result", result,
        "op", "advisor_state_snapshot",
        "route", route,
        "confidence", confidence,
        "unsafeReason", unsafeReason,
        "url", url,
        "error", effectiveError,
        "retryAttempted", retryAttempted ? "1" : "0",
        "retryReason", retryReason,
        "retrySucceeded", retrySucceeded ? "1" : "0",
        "latestPath", latestPath,
        "archivePath", archivePath,
        "latestWriteOk", latestOk ? "1" : "0",
        "archiveWriteOk", archiveOk ? "1" : "0"
    )
}

AdvisorQuoteFormatStateSnapshotException(functionName, stepLabel, err) {
    message := ""
    file := ""
    line := ""
    what := ""
    try message := err.Message
    try file := err.File
    try line := String(err.Line)
    try what := err.What

    detail := "exception:function=" functionName
        . ", step=" stepLabel
        . ", message=" message
    if (file != "")
        detail .= ", file=" file
    if (line != "")
        detail .= ", line=" line
    if (what != "")
        detail .= ", what=" what
    return detail
}

AdvisorQuoteBuildStateSnapshotCaptureJson(rawSnapshotJson, sourceName := "", errorCode := "", retryAttempted := false, retryReason := "", retrySucceeded := false) {
    raw := Trim(String(rawSnapshotJson ?? ""))
    rawIsJson := AdvisorQuoteLooksLikeJsonPayload(raw)
    capturedAt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    url := rawIsJson ? AdvisorQuoteExtractJsonString(raw, "url") : ""
    route := rawIsJson ? AdvisorQuoteExtractJsonString(raw, "route") : ""
    confidence := rawIsJson ? AdvisorQuoteExtractJsonNumber(raw, "confidence") : ""
    allowedNextActions := rawIsJson ? AdvisorQuoteExtractJsonArrayRaw(raw, "allowedNextActions") : "[]"
    unsafeReasonRaw := rawIsJson ? AdvisorQuoteExtractJsonNullableStringRaw(raw, "unsafeReason") : "null"
    effectiveError := AdvisorQuoteStateSnapshotEffectiveError(raw, errorCode)
    okText := (effectiveError = "") ? "true" : "false"
    rawPayload := rawIsJson ? raw : "null"
    rawTextPayload := (!rawIsJson && raw != "") ? ('"' AdvisorQuoteJsonEscape(raw) '"') : "null"

    json := "{`n"
        . '  "ok": ' okText ",`n"
        . '  "capturedAt": "' AdvisorQuoteJsonEscape(capturedAt) '",`n'
        . '  "source": "' AdvisorQuoteJsonEscape(sourceName) '",`n'
        . '  "op": "advisor_state_snapshot",`n'
        . '  "url": "' AdvisorQuoteJsonEscape(url) '",`n'
        . '  "route": "' AdvisorQuoteJsonEscape(route) '",`n'
        . '  "confidence": ' (confidence != "" ? confidence : "null") ",`n"
        . '  "allowedNextActions": ' allowedNextActions ",`n"
        . '  "unsafeReason": ' unsafeReasonRaw ",`n"
        . '  "error": ' (effectiveError = "" ? "null" : ('"' AdvisorQuoteJsonEscape(effectiveError) '"')) ",`n"
        . '  "retryAttempted": ' (retryAttempted ? "true" : "false") ",`n"
        . '  "retryReason": "' AdvisorQuoteJsonEscape(retryReason) '",`n'
        . '  "retrySucceeded": ' (retrySucceeded ? "true" : "false") ",`n"
        . '  "rawAdvisorStateSnapshot": ' rawPayload ",`n"
        . '  "rawText": ' rawTextPayload "`n"
        . "}`n"
    return json
}

AdvisorQuoteStateSnapshotEffectiveError(rawSnapshotJson, errorCode := "") {
    raw := Trim(String(rawSnapshotJson ?? ""))
    effectiveError := Trim(String(errorCode ?? ""))
    if (effectiveError != "")
        return effectiveError
    if (raw = "")
        return "empty-result-or-bridge-unavailable"
    if !AdvisorQuoteLooksLikeJsonPayload(raw)
        return "invalid-json-result"
    url := StrLower(AdvisorQuoteExtractJsonString(raw, "url"))
    if !InStr(url, "advisorpro.allstate.com")
        return "advisor-pro-not-active"
    return ""
}

AdvisorQuoteStateSnapshotRetryReason(rawSnapshotJson, errorCode := "") {
    if (Trim(String(errorCode ?? "")) != "")
        return ""
    raw := Trim(String(rawSnapshotJson ?? ""))
    if (raw = "")
        return "empty-result-or-bridge-unavailable"
    lowerRaw := StrLower(raw)
    if (InStr(lowerRaw, "bridge-unavailable") || InStr(lowerRaw, "bridge unavailable"))
        return "bridge-unavailable"
    return ""
}

AdvisorQuoteExtractJsonNumber(json, key) {
    pattern := '"' key '"\s*:\s*(-?\d+(?:\.\d+)?)'
    if RegExMatch(String(json ?? ""), pattern, &m)
        return m[1]
    return ""
}

AdvisorQuoteExtractJsonArrayRaw(json, key) {
    pattern := 's)"' key '"\s*:\s*(\[[^\]]*\])'
    if RegExMatch(String(json ?? ""), pattern, &m)
        return m[1]
    return "[]"
}

AdvisorQuoteExtractJsonNullableStringRaw(json, key) {
    pattern := 's)"' key '"\s*:\s*(null|"((?:\\.|[^"\\])*)")'
    if RegExMatch(String(json ?? ""), pattern, &m)
        return m[1]
    return "null"
}

AdvisorQuoteInitScanBundle(runId := "") {
    global logsRoot, advisorQuoteRunId, advisorQuoteRunStartedAt, advisorQuoteScanBundlePath
    global advisorQuoteScanBundleItems, advisorQuoteScanCount

    if (Trim(String(runId ?? "")) = "")
        runId := FormatTime(A_Now, "yyyyMMdd_HHmmss") . "_" . Format("{:03}", A_MSec)
    advisorQuoteRunId := AdvisorQuoteSanitizeScanToken(runId)
    if (advisorQuoteRunId = "")
        advisorQuoteRunId := "run-" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
    advisorQuoteRunStartedAt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    advisorQuoteScanBundleItems := []
    advisorQuoteScanCount := 0

    bundleDir := logsRoot "\advisor_scans"
    try DirCreate(bundleDir)
    advisorQuoteScanBundlePath := bundleDir "\advisor_scan_run_" advisorQuoteRunId ".json"
}

AdvisorQuoteEnsureScanBundleInitialized() {
    global advisorQuoteRunId, advisorQuoteScanBundlePath
    if (Trim(String(advisorQuoteRunId ?? "")) = "" || Trim(String(advisorQuoteScanBundlePath ?? "")) = "")
        AdvisorQuoteInitScanBundle()
}

AdvisorQuoteAppendScanToRunBundle(scanJson, label := "", reason := "") {
    global advisorQuoteScanBundlePath, advisorQuoteScanBundleItems, advisorQuoteScanCount

    try {
        AdvisorQuoteEnsureScanBundleInitialized()
        advisorQuoteScanCount += 1
        item := AdvisorQuoteBuildScanBundleItem(scanJson, label, reason, advisorQuoteScanCount)
        advisorQuoteScanBundleItems.Push(item)
        bundleJson := AdvisorQuoteBuildScanBundleJson()
        AdvisorQuoteWriteUtf8Atomic(advisorQuoteScanBundlePath, bundleJson)
        return advisorQuoteScanBundlePath
    } catch as err {
        AdvisorQuoteLogScanWriteFailure("run-bundle", advisorQuoteScanBundlePath, err)
        return ""
    }
}

AdvisorQuoteBuildScanBundleItem(scanJson, label := "", reason := "", sequence := 0) {
    payload := Trim(String(scanJson ?? ""))
    if !AdvisorQuoteLooksLikeJsonPayload(payload)
        payload := "null"

    capturedAt := AdvisorQuoteExtractJsonString(scanJson, "capturedAt")
    if (capturedAt = "")
        capturedAt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    url := AdvisorQuoteExtractJsonString(scanJson, "url")
    state := Trim(String(label ?? ""))

    json := "{`n"
        . '      "sequence": ' Integer(sequence) ",`n"
        . '      "capturedAt": "' AdvisorQuoteJsonEscape(capturedAt) '",`n'
        . '      "label": "' AdvisorQuoteJsonEscape(label) '",`n'
        . '      "reason": "' AdvisorQuoteJsonEscape(reason) '",`n'
        . '      "state": "' AdvisorQuoteJsonEscape(state) '",`n'
        . '      "url": "' AdvisorQuoteJsonEscape(url) '",`n'
        . '      "payload": ' payload "`n"
        . "    }"
    return json
}

AdvisorQuoteBuildScanBundleJson() {
    global advisorQuoteRunId, advisorQuoteRunStartedAt, advisorQuoteScanBundleItems, advisorQuoteScanCount
    updatedAt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    json := "{`n"
        . '  "runId": "' AdvisorQuoteJsonEscape(advisorQuoteRunId) '",`n'
        . '  "startedAt": "' AdvisorQuoteJsonEscape(advisorQuoteRunStartedAt) '",`n'
        . '  "updatedAt": "' AdvisorQuoteJsonEscape(updatedAt) '",`n'
        . '  "scanCount": ' Integer(advisorQuoteScanCount) ",`n"
        . '  "scans": ['
    if (advisorQuoteScanBundleItems.Length > 0) {
        json .= "`n"
        for index, item in advisorQuoteScanBundleItems {
            if (index > 1)
                json .= ",`n"
            json .= item
        }
        json .= "`n"
    }
    json .= "  ]`n}"
    return json
}

AdvisorQuoteShouldWriteIndividualScanArchives() {
    global advisorQuoteWriteIndividualScanArchives
    return advisorQuoteWriteIndividualScanArchives = true
}

AdvisorQuoteWriteIndividualScanArchive(scanJson, label := "", reason := "") {
    global logsRoot
    stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss") . "_" . Format("{:03}", A_MSec)
    safeLabel := AdvisorQuoteSanitizeScanToken(label)
    safeReason := AdvisorQuoteSanitizeScanToken(reason)
    archivePath := logsRoot "\advisor_scan_" . stamp
    if (safeLabel != "")
        archivePath .= "_" . safeLabel
    if (safeReason != "")
        archivePath .= "_" . safeReason
    archivePath .= ".json"
    AdvisorQuoteTryWriteUtf8Atomic(archivePath, scanJson, "individual-scan-archive")
}

AdvisorQuoteTryWriteUtf8Atomic(path, text, context := "file") {
    try {
        AdvisorQuoteWriteUtf8Atomic(path, text)
        return true
    } catch as err {
        AdvisorQuoteLogScanWriteFailure(context, path, err)
        return false
    }
}

AdvisorQuoteWriteUtf8Atomic(path, text) {
    dir := RegExReplace(path, "\\[^\\]+$", "")
    if (dir != "" && dir != path)
        DirCreate(dir)
    tempPath := path ".tmp"
    try FileDelete(tempPath)
    FileAppend(text, tempPath, "UTF-8")
    FileMove(tempPath, path, 1)
}

AdvisorQuoteLogScanWriteFailure(context, path, err) {
    message := ""
    try message := err.Message
    detail := "context=" context ", path=" path
    if (message != "")
        detail .= ", error=" message
    try AdvisorQuoteAppendLog("SCAN_WRITE_FAILED", AdvisorQuoteGetLastStep(), detail)
}

AdvisorQuoteLooksLikeJsonPayload(text) {
    trimmed := Trim(String(text ?? ""))
    lastChar := (StrLen(trimmed) > 0) ? SubStr(trimmed, StrLen(trimmed), 1) : ""
    return (SubStr(trimmed, 1, 1) = "{" && lastChar = "}")
        || (SubStr(trimmed, 1, 1) = "[" && lastChar = "]")
}

AdvisorQuoteExtractJsonString(json, key) {
    pattern := '"' key '"\s*:\s*"((?:\\.|[^"\\])*)"'
    if RegExMatch(String(json ?? ""), pattern, &m)
        return AdvisorQuoteJsonUnescapeBasic(m[1])
    return ""
}

AdvisorQuoteJsonUnescapeBasic(value) {
    text := String(value ?? "")
    text := StrReplace(text, '\"', '"')
    text := StrReplace(text, "\/", "/")
    text := StrReplace(text, "\r", "`r")
    text := StrReplace(text, "\n", "`n")
    text := StrReplace(text, "\t", A_Tab)
    text := StrReplace(text, "\\", "\")
    return text
}

AdvisorQuoteJsonEscape(value) {
    text := String(value ?? "")
    text := StrReplace(text, "\", "\\")
    text := StrReplace(text, '"', '\"')
    text := StrReplace(text, "`r", "\r")
    text := StrReplace(text, "`n", "\n")
    text := StrReplace(text, A_Tab, "\t")
    return text
}

AdvisorQuoteSanitizeScanToken(text) {
    token := Trim(String(text ?? ""))
    token := StrLower(token)
    token := RegExReplace(token, "[^a-z0-9]+", "-")
    token := RegExReplace(token, "^-+|-+$", "")
    return token
}

AdvisorQuoteClickById(id, timeoutMs := 4000) {
    start := A_TickCount
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return false
        result := AdvisorQuoteRunOp("click_by_id", Map("id", id), 2, 100)
        if (result = "OK")
            return true
        if !SafeSleep(250)
            return false
    }
    return false
}

AdvisorQuoteClickByText(text, tagSelector := "button,a", timeoutMs := 4000) {
    start := A_TickCount
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return false
        args := Map("text", text, "tagSelector", tagSelector)
        result := AdvisorQuoteRunOp("click_by_text", args, 2, 100)
        if (result = "OK")
            return true
        if !SafeSleep(250)
            return false
    }
    return false
}
