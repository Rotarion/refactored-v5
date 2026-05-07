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

AdvisorQuoteStateEntrySearch(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("ENTRY_SEARCH", "Opening Advisor quote entry flow.")
    state := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(state, ["BEGIN_QUOTING_SEARCH", "BEGIN_QUOTING_FORM", "DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("ENTRY_SEARCH", "ENTRY_SEARCH", "Entry search already satisfied.", entryScanPath, state)

    if !AdvisorQuoteIsStateInList(state, ["ADVISOR_HOME", "GATEWAY", "ADVISOR_OTHER"])
        return AdvisorQuoteResultFail("ENTRY_SEARCH", "ENTRY_SEARCH", "Unexpected state before quote entry.", true, entryScanPath, state)

    clickTarget := ""
    clicked := AdvisorQuoteClickById(db["selectors"]["advisorQuotingButtonId"], db["timeouts"]["actionMs"])
    if clicked
        clickTarget := "id:" db["selectors"]["advisorQuotingButtonId"]
    if !clicked {
        clicked := AdvisorQuoteClickByText("Quoting", "button,a", db["timeouts"]["actionMs"])
        if clicked
            clickTarget := "text:Quoting"
    }
    if !clicked {
        failScan := AdvisorQuoteScanCurrentPage("ENTRY_SEARCH", "quoting-button-missing")
        return AdvisorQuoteResultFail("ENTRY_SEARCH", "ENTRY_SEARCH", "Could not click the Quoting entry point.", true, failScan, state)
    }

    nextState := AdvisorQuoteWaitForObservedState(
        db,
        ["BEGIN_QUOTING_SEARCH", "BEGIN_QUOTING_FORM", "DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"],
        db["timeouts"]["transitionMs"]
    )
    if (nextState = "")
        nextState := AdvisorQuoteDetectState(db)

    if AdvisorQuoteIsStateInList(nextState, ["BEGIN_QUOTING_SEARCH", "BEGIN_QUOTING_FORM", "DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"]) {
        AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_SEARCH", "target=" clickTarget . ", beforeState=" state . ", afterState=" nextState)
        return AdvisorQuoteResultOkValue("ENTRY_SEARCH", "ENTRY_SEARCH", "Quoting entry point opened.", entryScanPath, nextState)
    }

    failScan := AdvisorQuoteScanCurrentPage("ENTRY_SEARCH", "transition-failed")
    AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_SEARCH", "target=" clickTarget . ", beforeState=" state . ", afterState=" nextState . ", unchangedOrUnexpected=1")
    return AdvisorQuoteResultFail("ENTRY_SEARCH", "ENTRY_SEARCH", "Quoting entry click did not reach Begin Quoting.", true, failScan, nextState)
}

AdvisorQuoteStateEntryCreateForm(profile, db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("ENTRY_CREATE_FORM", "Opening and submitting the Create New Prospect form.")
    state := AdvisorQuoteDetectState(db)

    if (state = "CUSTOMER_SUMMARY_OVERVIEW")
        return AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-initial-detected", entryScanPath, state)
    if AdvisorQuoteIsStateInList(state, ["PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS", "DUPLICATE"])
        return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create-form state already satisfied.", entryScanPath, state)

    forwardResult := AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-initial", entryScanPath, state)
    if IsObject(forwardResult)
        return forwardResult

    addressVerification := AdvisorQuoteResolveAddressVerification(profile, db, "entry-create-initial", 0)
    if addressVerification["handled"] {
        if addressVerification["ok"]
            return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Address Verification resolved.", entryScanPath, addressVerification["state"])
        failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "address-verification-failed")
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", addressVerification["reason"], true, failScan, addressVerification["state"], addressVerification["status"])
    }

    if (state = "BEGIN_QUOTING_SEARCH") {
        createResult := AdvisorQuoteOpenCreateNewProspectFromSearchResult(db)
        if !AdvisorQuoteResultOk(createResult)
            return createResult
        state := AdvisorQuoteResultValue(createResult, "observedState")
        if (state = "")
            state := AdvisorQuoteDetectState(db)
        if (state = "CUSTOMER_SUMMARY_OVERVIEW")
            return AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-after-search-detected", AdvisorQuoteResultValue(createResult, "scanPath"), state)
        if AdvisorQuoteIsStateInList(state, ["PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS", "DUPLICATE"])
            return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create New Prospect advanced beyond the form.", AdvisorQuoteResultValue(createResult, "scanPath"), state)
        forwardResult := AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-after-search", AdvisorQuoteResultValue(createResult, "scanPath"), state)
        if IsObject(forwardResult)
            return forwardResult
    }

    if (state != "BEGIN_QUOTING_FORM") {
        forwardResult := AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-not-form", entryScanPath, state)
        if IsObject(forwardResult)
            return forwardResult
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Expected the Create New Prospect form.", true, entryScanPath, state)
    }

    fields := profile["fields"]
    if !AdvisorQuoteWaitForProspectFormReady(db) {
        readyState := AdvisorQuoteDetectState(db)
        if (readyState = "CUSTOMER_SUMMARY_OVERVIEW")
            return AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-form-ready-forwarded", entryScanPath, readyState)
        if AdvisorQuoteIsStateInList(readyState, ["PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS", "DUPLICATE"])
            return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create-form state advanced while waiting for form readiness.", entryScanPath, readyState)
        forwardResult := AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-form-not-ready", entryScanPath, readyState)
        if IsObject(forwardResult)
            return forwardResult
        failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "form-not-ready")
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create New Prospect form did not become ready.", true, failScan, "BEGIN_QUOTING_FORM")
    }

    if !AdvisorQuotePrimeProspectFormFill(db) {
        failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "focus-failed")
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Could not focus the first-name field on the Create New Prospect form.", true, failScan, "BEGIN_QUOTING_FORM")
    }
    if !AdvisorQuoteFillProspectForm(fields, db, 1)
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Prospect form fill was interrupted.", false, entryScanPath, "BEGIN_QUOTING_FORM")

    if AdvisorQuoteIsDuplicatePage(db)
        return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Prospect form submitted to duplicate resolution.", entryScanPath, "DUPLICATE")

    status := AdvisorQuoteGetProspectFormStatus(db)
    if !AdvisorQuoteProspectFormReadyToSubmit(status, fields) {
        AdvisorQuoteAppendLog("PROSPECT_RETRY", "ENTRY_CREATE_FORM", "Prospect form incomplete after first pass. Retrying fill.")
        if !AdvisorQuotePrimeProspectFormFill(db) {
            failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "focus-failed-second-pass")
            return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Could not refocus the Create New Prospect form for retry.", true, failScan, "BEGIN_QUOTING_FORM")
        }
        if !AdvisorQuoteFillProspectForm(fields, db, 2)
            return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Prospect form second fill was interrupted.", false, entryScanPath, "BEGIN_QUOTING_FORM")
        if AdvisorQuoteIsDuplicatePage(db)
            return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Prospect form submitted to duplicate resolution.", entryScanPath, "DUPLICATE")
        status := AdvisorQuoteGetProspectFormStatus(db)
    }

    if !AdvisorQuoteProspectFormReadyToSubmit(status, fields) {
        failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "validation-failed")
        AdvisorQuoteLogProspectStatus(status, "PROSPECT_INVALID")
        return AdvisorQuoteResultFail(
            "ENTRY_CREATE_FORM",
            "ENTRY_CREATE_FORM",
            AdvisorQuoteBuildProspectInvalidReason(status),
            true,
            failScan,
            "BEGIN_QUOTING_FORM",
            status
        )
    }

    clickTarget := AdvisorQuoteClickCreateProspectPrimaryButtonDetailed(db)
    if (clickTarget = "") {
        failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "submit-button-missing")
        AdvisorQuoteLogProspectStatus(status, "PROSPECT_SUBMIT_FAIL")
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Could not click PrimaryApplicant-Continue-button on Create New Prospect.", true, failScan, "BEGIN_QUOTING_FORM", status)
    }

    postSubmitStates := AdvisorQuotePostProspectSubmitStates()
    nextState := AdvisorQuoteWaitForObservedState(
        db,
        postSubmitStates,
        db["timeouts"]["shortMs"]
    )

    if (nextState = "") {
        addressVerification := AdvisorQuoteResolveAddressVerification(profile, db, "entry-create-after-submit", 6000)
        if addressVerification["handled"] {
            if addressVerification["ok"] {
                AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_CREATE_FORM", "target=" clickTarget . ", beforeState=BEGIN_QUOTING_FORM, afterState=" addressVerification["state"] . ", intermediate=address-verification")
                return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create New Prospect submitted through Address Verification.", entryScanPath, addressVerification["state"])
            }
            failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "address-verification-failed")
            return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", addressVerification["reason"], true, failScan, addressVerification["state"], addressVerification["status"])
        }
    }

    if (nextState = "")
        nextState := AdvisorQuoteWaitForObservedState(db, postSubmitStates, db["timeouts"]["transitionMs"])
    if (nextState = "")
        nextState := AdvisorQuoteDetectState(db)

    if (nextState = "CUSTOMER_SUMMARY_OVERVIEW") {
        AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_CREATE_FORM", "target=" clickTarget . ", beforeState=BEGIN_QUOTING_FORM, afterState=CUSTOMER_SUMMARY_OVERVIEW")
        return AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-after-submit-detected", entryScanPath, nextState)
    }

    forwardResult := AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "ENTRY_CREATE_FORM", "entry-create-after-submit", entryScanPath, nextState)
    if IsObject(forwardResult) {
        AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_CREATE_FORM", "target=" clickTarget . ", beforeState=BEGIN_QUOTING_FORM, afterState=CUSTOMER_SUMMARY_OVERVIEW, routeFallback=customer-summary")
        return forwardResult
    }

    AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_CREATE_FORM", "target=" clickTarget . ", beforeState=BEGIN_QUOTING_FORM, afterState=" nextState)
    if AdvisorQuoteIsStateInList(nextState, postSubmitStates)
        return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create New Prospect submitted successfully.", entryScanPath, nextState)

    failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "submit-no-transition")
    status := AdvisorQuoteGetProspectFormStatus(db)
    AdvisorQuoteLogProspectStatus(status, "PROSPECT_SUBMIT_STILL_ON_FORM")
    return AdvisorQuoteResultFail(
        "ENTRY_CREATE_FORM",
        "ENTRY_CREATE_FORM",
        "Create New Prospect submit did not transition off the form. " . AdvisorQuoteBuildProspectInvalidReason(status),
        true,
        failScan,
        nextState,
        status
    )
}

AdvisorQuoteStateDuplicate(profile, db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("DUPLICATE", "Resolving This Prospect May Already Exist if shown.")
    state := AdvisorQuoteDetectState(db)
    if (state != "DUPLICATE")
        return AdvisorQuoteResultOkValue("DUPLICATE", "DUPLICATE", "Duplicate state not present.", entryScanPath, state)

    if !AdvisorQuoteHandleDuplicateProspect(profile, db) {
        failScan := AdvisorQuoteScanCurrentPage("DUPLICATE", "resolution-failed")
        return AdvisorQuoteResultFail("DUPLICATE", "DUPLICATE", "Duplicate prospect resolution did not complete.", true, failScan, "DUPLICATE")
    }

    nextState := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(nextState, ["CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("DUPLICATE", "DUPLICATE", "Duplicate prospect resolved.", entryScanPath, nextState)

    failScan := AdvisorQuoteScanCurrentPage("DUPLICATE", "still-on-duplicate")
    return AdvisorQuoteResultFail("DUPLICATE", "DUPLICATE", "Duplicate page remained after resolution.", true, failScan, nextState)
}

AdvisorQuoteStateCustomerSummaryOverview(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("CUSTOMER_SUMMARY_OVERVIEW", "Normalizing Customer Summary Overview through START HERE.")
    if !FocusEdge()
        return AdvisorQuoteResultFail("CUSTOMER_SUMMARY_OVERVIEW", "CUSTOMER_SUMMARY_OVERVIEW", "Microsoft Edge not found. Open Advisor Pro first.", false, entryScanPath, "NO_EDGE")

    state := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(state, ["PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "DRIVERS_VEHICLES", "INCIDENTS", "QUOTE_LANDING"])
        return AdvisorQuoteResultOkValue("CUSTOMER_SUMMARY_OVERVIEW", "CUSTOMER_SUMMARY_OVERVIEW", "Customer summary bridge already satisfied.", entryScanPath, state)
    forwardResult := AdvisorQuoteForwardCustomerSummaryToProductOverview(db, "CUSTOMER_SUMMARY_OVERVIEW", "customer-summary-handler", entryScanPath, state)
    if IsObject(forwardResult)
        return forwardResult

    failScan := AdvisorQuoteScanCurrentPage("CUSTOMER_SUMMARY_OVERVIEW", "route-status-not-detected")
    return AdvisorQuoteResultFail(
        "CUSTOMER_SUMMARY_OVERVIEW",
        "CUSTOMER_SUMMARY_OVERVIEW",
        "Expected Customer Summary Overview before START HERE routing; route-status fallback did not confirm it.",
        true,
        failScan,
        state
    )
}

AdvisorQuoteStateProductOverview(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("PRODUCT_OVERVIEW", "Selecting Auto on the product overview grid.")
    if !FocusEdge()
        return AdvisorQuoteResultFail("PRODUCT_OVERVIEW", "PRODUCT_OVERVIEW", "Microsoft Edge not found. Open Advisor Pro first.", false, entryScanPath, "NO_EDGE")

    state := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(state, ["RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("PRODUCT_OVERVIEW", "PRODUCT_OVERVIEW", "Product overview stage already satisfied.", entryScanPath, state)
    if (state != "PRODUCT_OVERVIEW")
        return AdvisorQuoteResultFail("PRODUCT_OVERVIEW", "PRODUCT_OVERVIEW", "Expected the product overview grid after prospect creation.", true, entryScanPath, state)

    failureCode := AdvisorQuoteHandleProductOverview(db)
    if (failureCode = "")
        return AdvisorQuoteResultOkValue("PRODUCT_OVERVIEW", "PRODUCT_OVERVIEW", "Product overview completed.", entryScanPath, AdvisorQuoteDetectState(db))

    failScan := AdvisorQuoteScanCurrentPage("PRODUCT_OVERVIEW", StrLower(failureCode))
    observedState := AdvisorQuoteDetectState(db)
    switch failureCode {
        case "OVERVIEW_NOT_READY":
            reason := "Product overview grid did not become ready in time."
        case "AUTO_TILE_NOT_FOUND":
            reason := "Could not find the Auto product tile on the product overview grid."
        case "AUTO_TILE_CLICK_FAILED":
            reason := "Could not select the Auto product tile on the product overview grid."
        case "AUTO_TILE_NOT_VERIFIED":
            reason := "The Auto product tile was clicked but could not be verified as selected."
        case "PRODUCT_TILE_AUTO_NOT_PRESENT":
            reason := "PRODUCT_TILE_AUTO_NOT_PRESENT: Auto product tile is not present or Product Tile Grid status could not confirm it."
        case "PRODUCT_TILE_AUTO_CLICK_FAILED":
            reason := "PRODUCT_TILE_AUTO_CLICK_FAILED: Auto product tile was present but could not be clicked."
        case "PRODUCT_TILE_AUTO_VERIFY_FAILED":
            reason := "PRODUCT_TILE_AUTO_VERIFY_FAILED: Auto product tile was clicked once but could not be verified as selected."
        case "PRODUCT_TILE_AUTO_UNSELECTED_BY_CLICK":
            reason := "PRODUCT_TILE_AUTO_UNSELECTED_BY_CLICK: Auto product tile appeared selected before click but became unselected after a click path."
        case "CONTINUE_BUTTON_NOT_FOUND":
            reason := "Could not click Save & Continue to Gather Data on the product overview grid."
        case "RAPPORT_TRANSITION_TIMEOUT":
            reason := "Product overview did not transition to Gather Data after selecting Auto and clicking Save & Continue to Gather Data."
        default:
            reason := "Product overview handling did not complete."
    }
    return AdvisorQuoteResultFail("PRODUCT_OVERVIEW", "PRODUCT_OVERVIEW", reason, true, failScan, observedState)
}

AdvisorQuoteStateRapport(profile, db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("RAPPORT", "Filling Gather Data and lead vehicles.")
    state := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(state, ["SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("RAPPORT", "RAPPORT", "Rapport stage already satisfied.", entryScanPath, state)

    failureReason := ""
    failureScan := ""
    if !AdvisorQuoteHandleGatherData(profile, db, &failureReason, &failureScan) {
        if (failureScan = "")
            failureScan := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-data-failed")
        if (failureReason = "")
            failureReason := "Gather Data stage did not complete."
        return AdvisorQuoteResultFail("RAPPORT", "RAPPORT", failureReason, true, failureScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("RAPPORT", "RAPPORT", "Gather Data completed.", entryScanPath, AdvisorQuoteDetectState(db))
}

AdvisorQuoteStateSelectProduct(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("SELECT_PRODUCT", "Applying Select Product defaults.")
    state := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(state, ["ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("SELECT_PRODUCT", "SELECT_PRODUCT", "Select Product stage already satisfied.", entryScanPath, state)

    AdvisorQuoteAppendLog("SELECT_PRODUCT_FALLBACK_DETECTED", "SELECT_PRODUCT", "mode=add-product-fallback, state=" state)

    failureReason := ""
    failureScan := ""
    if !AdvisorQuoteHandleSelectProduct(db, &failureReason, &failureScan) {
        if (failureScan = "")
            failureScan := AdvisorQuoteScanCurrentPage("SELECT_PRODUCT", "select-product-failed")
        if (failureReason = "")
            failureReason := "Select Product stage did not complete."
        return AdvisorQuoteResultFail("SELECT_PRODUCT", "SELECT_PRODUCT", failureReason, true, failureScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("SELECT_PRODUCT", "SELECT_PRODUCT", "Select Product completed.", entryScanPath, AdvisorQuoteDetectState(db))
}

AdvisorQuoteStateConsumerReports(profile, db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("CONSUMER_REPORTS", "Accepting consumer reports consent.")
    state := AdvisorQuoteDetectState(db)
    failureReason := ""
    failureScan := ""
    routeResult := AdvisorQuoteTryRouteConsumerReportsAscProduct(profile, db, state, entryScanPath, &failureReason, &failureScan)
    if (routeResult = "OK")
        return AdvisorQuoteResultOkValue("CONSUMER_REPORTS", "CONSUMER_REPORTS", "CONSUMER_REPORTS_ROUTED_TO_DRIVERS_VEHICLES", entryScanPath, AdvisorQuoteDetectState(db))
    if (routeResult = "ALREADY_SATISFIED")
        return AdvisorQuoteResultOkValue("CONSUMER_REPORTS", "CONSUMER_REPORTS", "Consumer reports stage already satisfied.", entryScanPath, AdvisorQuoteDetectState(db))
    if (routeResult = "FAILED") {
        if (failureScan = "")
            failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "consumer-reports-asc-route-failed")
        return AdvisorQuoteResultFail("CONSUMER_REPORTS", "CONSUMER_REPORTS", failureReason, true, failureScan, AdvisorQuoteDetectState(db))
    }

    if !AdvisorQuoteHandleConsumerReports(db, &failureReason) {
        failScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "consumer-reports-failed")
        if (failureReason = "")
            failureReason := "Consumer Reports consent did not complete."
        return AdvisorQuoteResultFail("CONSUMER_REPORTS", "CONSUMER_REPORTS", failureReason, true, failScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("CONSUMER_REPORTS", "CONSUMER_REPORTS", "Consumer Reports completed.", entryScanPath, AdvisorQuoteDetectState(db))
}

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

AdvisorQuoteOpenCreateNewProspectFromSearchResult(db) {
    selectors := db["selectors"]
    timeouts := db["timeouts"]
    beforeState := AdvisorQuoteDetectState(db)
    clickTarget := ""

    clicked := AdvisorQuoteClickById(selectors["searchCreateNewProspectId"], timeouts["actionMs"])
    if clicked
        clickTarget := "id:" selectors["searchCreateNewProspectId"]
    if !clicked {
        clicked := AdvisorQuoteClickByText("Create New Prospect", "button,a,input[type=button],input[type=submit]", timeouts["actionMs"])
        if clicked
            clickTarget := "text:Create New Prospect"
    }
    if !clicked {
        failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "create-new-button-missing")
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Could not find a Create New Prospect control on Begin Quoting Search.", true, failScan, beforeState)
    }

    nextState := AdvisorQuoteWaitForObservedState(
        db,
        ["BEGIN_QUOTING_FORM", "DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"],
        timeouts["transitionMs"]
    )
    if (nextState = "")
        nextState := AdvisorQuoteDetectState(db)

    AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_CREATE_FORM", "target=" clickTarget . ", beforeState=" beforeState . ", afterState=" nextState)
    if AdvisorQuoteIsStateInList(nextState, ["BEGIN_QUOTING_FORM", "DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create New Prospect button transitioned successfully.", "", nextState)

    failScan := AdvisorQuoteScanCurrentPage("ENTRY_CREATE_FORM", "search-unchanged-after-create-click")
    return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Begin Quoting Search stayed on the same page after clicking Create New Prospect.", true, failScan, nextState)
}

AdvisorQuoteClickCreateProspectPrimaryButtonDetailed(db) {
    actionMs := db["timeouts"]["actionMs"]
    if AdvisorQuoteClickById(db["selectors"]["beginQuotingContinueId"], actionMs)
        return "id:" db["selectors"]["beginQuotingContinueId"]
    if AdvisorQuoteClickByText("Create New Prospect", "button,a,input[type=button],input[type=submit]", actionMs)
        return "text:Create New Prospect"
    if AdvisorQuoteClickByText("Continue", "button,a,input[type=button],input[type=submit]", actionMs)
        return "text:Continue"
    return ""
}

AdvisorQuoteBuildProspectInvalidReason(status) {
    errors := Trim(String(AdvisorQuoteStatusValue(status, "errors")))
    if (errors != "")
        return "Create New Prospect validation errors: " errors

    missing := []
    if (Trim(String(AdvisorQuoteStatusValue(status, "firstName"))) = "")
        missing.Push("firstName")
    if (Trim(String(AdvisorQuoteStatusValue(status, "lastName"))) = "")
        missing.Push("lastName")
    if (Trim(String(AdvisorQuoteStatusValue(status, "dob"))) = "")
        missing.Push("dob")
    if (Trim(String(AdvisorQuoteStatusValue(status, "address"))) = "")
        missing.Push("address")
    if (Trim(String(AdvisorQuoteStatusValue(status, "city"))) = "")
        missing.Push("city")
    if (Trim(String(AdvisorQuoteStatusValue(status, "state"))) = "")
        missing.Push("state")
    if (Trim(String(AdvisorQuoteStatusValue(status, "zip"))) = "")
        missing.Push("zip")
    if (missing.Length > 0)
        return "Create New Prospect form still has missing fields: " JoinArray(missing, ", ")
    if (AdvisorQuoteStatusValue(status, "submitPresent") != "1")
        return "Create New Prospect submit button is missing."
    if (AdvisorQuoteStatusValue(status, "submitEnabled") != "1")
        return "Create New Prospect submit button is still disabled."
    return "Create New Prospect form did not validate cleanly."
}

AdvisorQuoteIsDriversVehiclesState(db) {
    return AdvisorQuoteWaitForCondition("drivers_or_incidents", 500, 150, AdvisorQuoteAscWaitArgs(db)) && !AdvisorQuoteIsIncidentsPage(db)
}

AdvisorQuoteAscWaitArgs(db, extraArgs := Map()) {
    args := Map("ascProductContains", db["urls"]["ascProductContains"])
    if IsObject(extraArgs) {
        for key, value in extraArgs
            args[String(key)] := value
    }
    return args
}

AdvisorQuoteAscProductRouteIdText(routeId) {
    routeId := Trim(String(routeId))
    return (routeId = "") ? "" : "ASCPRODUCT/" routeId
}

AdvisorQuoteIsConsumerReportsConsentPage(db) {
    args := AdvisorQuoteAscWaitArgs(db, Map("consumerReportsConsentYesId", db["selectors"]["consumerReportsConsentYesId"]))
    return AdvisorQuoteWaitForCondition("consumer_reports_ready", 500, 150, args)
}

AdvisorQuoteIsQuoteLandingPage(db) {
    return AdvisorQuoteWaitForCondition("quote_landing", 500, 150, AdvisorQuoteAscWaitArgs(db))
}

AdvisorQuoteTryRouteConsumerReportsAscProduct(profile, db, observedState, entryScanPath, &failureReason := "", &failureScan := "") {
    failureReason := ""
    failureScan := ""
    participantStatus := AdvisorQuoteGetAscParticipantDetailStatus()
    routeId := AdvisorQuoteStatusValue(participantStatus, "ascProductRouteId")
    ascDetected := (observedState = "ASC_PRODUCT") || (routeId != "") || AdvisorQuoteIsOnAscProductPage(db)
    AdvisorQuoteAppendLog(
        "CONSUMER_REPORTS_ROUTE_CHECK",
        AdvisorQuoteGetLastStep(),
        "consumerReportsObservedState=" observedState
            . ", consumerReportsAscProductDetected=" (ascDetected ? "1" : "0")
            . ", consumerReportsAscProductRouteId=" routeId
    )
    if !ascDetected
        return "CONTINUE"

    currentUrlText := AdvisorQuoteAscProductRouteIdText(routeId)
    driversVehiclesDetected := AdvisorQuoteIsDriversVehiclesState(db)
    incidentsDetected := AdvisorQuoteIsIncidentsPage(db)
    quoteLandingDetected := AdvisorQuoteIsQuoteLandingPage(db)
    consumerReportsReady := (!driversVehiclesDetected && !incidentsDetected && !quoteLandingDetected) ? AdvisorQuoteIsConsumerReportsConsentPage(db) : false
    AdvisorQuoteAppendLog(
        "CONSUMER_REPORTS_ASC_PRODUCT_SUBSTATE",
        AdvisorQuoteGetLastStep(),
        "consumerReportsObservedState=" observedState
            . ", consumerReportsCurrentUrl=" currentUrlText
            . ", consumerReportsAscProductDetected=1"
            . ", consumerReportsAscProductRouteId=" routeId
            . ", consumerReportsDriversVehiclesEvidence=" (driversVehiclesDetected ? "1" : "0")
            . ", incidentsEvidence=" (incidentsDetected ? "1" : "0")
            . ", quoteLandingEvidence=" (quoteLandingDetected ? "1" : "0")
            . ", consumerReportsReadyEvidence=" (consumerReportsReady ? "1" : "0")
            . ", participantStatusResult=" AdvisorQuoteStatusValue(participantStatus, "result")
            . ", participantEvidence=" AdvisorQuoteStatusValue(participantStatus, "evidence")
    )

    if driversVehiclesDetected {
        AdvisorQuoteAppendLog(
            "CONSUMER_REPORTS_ROUTED_TO_DRIVERS_VEHICLES",
            AdvisorQuoteGetLastStep(),
            "consumerReportsRoutedToDriversVehicles=1"
                . ", ascDriversVehiclesHandlerInvoked=1"
                . ", consumerReportsReadyWaitSkippedReason=already-on-asc-drivers-vehicles"
        )
        handlerFailureReason := ""
        handlerFailureScan := ""
        if AdvisorQuoteHandleDriversVehicles(profile, db, &handlerFailureReason, &handlerFailureScan)
            return "OK"
        failureReason := (handlerFailureReason != "") ? handlerFailureReason : "ASC_DRIVERS_VEHICLES_HANDLER_FAILED"
        failureScan := (handlerFailureScan != "") ? handlerFailureScan : AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "asc-drivers-vehicles-handler-failed")
        return "FAILED"
    }

    if incidentsDetected || quoteLandingDetected
        return "ALREADY_SATISFIED"

    if consumerReportsReady
        return "CONTINUE"

    failureReason := "ASC_PRODUCT_SUBSTATE_UNKNOWN"
    failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "asc-product-substate-unknown")
    return "FAILED"
}

AdvisorQuoteProfileLooksUsable(profile) {
    if !IsObject(profile)
        return false
    if !profile.Has("person")
        return false
    person := profile["person"]
    return Trim(String(person["firstName"])) != "" && Trim(String(person["lastName"])) != ""
}

AdvisorQuoteOpenEntryFlow(db) {
    if StopRequested()
        return false

    state := AdvisorQuoteDetectState(db)
    AdvisorQuoteSetStep("ENTRY_FLOW", "Detected state: " state)
    if (state = "RAPPORT" || state = "SELECT_PRODUCT" || state = "ASC_PRODUCT" || state = "DUPLICATE" || state = "INCIDENTS" || state = "BEGIN_QUOTING_FORM")
        return true

    selectors := db["selectors"]
    timeouts := db["timeouts"]

    if (state = "ADVISOR_HOME" || state = "GATEWAY") {
        AdvisorQuoteClickById(selectors["advisorQuotingButtonId"], timeouts["actionMs"])
        if AdvisorQuoteWaitForAnyState(db, timeouts["transitionMs"]) {
            stateAfterQuoting := AdvisorQuoteDetectState(db)
            if (stateAfterQuoting = "BEGIN_QUOTING_SEARCH")
                return AdvisorQuoteOpenCreateNewProspectFromSearch(db)
            return true
        }
    }

    if (state = "BEGIN_QUOTING_SEARCH") {
        if AdvisorQuoteOpenCreateNewProspectFromSearch(db)
            return true
    }

    if (state = "ADVISOR_OTHER") {
        AdvisorQuoteClickByText("Create New Prospect", "button,a,input[type=button],input[type=submit]", timeouts["actionMs"])
        if AdvisorQuoteWaitForAnyState(db, timeouts["transitionMs"])
            return true
        stateAfterCreate := AdvisorQuoteDetectState(db)
        if (stateAfterCreate = "BEGIN_QUOTING_FORM")
            return true
    }

    AdvisorQuoteClickByText("Quoting", "button,a", timeouts["actionMs"])
    if AdvisorQuoteWaitForAnyState(db, timeouts["transitionMs"]) {
        stateAfterFallbackQuoting := AdvisorQuoteDetectState(db)
        if (stateAfterFallbackQuoting = "BEGIN_QUOTING_SEARCH")
            return AdvisorQuoteOpenCreateNewProspectFromSearch(db)
        return true
    }

    ready := AdvisorQuoteIsPastEntry(db)
    if !ready
        AdvisorQuoteAppendLog("ENTRY_FLOW_FAIL", AdvisorQuoteGetLastStep(), "Could not reach form/quote state from entry.")
    return ready
}

AdvisorQuoteOpenCreateNewProspectFromSearch(db) {
    selectors := db["selectors"]
    timeouts := db["timeouts"]
    AdvisorQuoteSetStep("ENTRY_FLOW", "Begin Quoting search detected; clicking Create New Prospect.")

    clicked := AdvisorQuoteClickById(selectors["searchCreateNewProspectId"], timeouts["actionMs"])
    if !clicked
        clicked := AdvisorQuoteClickByText("Create New Prospect", "button,a,input[type=button],input[type=submit]", timeouts["actionMs"])
    if !clicked {
        AdvisorQuoteAppendLog("ENTRY_CREATE_NEW_FAIL", AdvisorQuoteGetLastStep(), "Could not click Create New Prospect from search page.")
        return false
    }

    if AdvisorQuoteWaitForAnyState(db, timeouts["transitionMs"])
        return true

    stateAfterClick := AdvisorQuoteDetectState(db)
    if (stateAfterClick = "BEGIN_QUOTING_FORM" || stateAfterClick = "DUPLICATE" || stateAfterClick = "RAPPORT" || stateAfterClick = "SELECT_PRODUCT" || stateAfterClick = "ASC_PRODUCT")
        return true

    AdvisorQuoteAppendLog("ENTRY_CREATE_NEW_TIMEOUT", AdvisorQuoteGetLastStep(), "Clicked Create New Prospect but did not transition to form in time.")
    return false
}

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

AdvisorQuoteHandleProspect(profile, db) {
    AdvisorQuoteSetStep("PROSPECT_RESOLUTION", "Resolving prospect/create flow.")
    if AdvisorQuoteIsOnRapportPage(db) || AdvisorQuoteIsOnSelectProductPage(db) || AdvisorQuoteIsOnAscProductPage(db)
        return true

    if AdvisorQuoteIsDuplicatePage(db)
        return AdvisorQuoteHandleDuplicateProspect(profile, db)

    fields := profile["fields"]
    if !AdvisorQuoteWaitForProspectFormReady(db)
        return false

    if !AdvisorQuotePrimeProspectFormFill(db)
        return false

    if !AdvisorQuoteFillProspectForm(fields, db, 1)
        return false

    if AdvisorQuoteIsDuplicatePage(db)
        return AdvisorQuoteHandleDuplicateProspect(profile, db)

    status := AdvisorQuoteGetProspectFormStatus(db)
    if !AdvisorQuoteProspectFormReadyToSubmit(status, fields) {
        AdvisorQuoteAppendLog("PROSPECT_RETRY", AdvisorQuoteGetLastStep(), "Prospect form incomplete after first pass. Retrying fill.")
        if !AdvisorQuotePrimeProspectFormFill(db)
            return false
        if !AdvisorQuoteFillProspectForm(fields, db, 2)
            return false
        if AdvisorQuoteIsDuplicatePage(db)
            return AdvisorQuoteHandleDuplicateProspect(profile, db)
        status := AdvisorQuoteGetProspectFormStatus(db)
    }

    if !AdvisorQuoteProspectFormReadyToSubmit(status, fields) {
        AdvisorQuoteLogProspectStatus(status, "PROSPECT_INVALID")
        AdvisorQuoteScanCurrentPage()
        return false
    }

    AdvisorQuoteSetStep("PROSPECT_SUBMIT", "Submitting Create New Prospect form.")
    submitted := AdvisorQuoteClickCreateProspectPrimaryButton(db)
    if !submitted {
        AdvisorQuoteLogProspectStatus(status, "PROSPECT_SUBMIT_FAIL")
        AdvisorQuoteScanCurrentPage()
        AdvisorQuoteAppendLog("PROSPECT_SUBMIT_FAIL", AdvisorQuoteGetLastStep(), "Could not find a submit button after filling prospect form.")
        return false
    }

    waitArgs := Map(
        "rapportContains", db["urls"]["rapportContains"],
        "selectProductContains", db["urls"]["selectProductContains"]
    )
    if AdvisorQuoteWaitForCondition("post_prospect_submit", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
        if AdvisorQuoteIsDuplicatePage(db)
            return AdvisorQuoteHandleDuplicateProspect(profile, db)
        addressVerification := AdvisorQuoteResolveAddressVerification(profile, db, "prospect-submit", 0)
        if addressVerification["handled"]
            return addressVerification["ok"]
        return true
    }

    return AdvisorQuoteIsOnRapportPage(db) || AdvisorQuoteIsOnSelectProductPage(db) || AdvisorQuoteIsOnAscProductPage(db)
}

AdvisorQuoteWaitForProspectFormReady(db, timeoutMs := 0) {
    if (timeoutMs <= 0)
        timeoutMs := db["timeouts"]["transitionMs"]
    args := Map("selectors", db["selectors"])
    ready := AdvisorQuoteWaitForCondition("prospect_form_ready", timeoutMs, db["timeouts"]["pollMs"], args)
    if !ready {
        AdvisorQuoteAppendLog("PROSPECT_READY_FAIL", AdvisorQuoteGetLastStep(), "Prospect form did not become ready.")
        AdvisorQuoteScanCurrentPage()
    }
    return ready
}

AdvisorQuotePrimeProspectFormFill(db) {
    global PROSPECT_TOOLTIP_DELAY

    if !AdvisorQuoteFocusProspectFirstInput(db) {
        AdvisorQuoteAppendLog("PROSPECT_FOCUS_FAIL", AdvisorQuoteGetLastStep(), "Could not focus the first name input.")
        return false
    }

    leadInMs := Integer(PROSPECT_TOOLTIP_DELAY ?? 0)
    if (leadInMs > 0)
        return SafeSleep(leadInMs)
    return true
}

AdvisorQuoteFillProspectForm(fields, db, passNumber := 1) {
    AdvisorQuoteAppendLog("PROSPECT_FILL", AdvisorQuoteGetLastStep(), "pass=" passNumber)
    if !AdvisorQuoteRefocusPageForNativeInput("prospect-form-fill-pass-" passNumber)
        return false
    FillNewProspectForm(fields)
    if !SafeSleep(250)
        return false
    return true
}

AdvisorQuoteFocusProspectFirstInput(db) {
    result := AdvisorQuoteRunOp("focus_prospect_first_input", Map())
    if (result = "1")
        return true
    return AdvisorQuoteClickByText("First Name", "label,span,div", db["timeouts"]["actionMs"])
}

AdvisorQuoteGetProspectFormStatus(db) {
    raw := AdvisorQuoteRunOp("prospect_form_status", Map("selectors", db["selectors"]), 2, 150)
    return AdvisorQuoteParseKeyValueLines(raw)
}

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

AdvisorQuoteProspectFormReadyToSubmit(status, fields) {
    if !IsObject(status) || status.Count = 0
        return false
    if (AdvisorQuoteStatusValue(status, "ready") != "1")
        return false
    if (AdvisorQuoteStatusValue(status, "submitPresent") != "1")
        return false
    if (AdvisorQuoteStatusValue(status, "submitEnabled") != "1")
        return false
    if (Trim(AdvisorQuoteStatusValue(status, "errors")) != "")
        return false

    return AdvisorQuoteProspectFieldMatches(AdvisorQuoteStatusValue(status, "firstName"), fields["FIRST_NAME"])
        && AdvisorQuoteProspectFieldMatches(AdvisorQuoteStatusValue(status, "lastName"), fields["LAST_NAME"])
        && AdvisorQuoteProspectDobMatches(AdvisorQuoteStatusValue(status, "dob"), fields["DOB"])
        && AdvisorQuoteProspectFieldMatches(AdvisorQuoteStatusValue(status, "address"), fields["ADDRESS_1"])
        && AdvisorQuoteProspectFieldMatches(AdvisorQuoteStatusValue(status, "city"), fields["CITY"])
        && AdvisorQuoteProspectStateMatches(AdvisorQuoteStatusValue(status, "state"), fields["STATE"])
        && AdvisorQuoteProspectZipMatches(AdvisorQuoteStatusValue(status, "zip"), fields["ZIP"])
}

AdvisorQuoteProspectFieldMatches(actual, expected) {
    wanted := AdvisorNormalizeLooseToken(expected)
    if (wanted = "")
        return true
    have := AdvisorNormalizeLooseToken(actual)
    return have = wanted
}

AdvisorQuoteProspectDobMatches(actual, expected) {
    wanted := NormalizeDOB(expected)
    if (wanted = "")
        return true
    have := NormalizeDOB(actual)
    return have = wanted
}

AdvisorQuoteProspectStateMatches(actual, expected) {
    wanted := NormalizeState(expected)
    if (wanted = "")
        return true
    have := NormalizeState(actual)
    return have = wanted
}

AdvisorQuoteProspectZipMatches(actual, expected) {
    wanted := NormalizeZip(expected)
    if (wanted = "")
        return true
    have := NormalizeZip(actual)
    return have = wanted
}

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

AdvisorQuoteGetGatherRapportSnapshot() {
    status := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_rapport_snapshot", AdvisorQuoteSnapshotArgs(), 2, 120))
    AdvisorQuoteAppendLog("GATHER_RAPPORT_SNAPSHOT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherRapportSnapshotDetail(status))
    return status
}

AdvisorQuoteBuildGatherRapportSnapshotDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily")
        . ", activeModalType=" AdvisorQuoteStatusValue(status, "activeModalType")
        . ", activePanelType=" AdvisorQuoteStatusValue(status, "activePanelType")
        . ", saveGate=" AdvisorQuoteStatusValue(status, "saveGate")
        . ", vehicleWarningPresent=" AdvisorQuoteStatusValue(status, "vehicleWarningPresent")
        . ", confirmedVehicleCount=" AdvisorQuoteStatusValue(status, "confirmedVehicleCount")
        . ", potentialVehicleCount=" AdvisorQuoteStatusValue(status, "potentialVehicleCount")
        . ", editVehiclePanelPresent=" AdvisorQuoteStatusValue(status, "editVehiclePanelPresent")
        . ", editVehicleStatus=" AdvisorQuoteStatusValue(status, "editVehicleStatus")
        . ", editVehicleUpdatePresent=" AdvisorQuoteStatusValue(status, "editVehicleUpdatePresent")
        . ", editVehicleUpdateEnabled=" AdvisorQuoteStatusValue(status, "editVehicleUpdateEnabled")
        . ", editVehicleRequiredComplete=" AdvisorQuoteStatusValue(status, "editVehicleRequiredComplete")
        . ", staleAddRowPresent=" AdvisorQuoteStatusValue(status, "staleAddRowPresent")
        . ", startQuotingSectionPresent=" AdvisorQuoteStatusValue(status, "startQuotingSectionPresent")
        . ", createQuotesEnabled=" AdvisorQuoteStatusValue(status, "createQuotesEnabled")
        . ", blockerCode=" AdvisorQuoteStatusValue(status, "blockerCode")
        . ", nextRecommendedReadOnlyStatus=" AdvisorQuoteStatusValue(status, "nextRecommendedReadOnlyStatus")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

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

AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, attemptCount, routedToEditVehicle := "0", afterResult := "") {
    return "rapportSnapshotActiveModalType=" AdvisorQuoteStatusValue(snapshot, "activeModalType")
        . ", rapportSnapshotActivePanelType=" AdvisorQuoteStatusValue(snapshot, "activePanelType")
        . ", rapportSnapshotBlockerCode=" AdvisorQuoteStatusValue(snapshot, "blockerCode")
        . ", rapportSnapshotEditUpdateEnabled=" AdvisorQuoteStatusValue(snapshot, "editVehicleUpdateEnabled")
        . ", rapportSnapshotRoutedToEditVehicle=" routedToEditVehicle
        . ", rapportSnapshotAfterEditResult=" afterResult
        . ", rapportSnapshotRouteAttemptCount=" attemptCount
        . ", editVehiclePanelPresent=" AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent")
        . ", editVehicleStatus=" AdvisorQuoteStatusValue(snapshot, "editVehicleStatus")
        . ", editVehicleYear=" AdvisorQuoteStatusValue(snapshot, "editVehicleYear")
        . ", editVehicleMake=" AdvisorQuoteStatusValue(snapshot, "editVehicleMake")
        . ", editVehicleModel=" AdvisorQuoteStatusValue(snapshot, "editVehicleModel")
}

AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(snapshot) {
    activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
    activePanelType := AdvisorQuoteStatusValue(snapshot, "activePanelType")
    blockerCode := AdvisorQuoteStatusValue(snapshot, "blockerCode")
    return blockerCode = "GATHER_STALE_ADD_VEHICLE_ROW_OPEN"
        || activeModalType = "GATHER_STALE_ADD_VEHICLE_ROW"
        || activePanelType = "GATHER_STALE_ADD_VEHICLE_ROW"
}

AdvisorQuoteGatherStaleBlockerActiveScopeSafe(snapshot) {
    activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
    activePanelType := AdvisorQuoteStatusValue(snapshot, "activePanelType")
    modalSafe := activeModalType = "" || activeModalType = "NONE" || activeModalType = "GATHER_STALE_ADD_VEHICLE_ROW"
    panelSafe := activePanelType = "" || activePanelType = "NONE" || activePanelType = "GATHER_STALE_ADD_VEHICLE_ROW"
    return modalSafe && panelSafe
}

AdvisorQuoteGatherStaleAddRowStatusSafeForCancel(status, snapshot, &unsafeReason := "") {
    unsafeReason := ""
    result := AdvisorQuoteStatusValue(status, "result")
    safeResult := result = "FOUND" || result = "OK" || result = "READY"
    if !safeResult {
        unsafeReason := "status-not-ready:" result
        return false
    }
    if !AdvisorQuoteGatherStaleBlockerActiveScopeSafe(snapshot) {
        unsafeReason := "unknown-active-modal-or-panel"
        return false
    }
    if (AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent") = "1"
        || AdvisorQuoteStatusValue(snapshot, "activeModalType") = "GATHER_EDIT_VEHICLE"
        || AdvisorQuoteStatusValue(snapshot, "activePanelType") = "GATHER_EDIT_VEHICLE") {
        unsafeReason := "edit-vehicle-panel-active"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "rowIncomplete") != "1") {
        unsafeReason := "row-not-incomplete"
        return false
    }
    if (StrLower(AdvisorQuoteStatusValue(status, "rowTitle")) != "add car or truck") {
        unsafeReason := "not-gather-add-car-truck-row"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "cancelButtonScoped") != "1") {
        unsafeReason := "cancel-button-not-scoped"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "safeToCancel") != "1") {
        unsafeReason := "operator-unsafe:" AdvisorQuoteStatusValue(status, "reason")
        return false
    }
    return true
}

AdvisorQuoteRapportSubModelPlaceholderFallbackEnabled(db) {
    if !(IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]))
        return true
    if !db["defaults"].Has("rapportAllowSubModelPlaceholderFallback")
        return true
    value := Trim(String(db["defaults"]["rapportAllowSubModelPlaceholderFallback"]))
    return !(StrLower(value) = "false" || value = "0" || StrLower(value) = "no")
}

AdvisorQuoteRapportSubModelFallbackMode(db) {
    mode := ""
    if (IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]) && db["defaults"].Has("rapportSubModelFallbackMode"))
        mode := Trim(String(db["defaults"]["rapportSubModelFallbackMode"]))
    return mode = "first-valid" ? mode : "first-valid"
}

AdvisorQuoteRapportModelPlaceholderFallbackEnabled(db) {
    if !(IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]))
        return true
    if !db["defaults"].Has("rapportAllowModelPlaceholderFallback")
        return true
    value := Trim(String(db["defaults"]["rapportAllowModelPlaceholderFallback"]))
    return !(StrLower(value) = "false" || value = "0" || StrLower(value) = "no")
}

AdvisorQuoteRapportModelFallbackMode(db) {
    mode := ""
    if (IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]) && db["defaults"].Has("rapportModelFallbackMode"))
        mode := Trim(String(db["defaults"]["rapportModelFallbackMode"]))
    return mode = "first-valid-same-make" ? mode : "first-valid-same-make"
}

AdvisorQuoteStatusFieldPresent(status, valueKey, presentKey := "") {
    if (AdvisorQuoteStatusValue(status, valueKey) != "")
        return true
    return presentKey != "" && AdvisorQuoteStatusValue(status, presentKey) = "1"
}

AdvisorQuoteGatherStaleAddRowStatusResumeableForSubModelFallback(status, snapshot, &unsafeReason := "") {
    unsafeReason := ""
    result := AdvisorQuoteStatusValue(status, "result")
    if (result != "FOUND") {
        unsafeReason := "status-not-readable:" result
        return false
    }
    if !AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(snapshot) {
        unsafeReason := "stale-add-row-blocker-not-active"
        return false
    }
    if (AdvisorQuoteStatusValue(snapshot, "staleAddRowPresent") != "1") {
        unsafeReason := "stale-add-row-not-present"
        return false
    }
    if !AdvisorQuoteGatherStaleBlockerActiveScopeSafe(snapshot) {
        unsafeReason := "unknown-active-modal-or-panel"
        return false
    }
    if (AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent") = "1"
        || AdvisorQuoteStatusValue(snapshot, "activeModalType") = "GATHER_EDIT_VEHICLE"
        || AdvisorQuoteStatusValue(snapshot, "activePanelType") = "GATHER_EDIT_VEHICLE") {
        unsafeReason := "edit-vehicle-panel-active"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "unsafeContext") = "1") {
        unsafeReason := "confirmed-or-potential-vehicle-context"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "rowIncomplete") != "1") {
        unsafeReason := "row-not-incomplete"
        return false
    }
    if !AdvisorQuoteStatusFieldPresent(status, "yearValue", "yearPresent") {
        unsafeReason := "year-missing"
        return false
    }
    if !AdvisorQuoteStatusFieldPresent(status, "manufacturerValue", "manufacturerPresent") {
        unsafeReason := "manufacturer-missing"
        return false
    }
    if !AdvisorQuoteStatusFieldPresent(status, "modelValue", "modelPresent") {
        unsafeReason := "model-missing"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "subModelPresent") != "1") {
        unsafeReason := "submodel-missing"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "subModelPlaceholderSelected") != "1") {
        unsafeReason := "submodel-already-selected"
        return false
    }
    if (AdvisorQuoteStatusInteger(status, "subModelOptionCount") < 1
        || AdvisorQuoteStatusValue(status, "subModelFirstValidOptionPresent") != "1") {
        unsafeReason := "submodel-no-options"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "addButtonPresent") != "1") {
        unsafeReason := "add-button-missing"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "addButtonEnabled") != "1") {
        unsafeReason := "add-button-disabled"
        return false
    }
    return true
}

AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(status, snapshot) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", rowTitle=" AdvisorQuoteStatusValue(status, "rowTitle")
        . ", rowIncomplete=" AdvisorQuoteStatusValue(status, "rowIncomplete")
        . ", yearPresent=" (AdvisorQuoteStatusValue(status, "yearValue") != "" ? "1" : "0")
        . ", manufacturerPresent=" (AdvisorQuoteStatusValue(status, "manufacturerValue") != "" ? "1" : "0")
        . ", modelPresent=" (AdvisorQuoteStatusValue(status, "modelValue") != "" ? "1" : "0")
        . ", subModelPresent=" AdvisorQuoteStatusValue(status, "subModelPresent")
        . ", subModelPlaceholderSelected=" AdvisorQuoteStatusValue(status, "subModelPlaceholderSelected")
        . ", subModelOptionCount=" AdvisorQuoteStatusValue(status, "subModelOptionCount")
        . ", subModelFirstValidOptionPresent=" AdvisorQuoteStatusValue(status, "subModelFirstValidOptionPresent")
        . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
        . ", addButtonEnabled=" AdvisorQuoteStatusValue(status, "addButtonEnabled")
        . ", cancelButtonPresent=" AdvisorQuoteStatusValue(status, "cancelButtonPresent")
        . ", cancelButtonScoped=" AdvisorQuoteStatusValue(status, "cancelButtonScoped")
        . ", unsafeContext=" AdvisorQuoteStatusValue(status, "unsafeContext")
        . ", safeToCancel=" AdvisorQuoteStatusValue(status, "safeToCancel")
        . ", reason=" AdvisorQuoteStatusValue(status, "reason")
        . ", activeModalType=" AdvisorQuoteStatusValue(snapshot, "activeModalType")
        . ", activePanelType=" AdvisorQuoteStatusValue(snapshot, "activePanelType")
        . ", blockerCode=" AdvisorQuoteStatusValue(snapshot, "blockerCode")
        . ", editVehiclePanelPresent=" AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent")
        . ", staleAddRowPresent=" AdvisorQuoteStatusValue(snapshot, "staleAddRowPresent")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", selectedIndex=" AdvisorQuoteStatusValue(status, "selectedIndex")
        . ", selectedValuePresent=" AdvisorQuoteStatusValue(status, "selectedValuePresent")
        . ", selectedMode=" AdvisorQuoteStatusValue(status, "selectedMode")
        . ", optionCount=" AdvisorQuoteStatusValue(status, "optionCount")
        . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
        . ", addButtonEnabled=" AdvisorQuoteStatusValue(status, "addButtonEnabled")
}

AdvisorQuoteBuildGatherAddRowAddClickDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
        . ", addButtonEnabled=" AdvisorQuoteStatusValue(status, "addButtonEnabled")
}

AdvisorQuoteBuildGatherStaleVehicleCancelSafetyDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", afterRowPresent=" AdvisorQuoteStatusValue(status, "afterRowPresent")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
}

AdvisorQuoteFindGatherEditVehicleForSnapshot(snapshot, actionableVehicles) {
    if !IsObject(actionableVehicles)
        return ""
    year := AdvisorQuoteStatusValue(snapshot, "editVehicleYear")
    make := AdvisorQuoteStatusValue(snapshot, "editVehicleMake")
    model := AdvisorQuoteStatusValue(snapshot, "editVehicleModel")
    if (year = "" || make = "" || model = "")
        return ""

    targetMake := AdvisorVehicleNormalizeMake(make)
    targetModelKey := AdvisorVehicleDbNormalizeModelKey(model)
    matches := []
    for _, vehicle in actionableVehicles {
        vehicleYear := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
        vehicleMake := IsObject(vehicle) && vehicle.Has("make") ? AdvisorVehicleNormalizeMake(vehicle["make"]) : ""
        vehicleModel := IsObject(vehicle) && vehicle.Has("model") ? AdvisorVehicleDbNormalizeModelKey(vehicle["model"]) : ""
        if (vehicleYear = year && vehicleMake = targetMake && vehicleModel = targetModelKey)
            matches.Push(vehicle)
    }
    return (matches.Length = 1) ? matches[1] : ""
}

AdvisorQuoteResolveGatherSnapshotBlockers(actionableVehicles, db, &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    staleCancelRows := Map()
    Loop 2 {
        snapshot := AdvisorQuoteGetGatherRapportSnapshot()
        activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
        blockerCode := AdvisorQuoteStatusValue(snapshot, "blockerCode")
        updateEnabled := AdvisorQuoteStatusValue(snapshot, "editVehicleUpdateEnabled")
        AdvisorQuoteAppendLog(
            "RAPPORT_SNAPSHOT_GATE",
            AdvisorQuoteGetLastStep(),
            AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "0")
        )

        if (AdvisorQuoteStatusValue(snapshot, "result") != "OK") {
            failureReason := "RAPPORT_SNAPSHOT_UNREADABLE: " AdvisorQuoteBuildGatherRapportSnapshotDetail(snapshot)
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-snapshot-unreadable")
            return false
        }
        if AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(snapshot) {
            staleStatus := AdvisorQuoteGetGatherStaleAddVehicleRowStatus(true)
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_STATUS",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
            )
            resumeUnsafeReason := ""
            if AdvisorQuoteGatherStaleAddRowStatusResumeableForSubModelFallback(staleStatus, snapshot, &resumeUnsafeReason) {
                if !AdvisorQuoteRapportSubModelPlaceholderFallbackEnabled(db) {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_FALLBACK_DISABLED: "
                        . AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-fallback-disabled")
                    return false
                }

                selectStatus := AdvisorQuoteSelectGatherAddRowFirstValidSubModel(true)
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_SUBMODEL_PLACEHOLDER_SELECTED",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(selectStatus)
                        . ", fallbackMode=" AdvisorQuoteRapportSubModelFallbackMode(db)
                )
                if (AdvisorQuoteStatusValue(selectStatus, "result") = "NO_OPTIONS") {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_NO_OPTIONS: " AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(selectStatus)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-no-options")
                    return false
                }
                if (AdvisorQuoteStatusValue(selectStatus, "result") != "OK"
                    || AdvisorQuoteStatusValue(selectStatus, "selectedValuePresent") != "1") {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_SELECT_FAILED: " AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(selectStatus)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-select-failed")
                    return false
                }

                afterSelectStatus := AdvisorQuoteGetGatherStaleAddVehicleRowStatus(true)
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_AFTER_SUBMODEL_STATUS",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(afterSelectStatus, snapshot)
                )
                if (AdvisorQuoteStatusValue(afterSelectStatus, "subModelPlaceholderSelected") = "1") {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_SELECT_FAILED: subModel remained placeholder. "
                        . AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(afterSelectStatus, snapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-select-verify-failed")
                    return false
                }
                if (AdvisorQuoteStatusValue(afterSelectStatus, "addButtonPresent") != "1"
                    || AdvisorQuoteStatusValue(afterSelectStatus, "addButtonEnabled") != "1") {
                    failureReason := "RAPPORT_ADD_ROW_ADD_BUTTON_DISABLED: "
                        . AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(afterSelectStatus, snapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-button-disabled")
                    return false
                }

                addStatus := AdvisorQuoteClickGatherAddRowAddButton(true)
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_ADD_CLICKED",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildGatherAddRowAddClickDetail(addStatus)
                )
                if (AdvisorQuoteStatusValue(addStatus, "result") != "CLICKED"
                    || AdvisorQuoteStatusValue(addStatus, "clicked") != "1") {
                    failureReason := "RAPPORT_ADD_ROW_ADD_BUTTON_DISABLED: " AdvisorQuoteBuildGatherAddRowAddClickDetail(addStatus)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-click-failed")
                    return false
                }

                afterSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
                afterResult := AdvisorQuoteStatusValue(afterSnapshot, "result")
                afterEditOpen := AdvisorQuoteStatusValue(afterSnapshot, "activeModalType") = "GATHER_EDIT_VEHICLE"
                    || AdvisorQuoteStatusValue(afterSnapshot, "activePanelType") = "GATHER_EDIT_VEHICLE"
                    || AdvisorQuoteStatusValue(afterSnapshot, "editVehiclePanelPresent") = "1"
                afterRowClosed := AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent") != "1"
                    || !AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(afterSnapshot)
                afterCountsChanged := AdvisorQuoteStatusValue(afterSnapshot, "confirmedVehicleCount") != AdvisorQuoteStatusValue(snapshot, "confirmedVehicleCount")
                    || AdvisorQuoteStatusValue(afterSnapshot, "potentialVehicleCount") != AdvisorQuoteStatusValue(snapshot, "potentialVehicleCount")
                afterGateChanged := AdvisorQuoteStatusValue(afterSnapshot, "vehicleWarningPresent") != AdvisorQuoteStatusValue(snapshot, "vehicleWarningPresent")
                    || AdvisorQuoteStatusValue(afterSnapshot, "startQuotingSectionPresent") != AdvisorQuoteStatusValue(snapshot, "startQuotingSectionPresent")
                    || AdvisorQuoteStatusValue(afterSnapshot, "createQuotesEnabled") != AdvisorQuoteStatusValue(snapshot, "createQuotesEnabled")
                    || AdvisorQuoteStatusValue(afterSnapshot, "blockerCode") != AdvisorQuoteStatusValue(snapshot, "blockerCode")
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_REENTERING_VALIDATION_FLOW",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, afterEditOpen ? "1" : "0", afterResult)
                        . ", addRowClosed=" (afterRowClosed ? "1" : "0")
                        . ", countsChanged=" (afterCountsChanged ? "1" : "0")
                        . ", gateChanged=" (afterGateChanged ? "1" : "0")
                )
                if (afterResult != "OK" || !(afterRowClosed || afterEditOpen || afterCountsChanged || afterGateChanged)) {
                    failureReason := "RAPPORT_ADD_ROW_ADD_VERIFY_FAILED: " AdvisorQuoteBuildGatherRapportSnapshotDetail(afterSnapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-verify-failed")
                    return false
                }
                if afterEditOpen {
                    vehicle := AdvisorQuoteFindGatherEditVehicleForSnapshot(afterSnapshot, actionableVehicles)
                    if !IsObject(vehicle) {
                        failureReason := "GATHER_EDIT_VEHICLE_NO_MATCHING_LEAD_VEHICLE: active Edit Vehicle panel could not be matched to exactly one actionable lead vehicle. " AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, "1")
                        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-no-matching-lead")
                        return false
                    }
                    editFailureReason := ""
                    editFailureScanPath := ""
                    editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &editFailureReason, &editFailureScanPath, "snapshot-gate-after-add-row")
                    finalSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
                    AdvisorQuoteAppendLog(
                        "RAPPORT_SNAPSHOT_EDIT_ROUTE_RESULT",
                        AdvisorQuoteGetLastStep(),
                        AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, "1", AdvisorQuoteStatusValue(finalSnapshot, "result"))
                            . ", routedVehicle=" AdvisorQuoteVehicleLabel(vehicle)
                            . ", editOutcome=" editOutcome
                            . ", rapportSnapshotAfterActiveModalType=" AdvisorQuoteStatusValue(finalSnapshot, "activeModalType")
                            . ", rapportSnapshotAfterBlockerCode=" AdvisorQuoteStatusValue(finalSnapshot, "blockerCode")
                            . ", rapportSnapshotAfterEditUpdateEnabled=" AdvisorQuoteStatusValue(finalSnapshot, "editVehicleUpdateEnabled")
                    )
                    if (editOutcome = "FAILED") {
                        failureReason := editFailureReason
                        failureScanPath := editFailureScanPath
                        if (failureReason = "")
                            failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_FAILED"
                        if (failureScanPath = "")
                            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-snapshot-route-failed")
                        return false
                    }
                }
                return true
            }

            if (resumeUnsafeReason = "submodel-no-options") {
                failureReason := "RAPPORT_ADD_ROW_SUBMODEL_NO_OPTIONS: " AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-no-options")
                return false
            }
            if (resumeUnsafeReason = "add-button-disabled") {
                failureReason := "RAPPORT_ADD_ROW_ADD_BUTTON_DISABLED: " AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-button-disabled")
                return false
            }

            cancelUnsafeReason := ""
            rowEmptyForCancel := AdvisorQuoteStatusValue(staleStatus, "yearValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "vinValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "manufacturerValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "modelValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "subModelValue") = ""
            if !(rowEmptyForCancel && AdvisorQuoteGatherStaleAddRowStatusSafeForCancel(staleStatus, snapshot, &cancelUnsafeReason)) {
                failureReason := "RAPPORT_STALE_ADD_ROW_UNSAFE: " resumeUnsafeReason
                    . ". " AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-unsafe")
                return false
            }

            staleCancelKey := AdvisorQuoteStatusValue(staleStatus, "rowIndex")
            if (staleCancelKey != "" && staleCancelRows.Has(staleCancelKey)) {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_LOOP_GUARD: repeated rowIndex=" staleCancelKey
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-loop-guard")
                return false
            }
            if (staleCancelKey != "")
                staleCancelRows[staleCancelKey] := true
            cancelStatus := AdvisorQuoteCancelStaleAddVehicleRow(true)
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_CANCEL",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildGatherStaleVehicleCancelSafetyDetail(cancelStatus)
            )
            if (AdvisorQuoteStatusValue(cancelStatus, "result") != "CANCELLED") {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_FAILED: "
                    . AdvisorQuoteBuildGatherStaleVehicleCancelSafetyDetail(cancelStatus)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-failed")
                return false
            }

            afterSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
            afterResult := AdvisorQuoteStatusValue(afterSnapshot, "result")
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_CANCEL_VERIFY",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, "0", afterResult)
                    . ", staleAddRowPresent=" AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent")
            )
            if (afterResult != "OK") {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_VERIFY_UNREADABLE: "
                    . AdvisorQuoteBuildGatherRapportSnapshotDetail(afterSnapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-verify-unreadable")
                return false
            }
            if (AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent") = "1"
                && AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(afterSnapshot)) {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_VERIFY_FAILED: "
                    . AdvisorQuoteBuildGatherRapportSnapshotDetail(afterSnapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-verify-failed")
                return false
            }
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_CANCELLED",
                AdvisorQuoteGetLastStep(),
                "attemptCount=" A_Index
                    . ", afterActiveModalType=" AdvisorQuoteStatusValue(afterSnapshot, "activeModalType")
                    . ", afterActivePanelType=" AdvisorQuoteStatusValue(afterSnapshot, "activePanelType")
                    . ", afterBlockerCode=" AdvisorQuoteStatusValue(afterSnapshot, "blockerCode")
                    . ", afterStaleAddRowPresent=" AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent")
            )
            return true
        }
        if (activeModalType = "" || activeModalType = "NONE")
            return true

        if (activeModalType != "GATHER_EDIT_VEHICLE") {
            failureReason := "RAPPORT_ACTIVE_BLOCKER_UNHANDLED: activeModalType=" activeModalType ", blockerCode=" blockerCode
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-active-blocker-unhandled")
            AdvisorQuoteAppendLog(
                "RAPPORT_SNAPSHOT_BLOCKER_UNHANDLED",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "0")
            )
            return false
        }

        vehicle := AdvisorQuoteFindGatherEditVehicleForSnapshot(snapshot, actionableVehicles)
        if !IsObject(vehicle) {
            failureReason := "GATHER_EDIT_VEHICLE_NO_MATCHING_LEAD_VEHICLE: active Edit Vehicle panel could not be matched to exactly one actionable lead vehicle. " AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "0")
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-no-matching-lead")
            return false
        }

        editFailureReason := ""
        editFailureScanPath := ""
        editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &editFailureReason, &editFailureScanPath, "snapshot-gate")
        afterSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
        afterActiveModalType := AdvisorQuoteStatusValue(afterSnapshot, "activeModalType")
        afterResult := AdvisorQuoteStatusValue(afterSnapshot, "result")
        AdvisorQuoteAppendLog(
            "RAPPORT_SNAPSHOT_EDIT_ROUTE_RESULT",
            AdvisorQuoteGetLastStep(),
            AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "1", afterResult)
                . ", routedVehicle=" AdvisorQuoteVehicleLabel(vehicle)
                . ", editOutcome=" editOutcome
                . ", rapportSnapshotAfterActiveModalType=" afterActiveModalType
                . ", rapportSnapshotAfterBlockerCode=" AdvisorQuoteStatusValue(afterSnapshot, "blockerCode")
                . ", rapportSnapshotAfterEditUpdateEnabled=" AdvisorQuoteStatusValue(afterSnapshot, "editVehicleUpdateEnabled")
        )

        if (editOutcome = "FAILED") {
            failureReason := editFailureReason
            failureScanPath := editFailureScanPath
            if (failureReason = "")
                failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_FAILED"
            if (failureScanPath = "")
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-snapshot-route-failed")
            return false
        }
        if (afterResult = "OK" && afterActiveModalType != "GATHER_EDIT_VEHICLE" && AdvisorQuoteStatusValue(afterSnapshot, "editVehiclePanelPresent") != "1")
            return true
        if !SafeSleep(db["timeouts"]["pollMs"]) {
            failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_WAIT_FAILED"
            return false
        }
    }

    failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_GUARD: Edit Vehicle panel remained active after two snapshot-routed attempts."
    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-snapshot-route-guard")
    return false
}

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

AdvisorQuotePostProspectSubmitStates() {
    return ["DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"]
}

AdvisorQuoteShouldCheckCustomerSummaryOverviewFallback(state) {
    normalized := Trim(String(state ?? ""))
    return normalized = "" || normalized = "ADVISOR_OTHER" || normalized = "UNKNOWN" || normalized = "NO_CONTEXT"
}

AdvisorQuoteGetCustomerSummaryOverviewStatus(db) {
    args := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("customer_summary_overview_status", args, 2, 120))
}

AdvisorQuoteCustomerSummaryStatusHighConfidence(status) {
    return AdvisorQuoteStatusValue(status, "result") = "DETECTED"
        && AdvisorQuoteStatusValue(status, "runtimeState") = "CUSTOMER_SUMMARY_OVERVIEW"
        && AdvisorQuoteStatusValue(status, "confidence") = "high"
        && AdvisorQuoteStatusValue(status, "urlMatched") = "1"
        && AdvisorQuoteStatusValue(status, "startHereMatched") = "1"
        && AdvisorQuoteStatusValue(status, "summaryAnchorMatched") = "1"
}

AdvisorQuoteCustomerSummaryStatusForwardConfidence(status) {
    result := AdvisorQuoteStatusValue(status, "result")
    confidence := AdvisorQuoteStatusValue(status, "confidence")
    return (result = "DETECTED" || result = "PARTIAL")
        && (confidence = "high" || confidence = "medium")
        && AdvisorQuoteStatusValue(status, "urlMatched") = "1"
        && AdvisorQuoteStatusValue(status, "overviewMatched") = "1"
        && AdvisorQuoteStatusValue(status, "startHereMatched") = "1"
}

AdvisorQuoteCustomerSummaryStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", runtimeState=" AdvisorQuoteStatusValue(status, "runtimeState")
        . ", confidence=" AdvisorQuoteStatusValue(status, "confidence")
        . ", urlMatched=" AdvisorQuoteStatusValue(status, "urlMatched")
        . ", overviewMatched=" AdvisorQuoteStatusValue(status, "overviewMatched")
        . ", startHereMatched=" AdvisorQuoteStatusValue(status, "startHereMatched")
        . ", quoteHistoryMatched=" AdvisorQuoteStatusValue(status, "quoteHistoryMatched")
        . ", assetsDetailsMatched=" AdvisorQuoteStatusValue(status, "assetsDetailsMatched")
        . ", summaryAnchorMatched=" AdvisorQuoteStatusValue(status, "summaryAnchorMatched")
        . ", startHereCount=" AdvisorQuoteStatusValue(status, "startHereCount")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
        . ", url=" AdvisorQuoteStatusValue(status, "url")
}

AdvisorQuoteTryCustomerSummaryOverviewFallback(db, context, &status := "") {
    status := AdvisorQuoteGetCustomerSummaryOverviewStatus(db)
    AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ROUTE_STATUS", AdvisorQuoteGetLastStep(), "context=" context . ", " . AdvisorQuoteCustomerSummaryStatusDetail(status))
    if AdvisorQuoteCustomerSummaryStatusForwardConfidence(status) {
        AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ROUTE_FALLBACK_ACCEPTED", AdvisorQuoteGetLastStep(), "context=" context . ", " . AdvisorQuoteCustomerSummaryStatusDetail(status))
        return true
    }

    if (AdvisorQuoteStatusValue(status, "confidence") = "low") {
        Loop 3 {
            AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ROUTE_FALLBACK_WAIT", AdvisorQuoteGetLastStep(), "context=" context . ", attempt=" A_Index "/3, " . AdvisorQuoteCustomerSummaryStatusDetail(status))
            if !SafeSleep(400)
                return false
            status := AdvisorQuoteGetCustomerSummaryOverviewStatus(db)
            AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ROUTE_STATUS", AdvisorQuoteGetLastStep(), "context=" context "-retry-" A_Index . ", " . AdvisorQuoteCustomerSummaryStatusDetail(status))
            if AdvisorQuoteCustomerSummaryStatusForwardConfidence(status) {
                AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ROUTE_FALLBACK_ACCEPTED", AdvisorQuoteGetLastStep(), "context=" context . ", " . AdvisorQuoteCustomerSummaryStatusDetail(status))
                return true
            }
        }
    }

    AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ROUTE_FALLBACK_REJECTED", AdvisorQuoteGetLastStep(), "context=" context . ", " . AdvisorQuoteCustomerSummaryStatusDetail(status))
    return false
}

AdvisorQuoteClickCustomerSummaryStartHere(db) {
    args := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("click_customer_summary_start_here", args, 2, 200))
}

AdvisorQuoteCustomerSummaryStartHereClickDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", targetText=" AdvisorQuoteStatusValue(status, "targetText")
        . ", targetTag=" AdvisorQuoteStatusValue(status, "targetTag")
        . ", targetClass=" AdvisorQuoteStatusValue(status, "targetClass")
        . ", urlBefore=" AdvisorQuoteStatusValue(status, "urlBefore")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
}

AdvisorQuoteCustomerSummaryUnconfirmedReason(stateName) {
    return (stateName = "ENTRY_CREATE_FORM")
        ? "ENTRY_CREATE_FORM_EXPECTED_FORM_BUT_CUSTOMER_SUMMARY_UNCONFIRMED"
        : "CUSTOMER_SUMMARY_OVERVIEW_UNCONFIRMED"
}

AdvisorQuoteCustomerSummaryStartHereFailureReason(clickStatus, stateName := "ENTRY_CREATE_FORM") {
    result := AdvisorQuoteStatusValue(clickStatus, "result")
    switch result {
        case "NO_START_HERE":
            return "CUSTOMER_SUMMARY_START_HERE_NOT_FOUND"
        case "CLICK_FAILED":
            return "CUSTOMER_SUMMARY_START_HERE_CLICK_FAILED"
        case "NO_CUSTOMER_SUMMARY":
            return AdvisorQuoteCustomerSummaryUnconfirmedReason(stateName)
        default:
            return "CUSTOMER_SUMMARY_START_HERE_CLICK_FAILED"
    }
}

AdvisorQuoteForwardCustomerSummaryToProductOverview(db, stateName, context, entryScanPath := "", observedState := "") {
    routeStatus := ""
    normalizedState := Trim(String(observedState ?? ""))
    if (normalizedState = "CUSTOMER_SUMMARY_OVERVIEW") {
        routeStatus := AdvisorQuoteGetCustomerSummaryOverviewStatus(db)
        AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ROUTE_STATUS", stateName, "context=" context . ", observedState=" normalizedState . ", " . AdvisorQuoteCustomerSummaryStatusDetail(routeStatus))
        if !AdvisorQuoteCustomerSummaryStatusForwardConfidence(routeStatus) {
            failScan := AdvisorQuoteScanCurrentPage(stateName, "customer-summary-unconfirmed")
            return AdvisorQuoteResultFail(stateName, stateName, AdvisorQuoteCustomerSummaryUnconfirmedReason(stateName), true, failScan, normalizedState, routeStatus)
        }
    } else {
        if !AdvisorQuoteShouldCheckCustomerSummaryOverviewFallback(normalizedState)
            return ""
        if !AdvisorQuoteTryCustomerSummaryOverviewFallback(db, context, &routeStatus) {
            if (AdvisorQuoteStatusValue(routeStatus, "urlMatched") = "1" && AdvisorQuoteStatusValue(routeStatus, "overviewMatched") = "1") {
                failScan := AdvisorQuoteScanCurrentPage(stateName, "customer-summary-unconfirmed")
                return AdvisorQuoteResultFail(stateName, stateName, AdvisorQuoteCustomerSummaryUnconfirmedReason(stateName), true, failScan, normalizedState, routeStatus)
            }
            return ""
        }
        normalizedState := "CUSTOMER_SUMMARY_OVERVIEW"
    }

    AdvisorQuoteAppendLog(
        (stateName = "ENTRY_CREATE_FORM") ? "ENTRY_CREATE_FORM_FORWARDED_TO_CUSTOMER_SUMMARY" : "CUSTOMER_SUMMARY_FORWARD_ROUTE",
        stateName,
        "context=" context
            . ", observedState=" observedState
            . ", customerSummaryStatus=" AdvisorQuoteStatusValue(routeStatus, "result")
            . ", customerSummaryConfidence=" AdvisorQuoteStatusValue(routeStatus, "confidence")
            . ", customerSummaryUrlMatched=" AdvisorQuoteStatusValue(routeStatus, "urlMatched")
            . ", customerSummaryStartHereMatched=" AdvisorQuoteStatusValue(routeStatus, "startHereMatched")
            . ", " . AdvisorQuoteCustomerSummaryStatusDetail(routeStatus)
    )

    clickStatus := AdvisorQuoteClickCustomerSummaryStartHere(db)
    AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_START_HERE_CLICK", stateName, "context=" context . ", startHereClickResult=" AdvisorQuoteStatusValue(clickStatus, "result") . ", startHereClickTarget=" AdvisorQuoteStatusValue(clickStatus, "targetText") . ", " . AdvisorQuoteCustomerSummaryStartHereClickDetail(clickStatus))
    if (AdvisorQuoteStatusValue(clickStatus, "result") != "OK" || AdvisorQuoteStatusValue(clickStatus, "clicked") != "1") {
        reason := AdvisorQuoteCustomerSummaryStartHereFailureReason(clickStatus, stateName)
        scanReason := (reason = "CUSTOMER_SUMMARY_START_HERE_NOT_FOUND") ? "customer-summary-start-here-not-found" : "customer-summary-start-here-click-failed"
        failScan := AdvisorQuoteScanCurrentPage(stateName, scanReason)
        return AdvisorQuoteResultFail(stateName, stateName, reason, true, failScan, normalizedState, clickStatus)
    }

    nextState := AdvisorQuoteWaitForObservedState(db, ["PRODUCT_OVERVIEW"], db["timeouts"]["transitionMs"])
    if (nextState = "")
        nextState := AdvisorQuoteDetectState(db)
    AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_TO_PRODUCT_OVERVIEW", stateName, "context=" context . ", postStartHereState=" nextState . ", productOverviewReached=" ((nextState = "PRODUCT_OVERVIEW") ? "1" : "0"))
    AdvisorQuoteAppendLog("CLICK_TRANSITION", stateName, "target=customer-summary-start-here, beforeState=" normalizedState . ", afterState=" nextState)
    if (nextState = "PRODUCT_OVERVIEW")
        return AdvisorQuoteResultOkValue(stateName, stateName, "Customer Summary / Prefill Gate advanced through START HERE.", entryScanPath, nextState)

    failScan := AdvisorQuoteScanCurrentPage(stateName, "customer-summary-to-product-overview-timeout")
    return AdvisorQuoteResultFail(stateName, stateName, "CUSTOMER_SUMMARY_TO_PRODUCT_OVERVIEW_TIMEOUT", true, failScan, nextState, clickStatus)
}

AdvisorQuoteLogProspectStatus(status, eventType := "PROSPECT_STATUS") {
    detail := "ready=" AdvisorQuoteStatusValue(status, "ready")
        . ", submitPresent=" AdvisorQuoteStatusValue(status, "submitPresent")
        . ", submitEnabled=" AdvisorQuoteStatusValue(status, "submitEnabled")
        . ", firstName=" AdvisorQuoteStatusValue(status, "firstName")
        . ", lastName=" AdvisorQuoteStatusValue(status, "lastName")
        . ", dob=" AdvisorQuoteStatusValue(status, "dob")
        . ", address=" AdvisorQuoteStatusValue(status, "address")
        . ", city=" AdvisorQuoteStatusValue(status, "city")
        . ", state=" AdvisorQuoteStatusValue(status, "state")
        . ", zip=" AdvisorQuoteStatusValue(status, "zip")
        . ", phone=" AdvisorQuoteStatusValue(status, "phone")
        . ", errors=" AdvisorQuoteStatusValue(status, "errors")
    AdvisorQuoteAppendLog(eventType, AdvisorQuoteGetLastStep(), detail)
}

AdvisorQuoteBuildAddressVerificationArgs(profile) {
    fields := (IsObject(profile) && profile.Has("fields")) ? profile["fields"] : Map()
    address := (IsObject(profile) && profile.Has("address")) ? profile["address"] : Map()
    street := address.Has("street") ? address["street"] : (fields.Has("ADDRESS_1") ? fields["ADDRESS_1"] : "")
    city := address.Has("city") ? address["city"] : (fields.Has("CITY") ? fields["CITY"] : "")
    state := address.Has("state") ? address["state"] : (fields.Has("STATE") ? fields["STATE"] : "")
    zip := address.Has("zip") ? address["zip"] : (fields.Has("ZIP") ? fields["ZIP"] : "")
    unit := fields.Has("APT_SUITE") ? fields["APT_SUITE"] : ""
    return Map(
        "street", street,
        "addressLine", street,
        "unit", unit,
        "aptSuite", unit,
        "city", city,
        "state", state,
        "zip", zip
    )
}

AdvisorQuoteGetAddressVerificationStatus() {
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("address_verification_status", Map(), 2, 120))
}

AdvisorQuoteAddressVerificationStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", radioCount=" AdvisorQuoteStatusValue(status, "radioCount")
        . ", continuePresent=" AdvisorQuoteStatusValue(status, "continuePresent")
        . ", continueEnabled=" AdvisorQuoteStatusValue(status, "continueEnabled")
        . ", selectedValue=" AdvisorQuoteStatusValue(status, "selectedValue")
        . ", enteredText=" AdvisorQuoteStatusValue(status, "enteredText")
        . ", suggestions=" AdvisorQuoteStatusValue(status, "suggestions")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

AdvisorQuoteAddressVerificationResultDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", method=" AdvisorQuoteStatusValue(status, "method")
        . ", selectedValue=" AdvisorQuoteStatusValue(status, "selectedValue")
        . ", selectedText=" AdvisorQuoteStatusValue(status, "selectedText")
        . ", selectedIndex=" AdvisorQuoteStatusValue(status, "selectedIndex")
        . ", radioSelected=" AdvisorQuoteStatusValue(status, "radioSelected")
        . ", continueButtonPresent=" AdvisorQuoteStatusValue(status, "continueButtonPresent")
        . ", continueButtonEnabledBefore=" AdvisorQuoteStatusValue(status, "continueButtonEnabledBefore")
        . ", continueButtonEnabledAfter=" AdvisorQuoteStatusValue(status, "continueButtonEnabledAfter")
        . ", continueClicked=" AdvisorQuoteStatusValue(status, "continueClicked")
        . ", matchScore=" AdvisorQuoteStatusValue(status, "matchScore")
        . ", matchedBy=" AdvisorQuoteStatusValue(status, "matchedBy")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
}

AdvisorQuoteAddressVerificationFailureReason(status) {
    result := AdvisorQuoteStatusValue(status, "result")
    if (result = "AMBIGUOUS")
        return "ADDRESS_VERIFICATION_AMBIGUOUS"
    return "ADDRESS_VERIFICATION_FAILED"
}

AdvisorQuoteResolveAddressVerification(profile, db, context := "", waitMs := 0) {
    start := A_TickCount
    pollMs := db["timeouts"]["pollMs"]
    Loop {
        if StopRequested()
            return Map("handled", true, "ok", false, "state", "BEGIN_QUOTING_FORM", "reason", "Stopped manually.", "status", Map())

        status := AdvisorQuoteGetAddressVerificationStatus()
        if (AdvisorQuoteStatusValue(status, "result") = "FOUND") {
            AdvisorQuoteAppendLog("ADDRESS_VERIFICATION_STATUS", AdvisorQuoteGetLastStep(), "context=" context . ", " . AdvisorQuoteAddressVerificationStatusDetail(status))
            raw := AdvisorQuoteRunOp("handle_address_verification", AdvisorQuoteBuildAddressVerificationArgs(profile), 2, 200)
            resultStatus := AdvisorQuoteParseKeyValueLines(raw)
            result := AdvisorQuoteStatusValue(resultStatus, "result")
            AdvisorQuoteAppendLog("ADDRESS_VERIFICATION_RESULT", AdvisorQuoteGetLastStep(), "context=" context . ", " . AdvisorQuoteAddressVerificationResultDetail(resultStatus))

            if (result = "SELECTED" && AdvisorQuoteStatusValue(resultStatus, "continueClicked") = "1") {
                nextState := AdvisorQuoteWaitForObservedState(db, AdvisorQuotePostProspectSubmitStates(), db["timeouts"]["transitionMs"])
                if (nextState = "")
                    nextState := AdvisorQuoteDetectState(db)
                if AdvisorQuoteIsStateInList(nextState, AdvisorQuotePostProspectSubmitStates())
                    return Map("handled", true, "ok", true, "state", nextState, "reason", "", "status", resultStatus)
                return Map("handled", true, "ok", false, "state", nextState, "reason", "ADDRESS_VERIFICATION_FAILED", "status", resultStatus)
            }

            return Map(
                "handled", true,
                "ok", false,
                "state", "BEGIN_QUOTING_FORM",
                "reason", AdvisorQuoteAddressVerificationFailureReason(resultStatus),
                "status", resultStatus
            )
        }

        if (waitMs <= 0 || (A_TickCount - start) >= waitMs)
            break
        if !SafeSleep(pollMs)
            return Map("handled", true, "ok", false, "state", "BEGIN_QUOTING_FORM", "reason", "Stopped manually.", "status", status)
    }

    return Map("handled", false, "ok", false, "state", "", "reason", "", "status", Map())
}

AdvisorQuoteClickCreateProspectPrimaryButton(db) {
    return AdvisorQuoteClickCreateProspectPrimaryButtonDetailed(db) != ""
}

AdvisorQuoteHandleDuplicateProspect(profile, db) {
    person := profile["person"]
    address := profile["address"]
    fields := profile["fields"]
    args := Map(
        "firstName", person["firstName"],
        "lastName", person["lastName"],
        "street", address["street"],
        "city", address.Has("city") ? address["city"] : fields["CITY"],
        "state", address.Has("state") ? address["state"] : fields["STATE"],
        "zip", address["zip"],
        "dob", person["dob"],
        "phone", person["phone"],
        "email", person["email"]
    )
    raw := AdvisorQuoteRunOp("handle_duplicate_prospect", args)
    status := AdvisorQuoteParseKeyValueLines(raw)
    result := (status.Has("result")) ? AdvisorQuoteStatusValue(status, "result") : Trim(String(raw))
    if (status.Count > 0) {
        AdvisorQuoteAppendLog(
            "DUPLICATE_RESOLUTION",
            AdvisorQuoteGetLastStep(),
            "result=" result
                . ", candidateCount=" AdvisorQuoteStatusValue(status, "candidateCount")
                . ", rowCount=" AdvisorQuoteStatusValue(status, "rowCount")
                . ", method=" AdvisorQuoteStatusValue(status, "method")
                . ", addressDecision=" AdvisorQuoteStatusValue(status, "addressDecision")
                . ", existingAddressMatch=" AdvisorQuoteStatusValue(status, "existingAddressMatch")
                . ", newProfileOptionFound=" AdvisorQuoteStatusValue(status, "newProfileOptionFound")
                . ", radioValue=" AdvisorQuoteStatusValue(status, "radioValue")
                . ", radioSelected=" AdvisorQuoteStatusValue(status, "radioSelected")
                . ", continueButtonPresent=" AdvisorQuoteStatusValue(status, "continueButtonPresent")
                . ", continueButtonEnabled=" AdvisorQuoteStatusValue(status, "continueButtonEnabled")
                . ", continueClicked=" AdvisorQuoteStatusValue(status, "continueClicked")
                . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
                . ", candidateSummaries=" AdvisorQuoteStatusValue(status, "candidateSummaries")
        )
    }
    if (result = "NO_ACTION" || result = "FAILED" || result = "AMBIGUOUS_DUPLICATE" || result = "ERROR" || result = "")
        return false

    waitArgs := Map(
        "rapportContains", db["urls"]["rapportContains"],
        "customerSummaryContains", db["urls"]["customerSummaryContains"],
        "selectProductContains", db["urls"]["selectProductContains"],
        "texts", db["texts"],
        "urls", db["urls"],
        "selectors", db["selectors"]
    )
    return AdvisorQuoteWaitForCondition("duplicate_to_next", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
}

AdvisorQuoteHandleGatherData(profile, db, &failureReason := "", &failureScanPath := "") {
    global advisorQuoteProductOverviewAutoPending, advisorQuoteProductOverviewAutoVerified, advisorQuoteGatherAutoCommitted
    failureReason := ""
    failureScanPath := ""

    AdvisorQuoteSetStep("GATHER_DATA", "Waiting for GATHER DATA page.")
    waitArgs := Map("rapportContains", db["urls"]["rapportContains"])
    if !AdvisorQuoteWaitForCondition("gather_data", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
        failureReason := "Gather Data page did not become ready."
        return false
    }

    if !AdvisorQuoteFillGatherDefaults(profile, db, &failureReason) {
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-defaults-failed")
        return false
    }

    vehiclePolicy := AdvisorQuoteClassifyGatherVehicles(profile)
    AdvisorQuoteLogGatherVehiclePolicy(vehiclePolicy)
    actionableVehicles := vehiclePolicy["actionableVehicles"]
    partialYearMakeVehicles := vehiclePolicy["partialYearMakeVehicles"]
    rapportLedger := AdvisorQuoteRapportVehicleLedgerCreate(profile, db)

    if !AdvisorQuoteResolveGatherSnapshotBlockers(actionableVehicles, db, &failureReason, &failureScanPath)
        return false

    if (rapportLedger["rateableCount"] = 0) {
        failureReason := "NO_RATEABLE_VEHICLES"
        AdvisorQuoteAppendLog(
            "RAPPORT_NO_RATEABLE_VEHICLES",
            AdvisorQuoteGetLastStep(),
            "ledger=" AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
                . ", vehicleCount=" rapportLedger["items"].Length
        )
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "no-actionable-lead-vehicle")
        return false
    }

    vehicleSatisfiedCount := 0
    satisfiedVehicles := []
    promotedPartialVehicles := []
    dbAddedVehicles := []
    deferredRapportVehicles := []
    deferredCompleteVehicles := []
    deferredUnknownVehicles := []
    deferredPartialVehicles := []
    staleDuplicateRowSeen := false
    staleDuplicateRowDetails := ""
    rapportVehicleMode := AdvisorQuoteRapportVehicleMode(db)
    vehicleModeAllowsAddComplete := AdvisorQuoteRapportVehicleModeAllowsAddComplete(rapportVehicleMode)
    AdvisorQuoteAppendLog(
        "RAPPORT_VEHICLE_MODE",
        AdvisorQuoteGetLastStep(),
        "rapportVehicleMode=" rapportVehicleMode
            . ", vehicleModeAllowsAddComplete=" (vehicleModeAllowsAddComplete ? "1" : "0")
    )
    for _, vehicle in actionableVehicles {
        if StopRequested() {
            failureReason := "Stopped manually."
            return false
        }

        AdvisorQuoteSetStep("GATHER_DATA_VEHICLE_CHECK", "Checking vehicle: " vehicle["displayKey"])
        AdvisorQuoteAppendLog(
            "VEHICLE_NORMALIZED",
            AdvisorQuoteGetLastStep(),
            "displayKey=" vehicle["displayKey"]
                . ", year=" vehicle["year"]
                . ", make=" vehicle["make"]
                . ", model=" vehicle["model"]
                . ", trimHint=" vehicle["trimHint"]
        )

        resolvedVehicle := AdvisorVehicleDbResolveLeadVehicle(vehicle["year"], vehicle["make"], vehicle["model"], vehicle.Has("vin") ? vehicle["vin"] : "")
        AdvisorQuoteAppendLog("VEHICLE_DB_RESOLVER", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle))
        resolveResult := AdvisorQuoteVehicleDbResolveResult(resolvedVehicle)
        if (resolveResult = "AMBIGUOUS") {
            AdvisorQuoteAppendLog(
                "VEHICLE_DB_CARD_MATCH_AMBIGUOUS",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", " AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle)
            )
        } else if (resolveResult != "RESOLVED") {
            AdvisorQuoteAppendLog(
                "VEHICLE_DB_CARD_MATCH_NOT_RESOLVED",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", " AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle)
            )
        }

        preflightStatus := AdvisorQuoteGetGatherVehicleAddStatus(vehicle)
        alreadyConfirmed := AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(preflightStatus)
        AdvisorQuoteLogGatherVehicleAddStatus(preflightStatus, "VEHICLE_PREFLIGHT_STATUS", vehicle)
        AdvisorQuoteAppendLog(
            "VEHICLE_PREFLIGHT_DECISION",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"]
                . ", vehiclePreflightStatus=" AdvisorQuoteStatusValue(preflightStatus, "result")
                . ", alreadyConfirmed=" (alreadyConfirmed ? "1" : "0")
                . ", confirmedVehicleMatched=" AdvisorQuoteStatusValue(preflightStatus, "confirmedVehicleMatched")
                . ", confirmedStatusMatched=" AdvisorQuoteStatusValue(preflightStatus, "confirmedStatusMatched")
                . ", matchedText=" AdvisorQuoteStatusValue(preflightStatus, "matchedText")
                . ", skippedBecauseAlreadyConfirmed=" (alreadyConfirmed ? "1" : "0")
        )
        if alreadyConfirmed {
            if AdvisorQuoteGatherVehicleDuplicateAddRowOpen(preflightStatus) {
                staleDuplicateRowSeen := true
                staleDuplicateRowDetails := AdvisorQuoteStatusValue(preflightStatus, "duplicateAddRowDetails")
                AdvisorQuoteAppendLog(
                    "DUPLICATE_ADD_ROW_OPEN_FOR_CONFIRMED_VEHICLE_DEFERRED",
                    AdvisorQuoteGetLastStep(),
                    "vehicle=" vehicle["displayKey"]
                        . ", matchedText=" AdvisorQuoteStatusValue(preflightStatus, "matchedText")
                        . ", duplicateAddRowDetails=" AdvisorQuoteStatusValue(preflightStatus, "duplicateAddRowDetails")
                        . ", cleanupDeferredUntilFinalConfirmedReconciliation=1"
                )
            }
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "CONFIRMED_EXACT", "matched-confirmed-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_ALREADY_CONFIRMED",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"]
                    . ", vehicleSatisfiedCount=" vehicleSatisfiedCount
                    . ", actionableVehicleCount=" actionableVehicles.Length
                    . ", matchedText=" AdvisorQuoteStatusValue(preflightStatus, "matchedText")
            )
            continue
        }

        editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &failureReason, &failureScanPath, "preflight")
        if (editOutcome = "CONFIRMED") {
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "CONFIRMED_EXACT", "edit-panel-update")
            continue
        }
        if (editOutcome = "FAILED")
            return false

        legacyListed := AdvisorQuoteVehicleAlreadyListed(vehicle)
        if legacyListed {
            AdvisorQuoteAppendLog(
                "VEHICLE_LEGACY_LISTED_NOT_CONFIRMED",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", alreadyConfirmed=0, actionWillContinue=1"
            )
        }

        if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, vehicle, "confirm_potential_vehicle", &failureReason) {
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
            return false
        }
        confirmOutcome := AdvisorQuoteConfirmPotentialVehicle(vehicle, db, &failureReason, &failureScanPath)
        if (confirmOutcome = "CONFIRMED") {
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "CONFIRMED_POTENTIAL_MATCH", "potential-card")
            continue
        }
        if (confirmOutcome = "FAILED")
            return false
        if (confirmOutcome = "AMBIGUOUS") {
            deferredRapportVehicles.Push(vehicle)
            deferredCompleteVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "DEFERRED_AMBIGUOUS", "potential-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", source=potential-card"
            )
            continue
        }

        if (resolveResult = "AMBIGUOUS") {
            deferredRapportVehicles.Push(vehicle)
            deferredCompleteVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "DEFERRED_AMBIGUOUS", "db-resolver")
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", source=db-resolver"
            )
            continue
        }

        if (vehicleModeAllowsAddComplete && resolveResult = "RESOLVED") {
            if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, vehicle, "add_db_resolved_vehicle", &failureReason) {
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
                return false
            }
            addOutcome := AdvisorQuoteAddCompleteDbResolvedVehicle(vehicle, resolvedVehicle, db, &failureReason, &failureScanPath)
            if (addOutcome = "ADDED") {
                vehicleSatisfiedCount += 1
                satisfiedVehicles.Push(vehicle)
                dbAddedVehicles.Push(vehicle)
                AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "ADDED_DB_RESOLVED", "db-resolved-model")
                continue
            }
            if (addOutcome = "FAILED")
                return false
            deferredRapportVehicles.Push(vehicle)
            deferredCompleteVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "SCRAP_MODEL_UNAVAILABLE", "db-add-deferred")
            continue
        }

        if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, vehicle, "add_exact_model_vehicle", &failureReason) {
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
            return false
        }
        if AdvisorQuoteAddVehicleInGatherData(vehicle, db) {
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "ADDED_SUBMODEL_PLACEHOLDER", "EXACT_MODEL")
            continue
        }

        deferredRapportVehicles.Push(vehicle)
        deferredCompleteVehicles.Push(vehicle)
        AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "SCRAP_MODEL_UNAVAILABLE", "exact-model-add-failed")
        AdvisorQuoteAppendLog(
            "VEHICLE_DEFERRED_NO_DB_CARD_MATCH",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"] ", source=exact-model-add, rapportVehicleMode=" rapportVehicleMode
        )
    }

    for _, partialVehicle in partialYearMakeVehicles {
        if StopRequested() {
            failureReason := "Stopped manually."
            return false
        }

        AdvisorQuoteSetStep("GATHER_DATA_PARTIAL_VEHICLE_CHECK", "Checking partial vehicle: " partialVehicle["displayKey"])
        partialStatus := AdvisorQuoteGetGatherPartialVehicleConfirmedStatus(partialVehicle)
        AdvisorQuoteLogGatherVehicleAddStatus(partialStatus, "VEHICLE_PARTIAL_PREFLIGHT_STATUS", partialVehicle)

        if AdvisorQuoteGatherVehiclePartialStatusPromoted(partialStatus) {
            promotedVehicle := AdvisorQuoteBuildGatherPromotedPartialVehicle(partialVehicle, partialStatus)
            if AdvisorQuoteGatherVehicleDuplicateAddRowOpen(partialStatus) {
                staleDuplicateRowSeen := true
                staleDuplicateRowDetails := AdvisorQuoteStatusValue(partialStatus, "duplicateAddRowDetails")
                AdvisorQuoteAppendLog(
                    "DUPLICATE_ADD_ROW_OPEN_FOR_PROMOTED_CONFIRMED_VEHICLE_DEFERRED",
                    AdvisorQuoteGetLastStep(),
                    "vehicle=" partialVehicle["displayKey"]
                        . ", promotedVehicle=" AdvisorQuoteVehicleLabel(promotedVehicle)
                        . ", promotedVehicleText=" AdvisorQuoteStatusValue(partialStatus, "promotedVehicleText")
                        . ", duplicateAddRowDetails=" AdvisorQuoteStatusValue(partialStatus, "duplicateAddRowDetails")
                        . ", cleanupDeferredUntilFinalConfirmedReconciliation=1"
                )
            }
            vehicleSatisfiedCount += 1
            promotedPartialVehicles.Push(promotedVehicle)
            satisfiedVehicles.Push(promotedVehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "CONFIRMED_EXACT", "partial-promoted-confirmed-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_PARTIAL_ALREADY_CONFIRMED",
                AdvisorQuoteGetLastStep(),
                "partialVehicle=" partialVehicle["displayKey"]
                    . ", promotedVehicle=" AdvisorQuoteVehicleLabel(promotedVehicle)
                    . ", promotedModel=" AdvisorQuoteStatusValue(partialStatus, "promotedModel")
                    . ", promotedVinEvidence=" AdvisorQuoteStatusValue(partialStatus, "promotedVinEvidence")
                    . ", promotionSource=" AdvisorQuoteStatusValue(partialStatus, "promotionSource")
                    . ", matchedText=" AdvisorQuoteStatusValue(partialStatus, "matchedText")
            )
            continue
        }

        result := AdvisorQuoteStatusValue(partialStatus, "result")
        if (result = "AMBIGUOUS") {
            deferredPartialVehicles.Push(partialVehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "DEFERRED_AMBIGUOUS", "partial-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH",
                AdvisorQuoteGetLastStep(),
                "partialVehicle=" partialVehicle["displayKey"]
                    . ", result=" result
                    . ", candidateCount=" AdvisorQuoteStatusValue(partialStatus, "candidateCount")
                    . ", candidateTexts=" AdvisorQuoteStatusValue(partialStatus, "candidateTexts")
            )
            continue
        }

        if AdvisorQuoteRapportModelPlaceholderFallbackEnabled(db) {
            if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, partialVehicle, "add_model_placeholder_vehicle", &failureReason) {
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
                return false
            }
            addedPlaceholderVehicle := ""
            placeholderOutcome := AdvisorQuoteAddPartialYearMakeVehicleWithModelFallback(partialVehicle, db, &addedPlaceholderVehicle, &failureReason, &failureScanPath)
            switch placeholderOutcome {
                case "ADDED":
                    vehicleSatisfiedCount += 1
                    satisfiedVehicles.Push(addedPlaceholderVehicle)
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "ADDED_MODEL_PLACEHOLDER", "MODEL_PLACEHOLDER_FALLBACK")
                    continue
                case "SCRAP_MAKE_UNAVAILABLE":
                    deferredPartialVehicles.Push(partialVehicle)
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "SCRAP_MAKE_UNAVAILABLE", "make-option-not-found")
                    continue
                case "SCRAP_MODEL_UNAVAILABLE":
                    deferredPartialVehicles.Push(partialVehicle)
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "SCRAP_MODEL_UNAVAILABLE", "model-option-not-found")
                    continue
                case "FAILED_UNSAFE":
                    deferredPartialVehicles.Push(partialVehicle)
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "FAILED_UNSAFE", "model-placeholder-add-failed")
                    continue
            }
        }

        deferredPartialVehicles.Push(partialVehicle)
        AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "SCRAP_MODEL_UNAVAILABLE", "model-placeholder-disabled")
        AdvisorQuoteAppendLog(
            "VEHICLE_PARTIAL_DEFERRED",
            AdvisorQuoteGetLastStep(),
            "partialVehicle=" partialVehicle["displayKey"]
                . ", result=" result
                . ", failedFields=" AdvisorQuoteStatusValue(partialStatus, "failedFields")
                . ", candidateCount=" AdvisorQuoteStatusValue(partialStatus, "candidateCount")
                . ", candidateTexts=" AdvisorQuoteStatusValue(partialStatus, "candidateTexts")
        )
    }

    if (vehicleSatisfiedCount = 0) {
        failureReason := "NO_RATEABLE_VEHICLES"
        AdvisorQuoteAppendLog(
            "RAPPORT_NO_RATEABLE_VEHICLES",
            AdvisorQuoteGetLastStep(),
            "ledger=" AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
                . ", deferredCompleteVehicles=" AdvisorQuoteVehicleListSummary(deferredCompleteVehicles)
                . ", deferredUnknownVehicles=" AdvisorQuoteVehicleListSummary(deferredUnknownVehicles)
                . ", deferredPartialVehicles=" AdvisorQuoteVehicleListSummary(deferredPartialVehicles)
        )
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "no-safe-rapport-vehicle-match")
        return false
    }

    if !AdvisorQuoteRapportVehicleLedgerAllRateableTerminal(rapportLedger) {
        failureReason := "RAPPORT_VEHICLE_LEDGER_INCOMPLETE: " AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-incomplete")
        return false
    }

    expectedVehiclesForGuardList := AdvisorQuoteBuildGatherFinalExpectedVehicles(satisfiedVehicles, [])
    expectedVehicleArgsForFinalGuard := AdvisorQuoteBuildExpectedVehiclesArgList(expectedVehiclesForGuardList)
    expectedVehicleCountForFinalGuard := expectedVehicleArgsForFinalGuard.Length
    promotedPartialExpectedCount := AdvisorQuoteCountExpectedArgsMatchingVehicles(expectedVehicleArgsForFinalGuard, promotedPartialVehicles)
    expectedVehiclesForFinalGuard := AdvisorQuoteVehicleListSummary(expectedVehiclesForGuardList)
    missingPromotedPartialExpectedVehicles := AdvisorQuoteExpectedArgsMissingVehiclesSummary(expectedVehicleArgsForFinalGuard, promotedPartialVehicles)
    if (promotedPartialVehicles.Length > 0 && missingPromotedPartialExpectedVehicles != "") {
        failureReason := "PROMOTED_PARTIAL_DROPPED_FROM_EXPECTED_LIST: " missingPromotedPartialExpectedVehicles
        AdvisorQuoteAppendLog(
            "PROMOTED_PARTIAL_DROPPED_FROM_EXPECTED_LIST",
            AdvisorQuoteGetLastStep(),
            "completeExpectedCount=" actionableVehicles.Length
            . ", promotedPartialExpectedCount=" promotedPartialExpectedCount
            . ", promotedPartialVehicleCount=" promotedPartialVehicles.Length
            . ", dbAddedVehicleCount=" dbAddedVehicles.Length
            . ", dbAddedVehicles=" AdvisorQuoteVehicleListSummary(dbAddedVehicles)
            . ", finalExpectedCount=" expectedVehicleCountForFinalGuard
            . ", finalExpectedVehicles=" expectedVehiclesForFinalGuard
            . ", missingPromotedPartialExpectedVehicles=" missingPromotedPartialExpectedVehicles
        )
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "promoted-partial-dropped-from-expected-list")
        return false
    }
    AdvisorQuoteAppendLog(
        "GATHER_CONFIRMED_VEHICLES_ARGS",
        AdvisorQuoteGetLastStep(),
        "actionableVehicleCount=" actionableVehicles.Length
            . ", actionableVehicles=" AdvisorQuoteVehicleListSummary(actionableVehicles)
            . ", completeExpectedCount=" expectedVehiclesForGuardList.Length
            . ", promotedPartialVehicleCount=" promotedPartialVehicles.Length
            . ", promotedPartialExpectedCount=" promotedPartialExpectedCount
            . ", promotedPartialVehicles=" AdvisorQuoteVehicleListSummary(promotedPartialVehicles)
            . ", dbAddedVehicleCount=" dbAddedVehicles.Length
            . ", dbAddedVehicles=" AdvisorQuoteVehicleListSummary(dbAddedVehicles)
            . ", deferredRapportVehicleCount=" deferredRapportVehicles.Length
            . ", deferredRapportVehicles=" AdvisorQuoteVehicleListSummary(deferredRapportVehicles)
            . ", deferredCompleteVehicleCount=" deferredCompleteVehicles.Length
            . ", deferredCompleteVehicles=" AdvisorQuoteVehicleListSummary(deferredCompleteVehicles)
            . ", deferredUnknownVehicleCount=" deferredUnknownVehicles.Length
            . ", deferredUnknownVehicles=" AdvisorQuoteVehicleListSummary(deferredUnknownVehicles)
            . ", deferredPartialVehicleCount=" deferredPartialVehicles.Length
            . ", deferredPartialVehicles=" AdvisorQuoteVehicleListSummary(deferredPartialVehicles)
            . ", expectedVehicleCountForFinalGuard=" expectedVehicleCountForFinalGuard
            . ", expectedVehiclesForFinalGuard=" expectedVehiclesForFinalGuard
            . ", finalExpectedCount=" expectedVehicleCountForFinalGuard
            . ", finalExpectedVehicles=" expectedVehiclesForFinalGuard
            . ", ignoredMissingYearVehicleCount=" vehiclePolicy["ignoredMissingYearVehicles"].Length
            . ", ignoredMissingYearVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["ignoredMissingYearVehicles"])
            . ", deferredVinVehicleCount=" vehiclePolicy["deferredVinVehicles"].Length
            . ", deferredVinVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["deferredVinVehicles"])
            . ", vehicleSatisfiedCount=" vehicleSatisfiedCount
            . ", satisfiedVehicles=" AdvisorQuoteVehicleListSummary(satisfiedVehicles)
            . ", confirmedGuardArgsSummary=" expectedVehiclesForFinalGuard
    )
    confirmedStatus := AdvisorQuoteGetGatherConfirmedVehiclesStatusForVehicles(expectedVehiclesForGuardList)
    AdvisorQuoteAppendLog("GATHER_CONFIRMED_VEHICLES_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherConfirmedVehiclesStatusDetail(confirmedStatus))
    AdvisorQuoteAppendLog(
        "GATHER_VEHICLE_RECONCILIATION",
        AdvisorQuoteGetLastStep(),
        "vehicleSatisfiedCount=" vehicleSatisfiedCount
            . ", actionableVehicleCount=" actionableVehicles.Length
            . ", completeExpectedCount=" expectedVehiclesForGuardList.Length
            . ", promotedPartialVehicleCount=" promotedPartialVehicles.Length
            . ", promotedPartialExpectedCount=" promotedPartialExpectedCount
            . ", promotedPartialVehicles=" AdvisorQuoteVehicleListSummary(promotedPartialVehicles)
            . ", dbAddedVehicleCount=" dbAddedVehicles.Length
            . ", dbAddedVehicles=" AdvisorQuoteVehicleListSummary(dbAddedVehicles)
            . ", deferredRapportVehicleCount=" deferredRapportVehicles.Length
            . ", deferredRapportVehicles=" AdvisorQuoteVehicleListSummary(deferredRapportVehicles)
            . ", deferredCompleteVehicleCount=" deferredCompleteVehicles.Length
            . ", deferredCompleteVehicles=" AdvisorQuoteVehicleListSummary(deferredCompleteVehicles)
            . ", deferredUnknownVehicleCount=" deferredUnknownVehicles.Length
            . ", deferredUnknownVehicles=" AdvisorQuoteVehicleListSummary(deferredUnknownVehicles)
            . ", deferredPartialVehicleCount=" deferredPartialVehicles.Length
            . ", deferredPartialVehicles=" AdvisorQuoteVehicleListSummary(deferredPartialVehicles)
            . ", expectedVehicleCountForFinalGuard=" expectedVehicleCountForFinalGuard
            . ", expectedVehiclesForFinalGuard=" expectedVehiclesForFinalGuard
            . ", finalExpectedCount=" expectedVehicleCountForFinalGuard
            . ", finalExpectedVehicles=" expectedVehiclesForFinalGuard
            . ", satisfiedVehicles=" AdvisorQuoteVehicleListSummary(satisfiedVehicles)
            . ", ignoredMissingYearVehicleCount=" vehiclePolicy["ignoredMissingYearVehicles"].Length
            . ", ignoredMissingYearVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["ignoredMissingYearVehicles"])
            . ", deferredVinVehicleCount=" vehiclePolicy["deferredVinVehicles"].Length
            . ", deferredVinVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["deferredVinVehicles"])
            . ", missingExpectedVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "missingExpectedVehicles")
            . ", unexpectedVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "unexpectedVehicles")
            . ", matchedVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "matchedVehicles")
            . ", unresolvedLeadVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "unresolvedLeadVehicles")
    )
    if !AdvisorQuoteGatherConfirmedVehiclesSafe(confirmedStatus, profile, &failureReason) {
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "confirmed-vehicles-unsafe")
        return false
    }

    if !AdvisorQuoteCleanupStaleGatherVehicleRowIfSafe(expectedVehiclesForGuardList, staleDuplicateRowSeen, staleDuplicateRowDetails, &failureReason, &failureScanPath)
        return false

    finalRapportSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
    if (AdvisorQuoteStatusValue(finalRapportSnapshot, "staleAddRowPresent") = "1") {
        failureReason := "RAPPORT_UNSAFE_ADD_ROW_REMAINS_BEFORE_START_QUOTING: " AdvisorQuoteBuildGatherRapportSnapshotDetail(finalRapportSnapshot)
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-unsafe-add-row-before-start-quoting")
        return false
    }
    if (AdvisorQuoteStatusValue(finalRapportSnapshot, "vehicleWarningPresent") = "1"
        && AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled") != "1") {
        failureReason := "RAPPORT_VEHICLE_WARNING_BLOCKS_START_QUOTING: " AdvisorQuoteBuildGatherRapportSnapshotDetail(finalRapportSnapshot)
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-warning-before-start-quoting")
        return false
    }
    if !AdvisorQuoteRapportVehicleLedgerStartQuotingAllowed(
        rapportLedger,
        vehicleSatisfiedCount,
        AdvisorQuoteStatusValue(finalRapportSnapshot, "staleAddRowPresent"),
        AdvisorQuoteStatusValue(finalRapportSnapshot, "vehicleWarningPresent"),
        AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled")
    ) {
        failureReason := "RAPPORT_VEHICLE_LEDGER_START_QUOTING_BLOCKED: " AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-start-quoting-blocked")
        return false
    }

    AdvisorQuoteAppendLog(
        "RAPPORT_VEHICLE_LEDGER_DONE",
        AdvisorQuoteGetLastStep(),
        "ledger=" AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
            . ", satisfiedCount=" AdvisorQuoteRapportVehicleLedgerSatisfiedCount(rapportLedger)
            . ", confirmedOrAddedVehicleCount=" vehicleSatisfiedCount
            . ", staleAddRowPresent=" AdvisorQuoteStatusValue(finalRapportSnapshot, "staleAddRowPresent")
            . ", vehicleWarningPresent=" AdvisorQuoteStatusValue(finalRapportSnapshot, "vehicleWarningPresent")
            . ", createQuotesEnabled=" AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled")
            . ", startQuotingAllowed=1"
    )

    startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
    AdvisorQuoteAppendLog("GATHER_START_QUOTING_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))

    startQuotingReason := ""
    startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
    startQuotingCheckboxEnsureAttempted := false
    if !startQuotingReady {
        if (advisorQuoteProductOverviewAutoPending && !AdvisorQuoteGatherStartQuotingAutoSelected(startQuotingStatus)) {
            advisorQuoteGatherAutoCommitted := false
            AdvisorQuoteAppendLog(
                "PRODUCT_OVERVIEW_AUTO_NOT_COMMITTED",
                AdvisorQuoteGetLastStep(),
                "GatherAutoCommitted=0, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus)
            )
        }

        if (AdvisorQuoteStatusValue(startQuotingStatus, "hasStartQuotingText") = "1") {
            startQuotingCheckboxEnsureAttempted := true
            checkboxStatus := AdvisorQuoteEnsureStartQuotingAutoCheckbox()
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_AUTO_CHECKBOX", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildStartQuotingAutoCheckboxDetail(checkboxStatus))

            applyStatus := AdvisorQuoteEnsureAutoStartQuotingState(db)
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_AUTO_SET", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingApplyDetail(applyStatus))

            startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))
            startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
        }
    }

    if (!startQuotingReady && AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(startQuotingStatus, db, advisorQuoteProductOverviewAutoVerified, &startQuotingReason)) {
        handoffPath := startQuotingCheckboxEnsureAttempted ? "checkbox-then-add-product" : "scoped-add-product"
        handoffStatus := Map()
        handoffReason := ""
        if !AdvisorQuoteRunScopedStartQuotingAddProductHandoff(db, startQuotingStatus, handoffPath, &handoffStatus, &handoffReason, &failureReason, &failureScanPath)
            return false
        startQuotingStatus := handoffStatus
        startQuotingReason := handoffReason
        startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
    }

    if (!startQuotingReady && advisorQuoteProductOverviewAutoVerified && AdvisorQuoteGatherNeedsProductTileRecovery(startQuotingStatus)) {
        recoveryScanPath := ""
        if AdvisorQuoteRecoverProductTileAutoFromRapport(db, startQuotingStatus, startQuotingReason, &failureReason, &recoveryScanPath) {
            startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
            AdvisorQuoteAppendLog(
                "GATHER_START_QUOTING_STATUS",
                AdvisorQuoteGetLastStep(),
                "phase=after-product-tile-recovery, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus)
            )
            startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
        } else {
            failureScanPath := recoveryScanPath
            return false
        }
    }

    if startQuotingReady {
        advisorQuoteProductOverviewAutoPending := false
        advisorQuoteGatherAutoCommitted := true
        AdvisorQuoteAppendLog("GATHER_START_QUOTING_READY", AdvisorQuoteGetLastStep(), "GatherAutoCommitted=1, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))
        AdvisorQuoteAppendLog(
            "GATHER_START_QUOTING_HANDOFF",
            AdvisorQuoteGetLastStep(),
            "startQuotingHandoffPath=create-quotes-enabled"
                . ", startQuotingCreateQuotesEnabledBefore=" (AdvisorQuoteStartQuotingCreateQuotesEnabled(startQuotingStatus) ? "1" : "0")
                . ", startQuotingScopedAddProductPresent=" (AdvisorQuoteStartQuotingScopedAddProductPresent(startQuotingStatus) ? "1" : "0")
                . ", startQuotingScopedAddProductClicked=0"
        )

        clickResult := AdvisorQuoteClickCreateQuotesOrderReports(db)
        AdvisorQuoteAppendLog("GATHER_START_QUOTING_CREATE_QUOTES_CLICK", AdvisorQuoteGetLastStep(), "result=" clickResult)
        if (clickResult != "OK") {
            if (clickResult = "DISABLED" && advisorQuoteProductOverviewAutoVerified) {
                retryStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
                AdvisorQuoteAppendLog(
                    "GATHER_START_QUOTING_STATUS",
                    AdvisorQuoteGetLastStep(),
                    "phase=create-quotes-disabled-retry, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(retryStatus)
                )
                retryReason := ""
                if AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(retryStatus, db, advisorQuoteProductOverviewAutoVerified, &retryReason) {
                    if !AdvisorQuoteRunScopedStartQuotingAddProductHandoff(db, retryStatus, "scoped-add-product", &startQuotingStatus, &startQuotingReason, &failureReason, &failureScanPath)
                        return false
                    clickResult := AdvisorQuoteClickCreateQuotesOrderReports(db)
                    AdvisorQuoteAppendLog("GATHER_START_QUOTING_CREATE_QUOTES_CLICK", AdvisorQuoteGetLastStep(), "phase=after-scoped-add-product, result=" clickResult)
                    if (clickResult = "OK") {
                        waitArgs := Map("ascProductContains", db["urls"]["ascProductContains"])
                        if !AdvisorQuoteWaitForCondition("gather_start_quoting_transition", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
                            failureReason := "Create Quotes & Order Reports did not transition to Consumer Reports or a later quote state."
                            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "create-quotes-transition-timeout")
                            return false
                        }
                        return true
                    }
                }
            }
            if (clickResult = "NO_BUTTON")
                failureReason := "Create Quotes & Order Reports button was not found on Gather Data."
            else if (clickResult = "DISABLED")
                failureReason := "Create Quotes & Order Reports is still disabled on Gather Data."
            else
                failureReason := "Create Quotes & Order Reports could not be clicked on Gather Data."
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "create-quotes-click-failed")
            return false
        }

        waitArgs := Map("ascProductContains", db["urls"]["ascProductContains"])
        if !AdvisorQuoteWaitForCondition("gather_start_quoting_transition", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
            failureReason := "Create Quotes & Order Reports did not transition to Consumer Reports or a later quote state."
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "create-quotes-transition-timeout")
            return false
        }
        return true
    }

    notReadyScan := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-start-quoting-not-ready")
    AdvisorQuoteAppendLog(
        "GATHER_START_QUOTING_NOT_READY",
        AdvisorQuoteGetLastStep(),
        "reason=" startQuotingReason . ", status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
    )

    if AdvisorQuoteIsOnSelectProductPage(db) {
        AdvisorQuoteAppendLog("SELECT_PRODUCT_FALLBACK_USED", AdvisorQuoteGetLastStep(), "reason=already-on-select-product")
        return true
    }

    if !advisorQuoteProductOverviewAutoVerified {
        failureReason := "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED: Gather Data reached without verified Product Tile Grid Auto selection; refusing Add Product fallback."
        failureScanPath := notReadyScan
        AdvisorQuoteAppendLog(
            "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED",
            AdvisorQuoteGetLastStep(),
            "reason=" startQuotingReason . ", status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
        )
        return false
    }

    if !AdvisorQuoteGatherStartQuotingAutoSelected(startQuotingStatus) {
        failureReason := "START_QUOTING_AUTO_MISSING_AFTER_PRODUCT_OVERVIEW: Auto was verified on Product Tile Grid but is not selected in Gather Data Start Quoting; refusing Add Product fallback."
        failureScanPath := notReadyScan
        AdvisorQuoteAppendLog(
            "START_QUOTING_AUTO_MISSING_AFTER_PRODUCT_OVERVIEW",
            AdvisorQuoteGetLastStep(),
            "reason=" startQuotingReason . ", status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
        )
        advisorQuoteProductOverviewAutoPending := false
        return false
    }

    failureReason := AdvisorQuoteStartQuotingFailureCode(startQuotingStatus, startQuotingReason)
    failureScanPath := notReadyScan
    AdvisorQuoteAppendLog(
        "GATHER_START_QUOTING_INVALID_AFTER_PRODUCT_OVERVIEW",
        AdvisorQuoteGetLastStep(),
        "reason=" startQuotingReason . ", failureReason=" failureReason . ", addProductFallbackRefusedReason=product-tile-auto-gate, status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
    )
    return false
}

AdvisorQuoteFillGatherDefaults(profile, db, &failureReason := "") {
    failureReason := ""
    person := (IsObject(profile) && profile.Has("person")) ? profile["person"] : Map()
    emailValue := person.Has("email") ? Trim(String(person["email"])) : ""
    ageValue := String(db["defaults"]["ageFirstLicensed"])
    ownershipValue := String(db["defaults"]["gatherResidenceOwnedRentedRentValue"])
    homeTypeValue := AdvisorQuoteInferGatherHomeType(profile, db)

    args := Map(
        "emailValue", emailValue,
        "ageValue", ageValue,
        "ownershipValue", ownershipValue,
        "homeTypeValue", homeTypeValue
    )
    applyStatus := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("fill_gather_defaults", args))
    applyResult := AdvisorQuoteStatusValue(applyStatus, "result")
    if (applyResult = "FAILED" || applyResult = "ERROR" || applyResult = "") {
        failureReason := "Could not apply Gather Data defaults via the Advisor page."
        return false
    }

    AdvisorQuoteAppendLog(
        "GATHER_DEFAULTS_APPLIED",
        AdvisorQuoteGetLastStep(),
        "ageValue=" ageValue
            . ", emailPresent=" ((emailValue != "") ? "1" : "0")
            . ", ownershipValue=" ownershipValue
            . ", homeTypeValue=" homeTypeValue
            . ", result=" applyResult
            . ", ageApplied=" AdvisorQuoteStatusValue(applyStatus, "ageApplied")
            . ", emailApplied=" AdvisorQuoteStatusValue(applyStatus, "emailApplied")
            . ", ownershipApplied=" AdvisorQuoteStatusValue(applyStatus, "ownershipApplied")
            . ", homeTypeApplied=" AdvisorQuoteStatusValue(applyStatus, "homeTypeApplied")
    )

    status := AdvisorQuoteGetGatherDefaultsStatus()
    AdvisorQuoteAppendLog("GATHER_DEFAULTS_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherDefaultsStatusDetail(status))
    return AdvisorQuoteGatherDefaultsValid(status, ageValue, emailValue, ownershipValue, homeTypeValue, &failureReason)
}

AdvisorQuoteGetGatherDefaultsStatus() {
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_defaults_status", Map(), 2, 120))
}

AdvisorQuoteBuildGatherDefaultsStatusDetail(status) {
    return "ageFirstLicensed=" AdvisorQuoteStatusValue(status, "ageFirstLicensed")
        . ", email=" AdvisorQuoteStatusValue(status, "email")
        . ", ownershipTypeValue=" AdvisorQuoteStatusValue(status, "ownershipTypeValue")
        . ", ownershipTypeText=" AdvisorQuoteStatusValue(status, "ownershipTypeText")
        . ", homeTypeValue=" AdvisorQuoteStatusValue(status, "homeTypeValue")
        . ", homeTypeText=" AdvisorQuoteStatusValue(status, "homeTypeText")
        . ", licenseStateValue=" AdvisorQuoteStatusValue(status, "licenseStateValue")
        . ", licenseStateText=" AdvisorQuoteStatusValue(status, "licenseStateText")
        . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
}

AdvisorQuoteGatherDefaultsValid(status, ageValue, emailValue, ownershipValue, homeTypeValue, &failureReason := "") {
    failureReason := ""
    if !IsObject(status) || (status.Count = 0) {
        failureReason := "Gather Data defaults status could not be read back from the page."
        return false
    }

    actualAge := Trim(AdvisorQuoteStatusValue(status, "ageFirstLicensed"))
    if (ageValue != "" && actualAge != ageValue) {
        failureReason := "Age First Licensed default did not stick. Expected " ageValue ", found " actualAge "."
        return false
    }

    actualEmail := Trim(AdvisorQuoteStatusValue(status, "email"))
    if (Trim(String(emailValue)) != "" && StrLower(actualEmail) != StrLower(Trim(String(emailValue)))) {
        failureReason := "Gather Data email default did not stick."
        return false
    }

    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "ownershipTypeValue"),
        AdvisorQuoteStatusValue(status, "ownershipTypeText"),
        ownershipValue,
        "Rent"
    ) {
        failureReason := "Gather Data ownership type default did not stick."
        return false
    }

    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "homeTypeValue"),
        AdvisorQuoteStatusValue(status, "homeTypeText"),
        homeTypeValue,
        AdvisorQuoteGatherHomeTypeLabel(homeTypeValue)
    ) {
        failureReason := "Gather Data home type default did not stick."
        return false
    }

    return true
}

AdvisorQuoteGetGatherStartQuotingStatus(db) {
    args := Map("selectors", db["selectors"])
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_start_quoting_status", args, 2, 120))
}

AdvisorQuoteBuildGatherStartQuotingStatusDetail(status) {
    return "hasStartQuotingText=" AdvisorQuoteStatusValue(status, "hasStartQuotingText")
        . ", startQuotingSectionPresent=" AdvisorQuoteStatusValue(status, "startQuotingSectionPresent")
        . ", autoProductPresent=" AdvisorQuoteStatusValue(status, "autoProductPresent")
        . ", autoProductChecked=" AdvisorQuoteStatusValue(status, "autoProductChecked")
        . ", autoProductSelected=" AdvisorQuoteStatusValue(status, "autoProductSelected")
        . ", autoProductSource=" AdvisorQuoteStatusValue(status, "autoProductSource")
        . ", autoCheckboxId=" AdvisorQuoteStatusValue(status, "autoCheckboxId")
        . ", ratingStatePresent=" AdvisorQuoteStatusValue(status, "ratingStatePresent")
        . ", ratingStateValue=" AdvisorQuoteStatusValue(status, "ratingStateValue")
        . ", ratingStateText=" AdvisorQuoteStatusValue(status, "ratingStateText")
        . ", ratingStateSource=" AdvisorQuoteStatusValue(status, "ratingStateSource")
        . ", createQuoteButtonPresent=" AdvisorQuoteStatusValue(status, "createQuoteButtonPresent")
        . ", createQuoteButtonEnabled=" AdvisorQuoteStatusValue(status, "createQuoteButtonEnabled")
        . ", addProductLinkPresent=" AdvisorQuoteStatusValue(status, "addProductLinkPresent")
        . ", createQuotesPresent=" AdvisorQuoteStatusValue(status, "createQuotesPresent")
        . ", createQuotesEnabled=" AdvisorQuoteStatusValue(status, "createQuotesEnabled")
        . ", addProductPresent=" AdvisorQuoteStatusValue(status, "addProductPresent")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
        . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
}

AdvisorQuoteBuildGatherStartQuotingApplyDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", autoApplied=" AdvisorQuoteStatusValue(status, "autoApplied")
        . ", autoMethod=" AdvisorQuoteStatusValue(status, "autoMethod")
        . ", ratingStateApplied=" AdvisorQuoteStatusValue(status, "ratingStateApplied")
        . ", ratingStateMethod=" AdvisorQuoteStatusValue(status, "ratingStateMethod")
        . ", " . AdvisorQuoteBuildGatherStartQuotingStatusDetail(status)
}

AdvisorQuoteGatherStartQuotingAutoSelected(status) {
    return (
        AdvisorQuoteStatusValue(status, "autoProductChecked") = "1"
        || AdvisorQuoteStatusValue(status, "autoProductSelected") = "1"
    )
}

AdvisorQuoteStartQuotingCreateQuotesPresent(status) {
    return AdvisorQuoteStatusValue(status, "createQuoteButtonPresent") = "1"
        || AdvisorQuoteStatusValue(status, "createQuotesPresent") = "1"
}

AdvisorQuoteStartQuotingCreateQuotesEnabled(status) {
    return AdvisorQuoteStatusValue(status, "createQuoteButtonEnabled") = "1"
        || AdvisorQuoteStatusValue(status, "createQuotesEnabled") = "1"
}

AdvisorQuoteStartQuotingScopedAddProductPresent(status) {
    return AdvisorQuoteStatusValue(status, "addProductLinkPresent") = "1"
        || AdvisorQuoteStatusValue(status, "addProductPresent") = "1"
        || AdvisorQuoteStatusValue(status, "startQuotingAddProductPresent") = "1"
}

AdvisorQuoteGatherStartQuotingCoreReady(status, db, &failureReason := "") {
    failureReason := ""
    if !IsObject(status) || (status.Count = 0) {
        failureReason := "Gather Data Start Quoting status could not be read back from the page."
        return false
    }
    if (AdvisorQuoteStatusValue(status, "hasStartQuotingText") != "1" || AdvisorQuoteStatusValue(status, "startQuotingSectionPresent") = "0") {
        failureReason := "Start Quoting block is not visible on Gather Data."
        return false
    }
    if (AdvisorQuoteStatusValue(status, "autoProductPresent") != "1") {
        failureReason := "Auto is not present in the Start Quoting block."
        return false
    }
    if !AdvisorQuoteGatherStartQuotingAutoSelected(status) {
        failureReason := "Auto is not selected in the Start Quoting block."
        return false
    }
    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "ratingStateValue"),
        AdvisorQuoteStatusValue(status, "ratingStateText"),
        db["defaults"]["ratingState"],
        db["defaults"]["ratingState"]
    ) {
        failureReason := "Start Quoting Rating State is not " db["defaults"]["ratingState"] "."
        return false
    }
    if !AdvisorQuoteStartQuotingCreateQuotesPresent(status) {
        failureReason := "Create Quotes & Order Reports is not present on Gather Data."
        return false
    }
    return true
}

AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(status, db, &failureReason := "") {
    if !AdvisorQuoteGatherStartQuotingCoreReady(status, db, &failureReason)
        return false
    if AdvisorQuoteStartQuotingCreateQuotesEnabled(status) {
        failureReason := "Create Quotes & Order Reports is already enabled."
        return false
    }
    if !AdvisorQuoteStartQuotingScopedAddProductPresent(status) {
        failureReason := "Scoped Start Quoting Add product link is not present."
        return false
    }
    failureReason := "START_QUOTING_NEEDS_SCOPED_ADD_PRODUCT"
    return true
}

AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(status, db, productOverviewAutoVerified, &failureReason := "") {
    if !productOverviewAutoVerified {
        failureReason := "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED"
        return false
    }
    return AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(status, db, &failureReason)
}

AdvisorQuoteGatherNeedsProductTileRecovery(status) {
    if !IsObject(status) || (status.Count = 0)
        return true
    if (AdvisorQuoteStatusValue(status, "hasStartQuotingText") != "1")
        return true
    if (AdvisorQuoteStatusValue(status, "startQuotingSectionPresent") = "0")
        return true
    if (AdvisorQuoteStatusValue(status, "autoProductPresent") != "1")
        return true
    return !AdvisorQuoteGatherStartQuotingAutoSelected(status)
}

AdvisorQuoteStartQuotingFailureCode(status, failureReason := "") {
    if !IsObject(status) || (status.Count = 0)
        return "START_QUOTING_SECTION_MISSING_OR_NOT_RENDERED: Gather Data Start Quoting status could not be read."
    if (AdvisorQuoteStatusValue(status, "hasStartQuotingText") != "1" || AdvisorQuoteStatusValue(status, "startQuotingSectionPresent") = "0")
        return "START_QUOTING_SECTION_MISSING_OR_NOT_RENDERED: " failureReason
    if (AdvisorQuoteStatusValue(status, "autoProductPresent") != "1")
        return "START_QUOTING_AUTO_NOT_PRESENT: " failureReason
    if !AdvisorQuoteGatherStartQuotingAutoSelected(status)
        return "START_QUOTING_AUTO_NOT_CHECKED: " failureReason
    if (AdvisorQuoteStatusValue(status, "ratingStatePresent") != "1")
        return "START_QUOTING_RATING_STATE_INVALID: " failureReason
    if !AdvisorQuoteStartQuotingCreateQuotesPresent(status) || !AdvisorQuoteStartQuotingCreateQuotesEnabled(status)
        return "START_QUOTING_CREATE_QUOTES_DISABLED: " failureReason
    return "START_QUOTING_RATING_STATE_INVALID: " failureReason
}

AdvisorQuoteGatherStartQuotingStatusValid(status, db, &failureReason := "") {
    if !AdvisorQuoteGatherStartQuotingCoreReady(status, db, &failureReason)
        return false
    if !AdvisorQuoteStartQuotingCreateQuotesEnabled(status) {
        failureReason := "Create Quotes & Order Reports is still disabled on Gather Data."
        return false
    }
    return true
}

AdvisorQuoteInferGatherHomeType(profile, db) {
    apartmentValue := String(db["defaults"]["gatherResidenceTypeApartmentValue"])
    singleFamilyValue := String(db["defaults"]["gatherResidenceTypeSingleFamilyValue"])
    residence := (IsObject(profile) && profile.Has("residence")) ? profile["residence"] : Map()
    if (IsObject(residence) && residence.Has("hasUnit") && residence["hasUnit"])
        return apartmentValue

    address := (IsObject(profile) && profile.Has("address")) ? profile["address"] : Map()
    fields := (IsObject(profile) && profile.Has("fields")) ? profile["fields"] : Map()
    parts := []
    if IsObject(address) {
        if address.Has("street")
            parts.Push(String(address["street"]))
        if address.Has("aptSuite")
            parts.Push(String(address["aptSuite"]))
    }
    if IsObject(fields) {
        if fields.Has("ADDRESS_1")
            parts.Push(String(fields["ADDRESS_1"]))
        if fields.Has("APT_SUITE")
            parts.Push(String(fields["APT_SUITE"]))
    }
    if (IsObject(profile) && profile.Has("rawRow"))
        parts.Push(String(profile["rawRow"]))
    if (IsObject(profile) && profile.Has("raw"))
        parts.Push(String(profile["raw"]))

    combined := StrLower(JoinArray(parts, " | "))
    if RegExMatch(combined, "(?:^|\b)(apt|apartment|unit|ste|suite|lot|room)\b")
        return apartmentValue
    if RegExMatch(combined, "#\s*[A-Za-z0-9]")
        return apartmentValue
    return singleFamilyValue
}

AdvisorQuoteGatherHomeTypeLabel(homeTypeValue) {
    normalized := AdvisorNormalizeLooseToken(homeTypeValue)
    if (normalized = "AP")
        return "Apartment"
    if (normalized = "SF")
        return "Single Family"
    return homeTypeValue
}

AdvisorQuoteStatusOptionMatches(actualValue, actualText, expectedValue, expectedText := "") {
    wantedValue := AdvisorNormalizeLooseToken(expectedValue)
    wantedText := AdvisorNormalizeLooseToken(expectedText)
    valueNorm := AdvisorNormalizeLooseToken(actualValue)
    textNorm := AdvisorNormalizeLooseToken(actualText)
    if (wantedValue != "" && valueNorm = wantedValue)
        return true
    if (wantedText != "" && textNorm != "" && InStr(textNorm, wantedText))
        return true
    return false
}

AdvisorQuoteProfileFullName(profile) {
    person := (IsObject(profile) && profile.Has("person")) ? profile["person"] : Map()
    fullName := person.Has("fullName") ? Trim(String(person["fullName"])) : ""
    if (fullName = "")
        fullName := Trim(String((person.Has("firstName") ? person["firstName"] : "") . " " . (person.Has("lastName") ? person["lastName"] : "")))
    return fullName
}

AdvisorQuoteLeadMaritalStatus(profile) {
    raw := (IsObject(profile) && profile.Has("raw")) ? String(profile["raw"]) : ""
    fields := (IsObject(profile) && profile.Has("fields")) ? profile["fields"] : Map()
    if (IsObject(fields) && fields.Has("MARITAL_STATUS")) {
        normalizedField := AdvisorQuoteNormalizeMaritalStatus(fields["MARITAL_STATUS"])
        if (normalizedField != "")
            return normalizedField
    }
    if RegExMatch(raw, "i)\bMarital\s+Status\s*:\s*(Single|Married|Divorced|Widowed|Separated)\b", &m)
        return AdvisorQuoteNormalizeMaritalStatus(m[1])
    return ""
}

AdvisorQuoteNormalizeMaritalStatus(value) {
    text := AdvisorNormalizeLooseToken(value)
    if InStr(text, "SINGLE")
        return "Single"
    if InStr(text, "MARRIED")
        return "Married"
    if InStr(text, "DIVORCED")
        return "Divorced"
    if InStr(text, "WIDOW")
        return "Widowed"
    if InStr(text, "SEPARATED")
        return "Separated"
    return ""
}

AdvisorQuoteLeadSpouseName(profile) {
    raw := (IsObject(profile) && profile.Has("raw")) ? String(profile["raw"]) : ""
    if RegExMatch(raw, "i)\b(?:Spouse|Spouse\s+Name)\s*:\s*([^\r\n]+)", &m)
        return Trim(String(m[1]))
    return ""
}

AdvisorQuoteExpectedDriverNamesText(profile, selectedSpouseName := "") {
    names := []
    primary := AdvisorQuoteProfileFullName(profile)
    if (primary != "")
        names.Push(primary)
    if (Trim(String(selectedSpouseName)) != "")
        names.Push(Trim(String(selectedSpouseName)))
    return JoinArray(names, "||")
}

AdvisorQuoteBuildVehicleJsArgs(vehicle, includeCatalogMakeLabels := false) {
    args := Map(
        "year", vehicle["year"],
        "make", vehicle["make"],
        "model", vehicle["model"]
    )
    if (IsObject(vehicle) && vehicle.Has("trimHint"))
        args["trimHint"] := vehicle["trimHint"]
    if (IsObject(vehicle) && vehicle.Has("vin"))
        args["vin"] := vehicle["vin"]
    if (IsObject(vehicle) && vehicle.Has("vinSuffix"))
        args["vinSuffix"] := vehicle["vinSuffix"]
    if (includeCatalogMakeLabels) {
        resolved := AdvisorVehicleDbResolveLeadVehicle(vehicle["year"], vehicle["make"], vehicle["model"], vehicle.Has("vin") ? vehicle["vin"] : "")
        dbArgs := AdvisorVehicleDbBuildJsVehicleArgs(resolved)
        for key, value in dbArgs
            args[key] := value
        args["allowedMakeLabels"] := AdvisorVehicleAllowedMakeLabelsText(vehicle["make"], vehicle["model"], vehicle["year"])
        if (resolved.Has("advisorMakeLabels") && resolved["advisorMakeLabels"].Length > 0)
            args["allowedMakeLabels"] := JoinArray(resolved["advisorMakeLabels"], "|")
        args["strictModelMatch"] := "1"
    }
    return args
}

AdvisorQuoteVehicleDbResolveResult(resolvedVehicle) {
    if (IsObject(resolvedVehicle) && resolvedVehicle.Has("result"))
        return Trim(String(resolvedVehicle["result"]))
    return "UNKNOWN"
}

AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle := "") {
    if !IsObject(resolvedVehicle)
        return "dbResult=UNKNOWN, dbReason=no-resolution"
    return "dbResult=" AdvisorQuoteStatusValue(resolvedVehicle, "result")
        . ", dbReason=" AdvisorQuoteStatusValue(resolvedVehicle, "reason")
        . ", confidence=" AdvisorQuoteStatusValue(resolvedVehicle, "confidence")
        . ", year=" AdvisorQuoteStatusValue(resolvedVehicle, "year")
        . ", inputMake=" AdvisorQuoteStatusValue(resolvedVehicle, "inputMake")
        . ", inputModel=" AdvisorQuoteStatusValue(resolvedVehicle, "inputModel")
        . ", canonicalMake=" AdvisorQuoteStatusValue(resolvedVehicle, "canonicalMake")
        . ", canonicalModel=" AdvisorQuoteStatusValue(resolvedVehicle, "canonicalModel")
        . ", advisorMakeLabels=" (resolvedVehicle.Has("advisorMakeLabels") ? JoinArray(resolvedVehicle["advisorMakeLabels"], "|") : "")
        . ", modelAliases=" (resolvedVehicle.Has("modelAliases") ? JoinArray(resolvedVehicle["modelAliases"], "|") : "")
        . ", normalizedModelKeys=" (resolvedVehicle.Has("normalizedModelKeys") ? JoinArray(resolvedVehicle["normalizedModelKeys"], "|") : "")
        . ", possibleMatches=" (resolvedVehicle.Has("possibleMatches") ? JoinArray(resolvedVehicle["possibleMatches"], " || ") : "")
}

AdvisorQuoteVehicleHasVinEvidence(vehicle) {
    return IsObject(vehicle)
        && ((vehicle.Has("vin") && Trim(String(vehicle["vin"])) != "")
            || (vehicle.Has("vinSuffix") && Trim(String(vehicle["vinSuffix"])) != ""))
}

AdvisorQuoteVehicleHasActionableFields(vehicle) {
    return IsObject(vehicle)
        && vehicle.Has("year") && Trim(String(vehicle["year"])) != ""
        && vehicle.Has("make") && Trim(String(vehicle["make"])) != ""
        && vehicle.Has("model") && Trim(String(vehicle["model"])) != ""
}

AdvisorQuoteVehicleHasPartialYearMakeFields(vehicle) {
    return IsObject(vehicle)
        && vehicle.Has("year") && Trim(String(vehicle["year"])) != ""
        && vehicle.Has("make") && Trim(String(vehicle["make"])) != ""
        && (!vehicle.Has("model") || Trim(String(vehicle["model"])) = "")
}

AdvisorQuoteRapportVehicleMode(db := "") {
    mode := ""
    if (IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]) && db["defaults"].Has("rapportVehicleMode"))
        mode := Trim(String(db["defaults"]["rapportVehicleMode"]))
    if (mode = "")
        mode := "match-existing-then-add-complete"
    if (mode = "match-existing-only" || mode = "match-existing-then-add-complete")
        return mode
    return "match-existing-then-add-complete"
}

AdvisorQuoteRapportVehicleModeAllowsAddComplete(mode) {
    return Trim(String(mode)) = "match-existing-then-add-complete"
}

AdvisorQuoteCompleteDbResolvedVehicleAddEligible(vehicle, resolvedVehicle, rapportVehicleMode := "match-existing-then-add-complete") {
    return AdvisorQuoteRapportVehicleModeAllowsAddComplete(rapportVehicleMode)
        && AdvisorQuoteVehicleHasActionableFields(vehicle)
        && (AdvisorQuoteVehicleDbResolveResult(resolvedVehicle) = "RESOLVED")
}

AdvisorQuoteVehicleLabel(vehicle) {
    if !IsObject(vehicle)
        return ""
    if (vehicle.Has("displayKey") && Trim(String(vehicle["displayKey"])) != "")
        return Trim(String(vehicle["displayKey"]))
    parts := []
    for _, key in ["year", "make", "model", "vinSuffix"] {
        if (vehicle.Has(key) && Trim(String(vehicle[key])) != "")
            parts.Push(Trim(String(vehicle[key])))
    }
    raw := vehicle.Has("raw") ? Trim(String(vehicle["raw"])) : ""
    return parts.Length ? JoinArray(parts, "|") : raw
}

AdvisorQuoteVehicleListSummary(vehicles) {
    if !IsObject(vehicles)
        return ""
    parts := []
    for _, vehicle in vehicles
        parts.Push(AdvisorQuoteVehicleLabel(vehicle))
    return JoinArray(parts, " || ")
}

AdvisorQuoteJoinVehicleLists(lists*) {
    result := []
    for _, list in lists {
        if !IsObject(list)
            continue
        for _, vehicle in list
            result.Push(vehicle)
    }
    return result
}

AdvisorQuoteGetGatherProfileVehicles(profile) {
    result := []
    seen := Map()

    vehicles := (IsObject(profile) && profile.Has("vehicles")) ? profile["vehicles"] : []
    if IsObject(vehicles) {
        for _, vehicle in vehicles
            AdvisorQuoteAppendUniqueVehicleByDisplayKey(result, seen, vehicle)
    }

    raw := (IsObject(profile) && profile.Has("raw")) ? Trim(String(profile["raw"])) : ""
    if (raw != "") {
        for _, vehicleText in ExtractVehicleList(raw) {
            normalized := AdvisorNormalizeVehicleDescriptor(vehicleText)
            AdvisorQuoteAppendUniqueVehicleByDisplayKey(result, seen, normalized)
        }
    }

    return result
}

AdvisorQuoteAppendUniqueVehicleByDisplayKey(vehicleList, seenVehicleKeys, vehicle) {
    if !IsObject(vehicle)
        return false
    if !vehicle.Has("displayKey")
        return false
    key := Trim(String(vehicle["displayKey"]))
    if (key = "")
        return false
    if seenVehicleKeys.Has(key)
        return false
    seenVehicleKeys[key] := true
    vehicleList.Push(vehicle)
    return true
}

AdvisorQuoteClassifyGatherVehicles(profile) {
    vehicles := AdvisorQuoteGetGatherProfileVehicles(profile)
    actionable := []
    partial := []
    missingYearNoVin := []
    deferredVin := []
    blocking := []

    for _, vehicle in vehicles {
        if AdvisorQuoteVehicleHasActionableFields(vehicle) {
            actionable.Push(vehicle)
            continue
        }
        if AdvisorQuoteVehicleHasVinEvidence(vehicle) {
            deferredVin.Push(vehicle)
            continue
        }
        if AdvisorQuoteVehicleHasPartialYearMakeFields(vehicle) {
            partial.Push(vehicle)
            continue
        }
        year := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
        make := IsObject(vehicle) && vehicle.Has("make") ? Trim(String(vehicle["make"])) : ""
        model := IsObject(vehicle) && vehicle.Has("model") ? Trim(String(vehicle["model"])) : ""
        if (year = "" && (make != "" || model != "")) {
            missingYearNoVin.Push(vehicle)
            continue
        }
        blocking.Push(vehicle)
    }

    ignored := []
    if (actionable.Length > 0) {
        for _, vehicle in missingYearNoVin
            ignored.Push(vehicle)
    } else {
        for _, vehicle in missingYearNoVin
            blocking.Push(vehicle)
    }

    return Map(
        "actionableVehicles", actionable,
        "partialYearMakeVehicles", partial,
        "ignoredMissingYearVehicles", ignored,
        "deferredVinVehicles", deferredVin,
        "blockingMissingVehicleData", blocking
    )
}

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

AdvisorQuoteRapportVehicleLedgerMaxIterations(rateableVehicleCount) {
    return (Integer(rateableVehicleCount) * 3) + 4
}

AdvisorQuoteRapportVehicleTerminalStatus(status) {
    switch Trim(String(status)) {
        case "CONFIRMED_EXACT", "CONFIRMED_POTENTIAL_MATCH", "ADDED_DB_RESOLVED", "ADDED_MODEL_PLACEHOLDER", "ADDED_SUBMODEL_PLACEHOLDER", "SCRAP_YEAR_MISSING", "SCRAP_MAKE_MISSING", "SCRAP_MAKE_UNAVAILABLE", "SCRAP_MODEL_UNAVAILABLE", "DEFERRED_AMBIGUOUS", "FAILED_UNSAFE":
            return true
        default:
            return false
    }
}

AdvisorQuoteRapportVehicleLedgerCreate(profile, db) {
    vehicles := AdvisorQuoteGetGatherProfileVehicles(profile)
    items := []
    rateableCount := 0
    scrappedCount := 0
    modelFallbackEnabled := AdvisorQuoteRapportModelPlaceholderFallbackEnabled(db)
    for index, vehicle in vehicles {
        year := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
        make := IsObject(vehicle) && vehicle.Has("make") ? Trim(String(vehicle["make"])) : ""
        model := IsObject(vehicle) && vehicle.Has("model") ? Trim(String(vehicle["model"])) : ""
        status := ""
        kind := ""
        if (year = "") {
            status := "SCRAP_YEAR_MISSING"
            kind := "scrap"
            scrappedCount += 1
        } else if (make = "") {
            status := "SCRAP_MAKE_MISSING"
            kind := "scrap"
            scrappedCount += 1
        } else if (model = "") {
            if modelFallbackEnabled {
                kind := "model-placeholder"
                rateableCount += 1
            } else {
                status := "SCRAP_MODEL_UNAVAILABLE"
                kind := "scrap"
                scrappedCount += 1
            }
        } else {
            kind := "exact"
            rateableCount += 1
        }
        items.Push(Map(
            "index", index,
            "vehicle", vehicle,
            "key", AdvisorQuoteVehicleLabel(vehicle),
            "kind", kind,
            "status", status,
            "detail", ""
        ))
    }
    ledger := Map(
        "items", items,
        "rateableCount", rateableCount,
        "scrappedCount", scrappedCount,
        "iterations", 0,
        "maxIterations", AdvisorQuoteRapportVehicleLedgerMaxIterations(rateableCount),
        "actionKeys", Map()
    )
    for _, item in items {
        if (item["status"] = "SCRAP_YEAR_MISSING")
            AdvisorQuoteAppendLog("RAPPORT_VEHICLE_SCRAPPED_YEAR_MISSING", AdvisorQuoteGetLastStep(), "vehicle=" item["key"])
        else if (item["status"] = "SCRAP_MAKE_MISSING")
            AdvisorQuoteAppendLog("RAPPORT_VEHICLE_SCRAPPED_MAKE_MISSING", AdvisorQuoteGetLastStep(), "vehicle=" item["key"])
        AdvisorQuoteAppendLog("RAPPORT_VEHICLE_LEDGER_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteRapportVehicleLedgerItemDetail(item))
    }
    return ledger
}

AdvisorQuoteRapportVehicleLedgerItemDetail(item) {
    vehicle := IsObject(item) && item.Has("vehicle") ? item["vehicle"] : ""
    return "vehicle=" (IsObject(item) && item.Has("key") ? item["key"] : AdvisorQuoteVehicleLabel(vehicle))
        . ", kind=" (IsObject(item) && item.Has("kind") ? item["kind"] : "")
        . ", status=" (IsObject(item) && item.Has("status") ? item["status"] : "")
        . ", detail=" (IsObject(item) && item.Has("detail") ? item["detail"] : "")
}

AdvisorQuoteRapportVehicleLedgerFindItem(ledger, vehicle) {
    if !(IsObject(ledger) && ledger.Has("items"))
        return ""
    key := AdvisorQuoteVehicleLabel(vehicle)
    for _, item in ledger["items"] {
        if (item["key"] = key)
            return item
    }
    return ""
}

AdvisorQuoteRapportVehicleLedgerSetStatus(ledger, vehicle, status, detail := "") {
    item := AdvisorQuoteRapportVehicleLedgerFindItem(ledger, vehicle)
    if !IsObject(item)
        return
    item["status"] := status
    item["detail"] := detail
    eventType := "RAPPORT_VEHICLE_LEDGER_STATUS"
    switch status {
        case "ADDED_DB_RESOLVED":
            eventType := "RAPPORT_VEHICLE_ADDED_DB_RESOLVED"
        case "ADDED_MODEL_PLACEHOLDER":
            eventType := "RAPPORT_VEHICLE_ADDED_MODEL_PLACEHOLDER"
        case "ADDED_SUBMODEL_PLACEHOLDER":
            eventType := "RAPPORT_VEHICLE_ADDED_SUBMODEL_PLACEHOLDER"
        case "SCRAP_YEAR_MISSING":
            eventType := "RAPPORT_VEHICLE_SCRAPPED_YEAR_MISSING"
        case "SCRAP_MAKE_MISSING":
            eventType := "RAPPORT_VEHICLE_SCRAPPED_MAKE_MISSING"
        case "SCRAP_MAKE_UNAVAILABLE":
            eventType := "RAPPORT_VEHICLE_SCRAPPED_MAKE_UNAVAILABLE"
    }
    AdvisorQuoteAppendLog(eventType, AdvisorQuoteGetLastStep(), AdvisorQuoteRapportVehicleLedgerItemDetail(item))
    if (eventType != "RAPPORT_VEHICLE_LEDGER_STATUS")
        AdvisorQuoteAppendLog("RAPPORT_VEHICLE_LEDGER_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteRapportVehicleLedgerItemDetail(item))
}

AdvisorQuoteRapportVehicleLedgerRecordAction(ledger, vehicle, actionType, &failureReason := "") {
    failureReason := ""
    if !IsObject(ledger)
        return true
    ledger["iterations"] := AdvisorQuoteStatusInteger(ledger, "iterations") + 1
    if (ledger["iterations"] > ledger["maxIterations"]) {
        failureReason := "RAPPORT_VEHICLE_LEDGER_LOOP_GUARD: maxIterations=" ledger["maxIterations"]
        return false
    }
    key := AdvisorQuoteVehicleLabel(vehicle) "|" actionType
    if ledger["actionKeys"].Has(key) {
        failureReason := "RAPPORT_VEHICLE_LEDGER_LOOP_GUARD: repeatedAction=" actionType ", vehicle=" AdvisorQuoteVehicleLabel(vehicle)
        return false
    }
    ledger["actionKeys"][key] := true
    AdvisorQuoteAppendLog(
        "RAPPORT_VEHICLE_LEDGER_NEXT_ACTION",
        AdvisorQuoteGetLastStep(),
        "iteration=" ledger["iterations"]
            . ", maxIterations=" ledger["maxIterations"]
            . ", vehicle=" AdvisorQuoteVehicleLabel(vehicle)
            . ", action=" actionType
    )
    return true
}

AdvisorQuoteRapportVehicleLedgerAllRateableTerminal(ledger) {
    if !(IsObject(ledger) && ledger.Has("items"))
        return true
    for _, item in ledger["items"] {
        if (item["kind"] = "exact" || item["kind"] = "model-placeholder") {
            if !AdvisorQuoteRapportVehicleTerminalStatus(item["status"])
                return false
        }
    }
    return true
}

AdvisorQuoteRapportVehicleLedgerSatisfiedCount(ledger) {
    count := 0
    if !(IsObject(ledger) && ledger.Has("items"))
        return count
    for _, item in ledger["items"] {
        switch item["status"] {
            case "CONFIRMED_EXACT", "CONFIRMED_POTENTIAL_MATCH", "ADDED_DB_RESOLVED", "ADDED_MODEL_PLACEHOLDER", "ADDED_SUBMODEL_PLACEHOLDER":
                count += 1
        }
    }
    return count
}

AdvisorQuoteRapportVehicleLedgerStartQuotingAllowed(ledger, confirmedOrAddedVehicleCount, staleAddRowPresent, vehicleWarningPresent, createQuotesEnabled) {
    return AdvisorQuoteRapportVehicleLedgerAllRateableTerminal(ledger)
        && Integer(confirmedOrAddedVehicleCount) > 0
        && Trim(String(staleAddRowPresent)) != "1"
        && (Trim(String(vehicleWarningPresent)) != "1" || Trim(String(createQuotesEnabled)) = "1")
}

AdvisorQuoteRapportVehicleLedgerSummary(ledger) {
    if !(IsObject(ledger) && ledger.Has("items"))
        return ""
    parts := []
    for _, item in ledger["items"]
        parts.Push(item["key"] ":" item["status"])
    return JoinArray(parts, " || ")
}

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

AdvisorQuoteLogGatherVehiclePolicy(policy) {
    actionable := IsObject(policy) && policy.Has("actionableVehicles") ? policy["actionableVehicles"] : []
    partial := IsObject(policy) && policy.Has("partialYearMakeVehicles") ? policy["partialYearMakeVehicles"] : []
    ignored := IsObject(policy) && policy.Has("ignoredMissingYearVehicles") ? policy["ignoredMissingYearVehicles"] : []
    deferred := IsObject(policy) && policy.Has("deferredVinVehicles") ? policy["deferredVinVehicles"] : []
    blocking := IsObject(policy) && policy.Has("blockingMissingVehicleData") ? policy["blockingMissingVehicleData"] : []
    AdvisorQuoteAppendLog(
        "GATHER_VEHICLE_POLICY",
        AdvisorQuoteGetLastStep(),
        "actionableVehicleCount=" actionable.Length
            . ", partialYearMakeVehicleCount=" partial.Length
            . ", ignoredMissingYearVehicleCount=" ignored.Length
            . ", deferredVinVehicleCount=" deferred.Length
            . ", blockingMissingVehicleDataCount=" blocking.Length
            . ", actionableVehicles=" AdvisorQuoteVehicleListSummary(actionable)
            . ", partialYearMakeVehicles=" AdvisorQuoteVehicleListSummary(partial)
            . ", ignoredMissingYearVehicles=" AdvisorQuoteVehicleListSummary(ignored)
            . ", deferredVinVehicles=" AdvisorQuoteVehicleListSummary(deferred)
            . ", blockingMissingVehicleData=" AdvisorQuoteVehicleListSummary(blocking)
    )
}

AdvisorQuoteBuildExpectedVehiclesTextFromList(vehicles) {
    if !IsObject(vehicles)
        return ""
    parts := []
    for _, vehicle in vehicles {
        year := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
        make := IsObject(vehicle) && vehicle.Has("make") ? Trim(String(vehicle["make"])) : ""
        model := IsObject(vehicle) && vehicle.Has("model") ? Trim(String(vehicle["model"])) : ""
        vin := IsObject(vehicle) && vehicle.Has("vin") ? Trim(String(vehicle["vin"])) : ""
        if (year != "" || make != "" || model != "" || vin != "")
            parts.Push(year "|" make "|" model "|" vin)
    }
    return JoinArray(parts, "||")
}

AdvisorQuoteBuildExpectedVehiclesArgList(vehicles) {
    result := []
    if !IsObject(vehicles)
        return result
    for _, vehicle in vehicles {
        year := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
        make := IsObject(vehicle) && vehicle.Has("make") ? Trim(String(vehicle["make"])) : ""
        model := IsObject(vehicle) && vehicle.Has("model") ? Trim(String(vehicle["model"])) : ""
        vin := IsObject(vehicle) && vehicle.Has("vin") ? Trim(String(vehicle["vin"])) : ""
        vinSuffix := IsObject(vehicle) && vehicle.Has("vinSuffix") ? Trim(String(vehicle["vinSuffix"])) : ""
        if (year = "" && make = "" && model = "" && vin = "" && vinSuffix = "")
            continue
        item := Map(
            "year", year,
            "make", make,
            "model", model,
            "vin", vin,
            "vinSuffix", vinSuffix,
            "allowedMakeLabels", AdvisorVehicleAllowedMakeLabelsText(make, model, year),
            "strictModelMatch", "1"
        )
        resolved := AdvisorVehicleDbResolveLeadVehicle(year, make, model, vin)
        if IsObject(resolved) {
            if (resolved.Has("advisorMakeLabels") && resolved["advisorMakeLabels"].Length > 0)
                item["allowedMakeLabels"] := JoinArray(resolved["advisorMakeLabels"], "|")
            if (resolved.Has("modelAliases") && resolved["modelAliases"].Length > 0)
                item["modelAliases"] := JoinArray(resolved["modelAliases"], "|")
            if (resolved.Has("normalizedModelKeys") && resolved["normalizedModelKeys"].Length > 0)
                item["normalizedModelKeys"] := JoinArray(resolved["normalizedModelKeys"], "|")
            item["dbResult"] := AdvisorQuoteStatusValue(resolved, "result")
            item["dbReason"] := AdvisorQuoteStatusValue(resolved, "reason")
            item["canonicalMake"] := AdvisorQuoteStatusValue(resolved, "canonicalMake")
            item["canonicalModel"] := AdvisorQuoteStatusValue(resolved, "canonicalModel")
        }
        if IsObject(vehicle) {
            for _, metaKey in ["promotedFromPartial", "promotionSource", "promotedVehicleText", "originalLeadText", "promotedVinEvidence"] {
                if vehicle.Has(metaKey)
                    item[metaKey] := vehicle[metaKey]
            }
        }
        result.Push(item)
    }
    return result
}

AdvisorQuoteBuildGatherFinalExpectedVehicles(actionableVehicles, promotedPartialVehicles) {
    return AdvisorQuoteJoinVehicleLists(actionableVehicles, promotedPartialVehicles)
}

AdvisorQuoteVehicleIdentityKey(vehicle) {
    if !IsObject(vehicle)
        return ""
    year := vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
    make := vehicle.Has("make") ? Trim(String(vehicle["make"])) : ""
    model := vehicle.Has("model") ? Trim(String(vehicle["model"])) : ""
    return AdvisorBuildVehicleDisplayKey(year, make, model)
}

AdvisorQuoteExpectedArgIdentityKey(expected) {
    if !IsObject(expected)
        return ""
    year := expected.Has("year") ? Trim(String(expected["year"])) : ""
    make := expected.Has("make") ? Trim(String(expected["make"])) : ""
    model := expected.Has("model") ? Trim(String(expected["model"])) : ""
    return AdvisorBuildVehicleDisplayKey(year, make, model)
}

AdvisorQuoteExpectedArgsContainVehicle(expectedArgs, vehicle) {
    targetKey := AdvisorQuoteVehicleIdentityKey(vehicle)
    if (targetKey = "")
        return false
    if !IsObject(expectedArgs)
        return false
    for _, expected in expectedArgs {
        if (AdvisorQuoteExpectedArgIdentityKey(expected) = targetKey)
            return true
    }
    return false
}

AdvisorQuoteCountExpectedArgsMatchingVehicles(expectedArgs, vehicles) {
    count := 0
    if !IsObject(vehicles)
        return count
    for _, vehicle in vehicles {
        if AdvisorQuoteExpectedArgsContainVehicle(expectedArgs, vehicle)
            count += 1
    }
    return count
}

AdvisorQuoteExpectedArgsMissingVehiclesSummary(expectedArgs, vehicles) {
    missing := []
    if IsObject(vehicles) {
        for _, vehicle in vehicles {
            if !AdvisorQuoteExpectedArgsContainVehicle(expectedArgs, vehicle)
                missing.Push(AdvisorQuoteVehicleLabel(vehicle))
        }
    }
    return JoinArray(missing, " || ")
}

AdvisorQuoteBuildExpectedVehiclesText(profile) {
    if !IsObject(profile) || !profile.Has("vehicles")
        return ""
    return AdvisorQuoteBuildExpectedVehiclesTextFromList(profile["vehicles"])
}

AdvisorQuoteGetGatherConfirmedVehiclesStatusForVehicles(vehicles) {
    args := Map("expectedVehicles", AdvisorQuoteBuildExpectedVehiclesArgList(vehicles))
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_confirmed_vehicles_status", args))
}

AdvisorQuoteGetGatherConfirmedVehiclesStatus(profile) {
    vehicles := IsObject(profile) && profile.Has("vehicles") ? profile["vehicles"] : []
    args := Map("expectedVehicles", AdvisorQuoteBuildExpectedVehiclesArgList(vehicles))
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_confirmed_vehicles_status", args))
}

AdvisorQuoteGetGatherStaleAddVehicleRowStatus(allExpectedVehiclesSatisfied := false) {
    args := Map("allExpectedVehiclesSatisfied", allExpectedVehiclesSatisfied ? "1" : "0")
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_stale_add_vehicle_row_status", args))
}

AdvisorQuoteCancelStaleAddVehicleRow(allExpectedVehiclesSatisfied := false) {
    args := Map("allExpectedVehiclesSatisfied", allExpectedVehiclesSatisfied ? "1" : "0")
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("cancel_stale_add_vehicle_row", args))
}

AdvisorQuoteSelectGatherAddRowFirstValidSubModel(allExpectedVehiclesSatisfied := false) {
    args := Map("allExpectedVehiclesSatisfied", allExpectedVehiclesSatisfied ? "1" : "0")
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("select_gather_add_row_first_valid_submodel", args))
}

AdvisorQuoteClickGatherAddRowAddButton(allExpectedVehiclesSatisfied := false) {
    args := Map("allExpectedVehiclesSatisfied", allExpectedVehiclesSatisfied ? "1" : "0")
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("click_gather_add_row_add_button", args))
}

AdvisorQuoteBuildGatherConfirmedVehiclesStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", confirmedCount=" AdvisorQuoteStatusValue(status, "confirmedCount")
        . ", expectedCount=" AdvisorQuoteStatusValue(status, "expectedCount")
        . ", matchedExpectedCount=" AdvisorQuoteStatusValue(status, "matchedExpectedCount")
        . ", unexpectedCount=" AdvisorQuoteStatusValue(status, "unexpectedCount")
        . ", unexpectedVehicles=" AdvisorQuoteStatusValue(status, "unexpectedVehicles")
        . ", matchedVehicles=" AdvisorQuoteStatusValue(status, "matchedVehicles")
        . ", missingExpectedVehicles=" AdvisorQuoteStatusValue(status, "missingExpectedVehicles")
        . ", unresolvedLeadVehicles=" AdvisorQuoteStatusValue(status, "unresolvedLeadVehicles")
        . ", method=" AdvisorQuoteStatusValue(status, "method")
}

AdvisorQuoteBuildGatherStaleVehicleRowStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", rowTitle=" AdvisorQuoteStatusValue(status, "rowTitle")
        . ", rowIncomplete=" AdvisorQuoteStatusValue(status, "rowIncomplete")
        . ", yearValue=" AdvisorQuoteStatusValue(status, "yearValue")
        . ", vinValue=" AdvisorQuoteStatusValue(status, "vinValue")
        . ", manufacturerValue=" AdvisorQuoteStatusValue(status, "manufacturerValue")
        . ", modelValue=" AdvisorQuoteStatusValue(status, "modelValue")
        . ", subModelValue=" AdvisorQuoteStatusValue(status, "subModelValue")
        . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
        . ", cancelButtonPresent=" AdvisorQuoteStatusValue(status, "cancelButtonPresent")
        . ", cancelButtonScoped=" AdvisorQuoteStatusValue(status, "cancelButtonScoped")
        . ", safeToCancel=" AdvisorQuoteStatusValue(status, "safeToCancel")
        . ", reason=" AdvisorQuoteStatusValue(status, "reason")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

AdvisorQuoteBuildGatherStaleVehicleCancelDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", cancelButtonText=" AdvisorQuoteStatusValue(status, "cancelButtonText")
        . ", cancelButtonClass=" AdvisorQuoteStatusValue(status, "cancelButtonClass")
        . ", beforeRowText=" AdvisorQuoteStatusValue(status, "beforeRowText")
        . ", afterRowPresent=" AdvisorQuoteStatusValue(status, "afterRowPresent")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
}

AdvisorQuoteCleanupStaleGatherVehicleRowIfSafe(expectedVehicles, staleDuplicateRowSeen := false, staleDuplicateRowDetails := "", &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    status := AdvisorQuoteGetGatherStaleAddVehicleRowStatus(true)
    AdvisorQuoteAppendLog(
        "STALE_ADD_VEHICLE_ROW_STATUS",
        AdvisorQuoteGetLastStep(),
        AdvisorQuoteBuildGatherStaleVehicleRowStatusDetail(status)
            . ", staleDuplicateRowSeen=" (staleDuplicateRowSeen ? "1" : "0")
            . ", staleDuplicateRowDetails=" staleDuplicateRowDetails
    )
    result := AdvisorQuoteStatusValue(status, "result")
    if (result = "" || result = "NONE")
        return true
    if (AdvisorQuoteStatusValue(status, "safeToCancel") != "1") {
        failureReason := "STALE_ADD_ROW_CANCEL_UNSAFE: stale Add Car/Truck row exists but is not safe to cancel. reason=" AdvisorQuoteStatusValue(status, "reason")
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "stale-add-row-cancel-unsafe")
        return false
    }

    cancelStatus := AdvisorQuoteCancelStaleAddVehicleRow(true)
    AdvisorQuoteAppendLog("STALE_ADD_VEHICLE_ROW_CANCEL", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStaleVehicleCancelDetail(cancelStatus))
    if (AdvisorQuoteStatusValue(cancelStatus, "result") != "CANCELLED") {
        failureReason := "STALE_ADD_ROW_CANCEL_FAILED: " AdvisorQuoteBuildGatherStaleVehicleCancelDetail(cancelStatus)
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "stale-add-row-cancel-failed")
        return false
    }

    rowStatus := AdvisorQuoteGetGatherVehicleRowStatus()
    AdvisorQuoteLogGatherVehicleRowStatus(rowStatus, "STALE_ADD_ROW_POST_CANCEL_ROW_STATUS")
    confirmedStatus := AdvisorQuoteGetGatherConfirmedVehiclesStatusForVehicles(expectedVehicles)
    AdvisorQuoteAppendLog("GATHER_CONFIRMED_VEHICLES_STATUS_AFTER_STALE_ROW_CANCEL", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherConfirmedVehiclesStatusDetail(confirmedStatus))
    safeReason := ""
    if !AdvisorQuoteGatherConfirmedVehiclesSafe(confirmedStatus, "", &safeReason) {
        failureReason := "STALE_ADD_ROW_CANCEL_RECONCILIATION_FAILED: " safeReason
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "stale-add-row-cancel-reconciliation-failed")
        return false
    }
    return true
}

AdvisorQuoteGatherConfirmedVehiclesSafe(status, profile, &failureReason := "") {
    failureReason := ""
    result := AdvisorQuoteStatusValue(status, "result")
    if (result = "UNEXPECTED") {
        failureReason := "UNEXPECTED_CONFIRMED_VEHICLES: " AdvisorQuoteStatusValue(status, "unexpectedVehicles")
        return false
    }
    expectedCount := AdvisorQuoteStatusInteger(status, "expectedCount")
    matchedExpectedCount := AdvisorQuoteStatusInteger(status, "matchedExpectedCount")
    unresolved := AdvisorQuoteStatusValue(status, "unresolvedLeadVehicles")
    missing := AdvisorQuoteStatusValue(status, "missingExpectedVehicles")
    if (expectedCount > 0 && matchedExpectedCount < expectedCount) {
        failureReason := "MISSING_EXPECTED_CONFIRMED_VEHICLES: " missing
        return false
    }
    if (expectedCount = 0 && unresolved != "") {
        failureReason := "Lead vehicles have no usable year, so public-record vehicles cannot be auto-confirmed: " unresolved
        return false
    }
    if (unresolved != "")
        AdvisorQuoteAppendLog("GATHER_UNRESOLVED_LEAD_VEHICLES", AdvisorQuoteGetLastStep(), "vehicles=" unresolved)
    return true
}

AdvisorQuoteVehicleAlreadyListed(vehicle) {
    args := AdvisorQuoteBuildVehicleJsArgs(vehicle, true)
    return AdvisorQuoteRunOp("vehicle_already_listed", args) = "1"
}

AdvisorQuoteConfirmPotentialVehicle(vehicle, db, &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    args := AdvisorQuoteBuildVehicleJsArgs(vehicle, true)
    status := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("confirm_potential_vehicle", args))
    result := AdvisorQuoteStatusValue(status, "result")
    cardText := AdvisorQuoteStatusValue(status, "cardText")
    matches := AdvisorQuoteStatusValue(status, "matches")
    score := AdvisorQuoteStatusValue(status, "score")
    candidateScope := AdvisorQuoteStatusValue(status, "candidateScope")
    rejectedReason := AdvisorQuoteStatusValue(status, "rejectedReason")
    confirmClicked := AdvisorQuoteStatusValue(status, "confirmClicked")

    switch result {
        case "", "NO_MATCH":
            if (rejectedReason != "") {
                AdvisorQuoteAppendLog(
                    "VEHICLE_POTENTIAL_REJECTED",
                    AdvisorQuoteGetLastStep(),
                    "vehicle=" vehicle["displayKey"]
                        . ", candidateScope=" candidateScope
                        . ", rejectedReason=" rejectedReason
                        . ", confirmButtonCount=" AdvisorQuoteStatusValue(status, "confirmButtonCount")
                        . ", vehicleTitleCount=" AdvisorQuoteStatusValue(status, "vehicleTitleCount")
                        . ", matchedCardText=" AdvisorQuoteStatusValue(status, "matchedCardText")
                )
            }
            return "NO_MATCH"
        case "SKIP_MISSING_YEAR":
            AdvisorQuoteAppendLog("VEHICLE_POTENTIAL_SKIP", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", reason=lead-vehicle-year-missing")
            return "NO_MATCH"
        case "CONFIRMED":
            AdvisorQuoteAppendLog(
                "VEHICLE_POTENTIAL_CONFIRM",
                AdvisorQuoteGetLastStep(),
                "year=" vehicle["year"]
                    . ", make=" vehicle["make"]
                    . ", model=" vehicle["model"]
                    . ", matches=" matches
                    . ", score=" score
                    . ", candidateScope=" candidateScope
                    . ", confirmClicked=" confirmClicked
                    . ", cardText=" cardText
            )
            postConfirmStatus := AdvisorQuoteWaitForGatherVehicleConfirmedStatus(vehicle, db)
            AdvisorQuoteLogGatherVehicleAddStatus(postConfirmStatus, "VEHICLE_POST_CONFIRM_STATUS", vehicle)
            AdvisorQuoteAppendLog(
                "VEHICLE_POST_CONFIRM_DECISION",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"]
                    . ", postConfirmStatus=" AdvisorQuoteStatusValue(postConfirmStatus, "result")
                    . ", alreadyConfirmed=" (AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(postConfirmStatus) ? "1" : "0")
                    . ", confirmedVehicleMatched=" AdvisorQuoteStatusValue(postConfirmStatus, "confirmedVehicleMatched")
                    . ", confirmedStatusMatched=" AdvisorQuoteStatusValue(postConfirmStatus, "confirmedStatusMatched")
                    . ", matchedText=" AdvisorQuoteStatusValue(postConfirmStatus, "matchedText")
            )
            if !AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(postConfirmStatus) {
                editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &failureReason, &failureScanPath, "post-confirm")
                if (editOutcome = "CONFIRMED")
                    return "CONFIRMED"
                if (editOutcome = "FAILED")
                    return "FAILED"
                failureReason := "Potential vehicle confirmation did not become a confirmed vehicle card for " vehicle["displayKey"] "."
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-confirm-status-timeout")
                return "FAILED"
            }
            return "CONFIRMED"
        case "AMBIGUOUS":
            AdvisorQuoteAppendLog(
                "VEHICLE_POTENTIAL_AMBIGUOUS",
                AdvisorQuoteGetLastStep(),
                "year=" vehicle["year"]
                    . ", make=" vehicle["make"]
                    . ", model=" vehicle["model"]
                    . ", matches=" matches
                    . ", candidateScope=" candidateScope
                    . ", rejectedReason=" rejectedReason
                    . ", cards=" AdvisorQuoteStatusValue(status, "cards")
            )
            return "AMBIGUOUS"
        case "CLICK_FAILED":
            failureReason := "Could not confirm matching potential vehicle for " vehicle["displayKey"] "."
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-confirm-click-failed")
            return "FAILED"
        default:
            failureReason := "Unexpected potential vehicle match result: " result
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-confirm-unexpected")
            return "FAILED"
    }
}

AdvisorQuoteBuildDbResolvedVehicleJsArgs(vehicle, resolvedVehicle) {
    args := AdvisorQuoteBuildVehicleJsArgs(vehicle)
    if IsObject(resolvedVehicle) {
        dbArgs := AdvisorVehicleDbBuildJsVehicleArgs(resolvedVehicle)
        for key, value in dbArgs
            args[key] := value
    }
    args["strictModelMatch"] := "1"
    return args
}

AdvisorQuoteResolvedListFirst(resolvedVehicle, key, fallback := "") {
    if (IsObject(resolvedVehicle) && resolvedVehicle.Has(key) && IsObject(resolvedVehicle[key])) {
        for _, value in resolvedVehicle[key] {
            text := Trim(String(value))
            if (text != "")
                return text
        }
    }
    return Trim(String(fallback))
}

AdvisorQuotePreferredDbMakeLabel(resolvedVehicle, fallback := "") {
    if (IsObject(resolvedVehicle) && resolvedVehicle.Has("advisorMakeLabels") && IsObject(resolvedVehicle["advisorMakeLabels"])) {
        possibleText := ""
        if (resolvedVehicle.Has("possibleMatches") && IsObject(resolvedVehicle["possibleMatches"]))
            possibleText := AdvisorVehicleNormalizeText(JoinArray(resolvedVehicle["possibleMatches"], " "))
        if (possibleText != "") {
            for _, label in resolvedVehicle["advisorMakeLabels"] {
                labelText := Trim(String(label))
                if (labelText != "" && RegExMatch(labelText, "i)\b(TRUCKS|VANS)\b") && InStr(possibleText, AdvisorVehicleNormalizeText(labelText)))
                    return labelText
            }
            for _, label in resolvedVehicle["advisorMakeLabels"] {
                labelText := Trim(String(label))
                if (labelText != "" && InStr(possibleText, AdvisorVehicleNormalizeText(labelText)))
                    return labelText
            }
        }
    }
    return AdvisorQuoteResolvedListFirst(resolvedVehicle, "advisorMakeLabels", fallback)
}

AdvisorQuoteVehicleOptionSummaryList(optionSummary) {
    options := []
    for _, optionText in StrSplit(String(optionSummary ?? ""), "|") {
        text := Trim(optionText)
        if (text != "")
            options.Push(text)
    }
    return options
}

AdvisorQuoteSelectDbAddSubModelIfRequired(index, vehicle, resolvedVehicle, db) {
    AdvisorQuoteWaitForVehicleSelectEnabled(index, "SubModel", db["timeouts"]["shortMs"], 1)
    rowStatus := AdvisorQuoteGetGatherVehicleRowStatus(index, vehicle["year"])
    AdvisorQuoteLogGatherVehicleRowStatus(rowStatus, "VEHICLE_DB_ADD_SUBMODEL_STATUS", vehicle)
    if (AdvisorQuoteStatusValue(rowStatus, "hasSubModel") != "1")
        return "OK"
    if (Trim(String(AdvisorQuoteStatusValue(rowStatus, "subModelValue"))) != "")
        return "OK"

    subModelOptions := AdvisorQuoteVehicleOptionSummaryList(AdvisorQuoteStatusValue(rowStatus, "subModelOptions"))
    if (subModelOptions.Length = 0)
        return "NO_OPTIONS"

    optionArgs := AdvisorQuoteBuildDbResolvedVehicleJsArgs(vehicle, resolvedVehicle)
    trimHint := IsObject(vehicle) && vehicle.Has("trimHint") ? Trim(String(vehicle["trimHint"])) : ""
    if (trimHint != "")
        return AdvisorQuoteSelectVehicleDropdownOptionResult(index, "SubModel", trimHint, false, vehicle, optionArgs)

    if (subModelOptions.Length = 1)
        return AdvisorQuoteSelectVehicleDropdownOptionResult(index, "SubModel", subModelOptions[1], false, vehicle, optionArgs)

    if AdvisorQuoteRapportSubModelPlaceholderFallbackEnabled(db) {
        fallbackStatus := AdvisorQuoteSelectVehicleDropdownFirstValidNonPlaceholder(index, "SubModel", vehicle)
        if (AdvisorQuoteStatusValue(fallbackStatus, "result") = "OK") {
            AdvisorQuoteAppendLog(
                "RAPPORT_VEHICLE_ADDED_SUBMODEL_PLACEHOLDER",
                AdvisorQuoteGetLastStep(),
                "vehicle=" AdvisorQuoteVehicleLabel(vehicle)
                    . ", fallbackMode=" AdvisorQuoteRapportSubModelFallbackMode(db)
                    . ", selectedValuePresent=" AdvisorQuoteStatusValue(fallbackStatus, "selectedValuePresent")
                    . ", optionCount=" AdvisorQuoteStatusValue(fallbackStatus, "optionCount")
            )
            return "OK"
        }
        return AdvisorQuoteStatusValue(fallbackStatus, "result")
    }

    return "AMBIGUOUS"
}

AdvisorQuoteAddCompleteDbResolvedVehicle(vehicle, resolvedVehicle, db, &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    if !AdvisorQuoteCompleteDbResolvedVehicleAddEligible(vehicle, resolvedVehicle, "match-existing-then-add-complete") {
        AdvisorQuoteAppendLog(
            "VEHICLE_DEFERRED_DB_ADD_UNSAFE",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"] ", reason=not-complete-db-resolved, " AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle)
        )
        return "DEFERRED"
    }

    AdvisorQuoteAppendLog(
        "VEHICLE_DB_ADD_ATTEMPT",
        AdvisorQuoteGetLastStep(),
        "vehicle=" vehicle["displayKey"] ", " AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle)
    )
    preAddStatus := AdvisorQuoteGetGatherVehicleAddStatus(vehicle)
    AdvisorQuoteLogGatherVehicleAddStatus(preAddStatus, "VEHICLE_DB_ADD_PREFLIGHT_STATUS", vehicle)
    if AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(preAddStatus) {
        AdvisorQuoteAppendLog(
            "VEHICLE_DB_ADD_COMMITTED",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"] ", method=already-confirmed-before-add, matchedText=" AdvisorQuoteStatusValue(preAddStatus, "matchedText")
        )
        return "ADDED"
    }

    AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus("", vehicle["year"]), "VEHICLE_ROW_STATUS_BEFORE_DB_ADD_PREPARE", vehicle)
    idx := AdvisorQuotePrepareVehicleRow(vehicle["year"])
    if (idx < 0) {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus("", vehicle["year"]), "VEHICLE_ROW_PREPARE_FAILED", vehicle)
        AdvisorQuoteAppendLog("VEHICLE_DEFERRED_DB_ADD_UNSAFE", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", reason=prepare-row-failed")
        return "DEFERRED"
    }

    yearCascadeStatus := AdvisorQuoteSetVehicleYearAndWaitManufacturer(idx, vehicle["year"], db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"])
    AdvisorQuoteLogVehicleYearCascadeStatus(yearCascadeStatus, "VEHICLE_YEAR_CASCADE", vehicle)
    if (AdvisorQuoteStatusValue(yearCascadeStatus, "yearVerified") != "1") {
        AdvisorQuoteAppendLog("VEHICLE_DEFERRED_DB_ADD_UNSAFE", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", reason=year-not-verified")
        return "DEFERRED"
    }
    AdvisorQuoteAppendLog(
        "VEHICLE_DB_ADD_SELECTED_YEAR",
        AdvisorQuoteGetLastStep(),
        "vehicle=" vehicle["displayKey"]
            . ", year=" vehicle["year"]
            . ", yearValue=" AdvisorQuoteStatusValue(yearCascadeStatus, "yearValue")
            . ", method=" AdvisorQuoteStatusValue(yearCascadeStatus, "method")
    )

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Manufacturer", db["timeouts"]["transitionMs"], 2) {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_MAKE_OPTIONS_TIMEOUT", vehicle)
        AdvisorQuoteAppendLog("VEHICLE_DEFERRED_DB_ADD_UNSAFE", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", reason=make-options-timeout")
        return "DEFERRED"
    }

    optionArgs := AdvisorQuoteBuildDbResolvedVehicleJsArgs(vehicle, resolvedVehicle)
    makeWanted := AdvisorQuotePreferredDbMakeLabel(resolvedVehicle, vehicle["make"])
    makeResult := AdvisorQuoteSelectVehicleDropdownOptionResult(idx, "Manufacturer", makeWanted, false, vehicle, optionArgs)
    if (makeResult != "OK") {
        AdvisorQuoteAppendLog(
            "VEHICLE_DEFERRED_DB_ADD_UNSAFE",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"] ", reason=make-option-" makeResult ", allowedMakeLabels=" AdvisorQuoteStatusValue(optionArgs, "allowedMakeLabels")
        )
        return "DEFERRED"
    }
    AdvisorQuoteAppendLog(
        "VEHICLE_DB_ADD_SELECTED_MAKE",
        AdvisorQuoteGetLastStep(),
        "vehicle=" vehicle["displayKey"] ", wanted=" makeWanted ", allowedMakeLabels=" AdvisorQuoteStatusValue(optionArgs, "allowedMakeLabels")
    )

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Model", db["timeouts"]["transitionMs"], 2) {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_MODEL_OPTIONS_TIMEOUT", vehicle)
        AdvisorQuoteAppendLog("VEHICLE_DEFERRED_DB_MODEL_OPTION_NOT_FOUND", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", reason=model-options-timeout")
        return "DEFERRED"
    }

    modelWanted := AdvisorQuoteResolvedListFirst(resolvedVehicle, "modelAliases", vehicle["model"])
    modelResult := AdvisorQuoteSelectVehicleDropdownOptionResult(idx, "Model", modelWanted, false, vehicle, optionArgs)
    switch modelResult {
        case "OK":
            AdvisorQuoteAppendLog(
                "VEHICLE_DB_ADD_SELECTED_MODEL",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", wanted=" modelWanted ", modelAliases=" AdvisorQuoteStatusValue(optionArgs, "modelAliases") ", normalizedModelKeys=" AdvisorQuoteStatusValue(optionArgs, "normalizedModelKeys")
            )
        case "AMBIGUOUS":
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_DB_MODEL_OPTION_AMBIGUOUS",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", wanted=" modelWanted ", modelAliases=" AdvisorQuoteStatusValue(optionArgs, "modelAliases") ", normalizedModelKeys=" AdvisorQuoteStatusValue(optionArgs, "normalizedModelKeys")
            )
            return "DEFERRED"
        case "NO_OPTION":
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_DB_MODEL_OPTION_NOT_FOUND",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", wanted=" modelWanted ", modelAliases=" AdvisorQuoteStatusValue(optionArgs, "modelAliases") ", normalizedModelKeys=" AdvisorQuoteStatusValue(optionArgs, "normalizedModelKeys")
            )
            return "DEFERRED"
        default:
            AdvisorQuoteAppendLog("VEHICLE_DEFERRED_DB_ADD_UNSAFE", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", reason=model-option-" modelResult)
            return "DEFERRED"
    }

    subModelResult := AdvisorQuoteSelectDbAddSubModelIfRequired(idx, vehicle, resolvedVehicle, db)
    if (subModelResult != "OK") {
        AdvisorQuoteAppendLog(
            "VEHICLE_DEFERRED_DB_SUBMODEL_AMBIGUOUS",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"] ", result=" subModelResult
        )
        return "DEFERRED"
    }

    readyStatus := AdvisorQuoteGetGatherVehicleAddStatus(vehicle, idx)
    AdvisorQuoteLogGatherVehicleAddStatus(readyStatus, "VEHICLE_DB_ADD_READY_STATUS", vehicle)
    if (AdvisorQuoteStatusValue(readyStatus, "rowComplete") != "1") {
        AdvisorQuoteAppendLog(
            "VEHICLE_DEFERRED_DB_ADD_UNSAFE",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"] ", reason=row-not-complete-after-db-selection, method=" AdvisorQuoteStatusValue(readyStatus, "method")
        )
        return "DEFERRED"
    }

    addStatus := AdvisorQuoteClickGatherAddRowAddButton(true)
    AdvisorQuoteAppendLog("RAPPORT_ADD_ROW_ADD_CLICKED", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherAddRowAddClickDetail(addStatus))
    if (AdvisorQuoteStatusValue(addStatus, "result") != "CLICKED" || AdvisorQuoteStatusValue(addStatus, "clicked") != "1") {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_ADD_CLICK_FAILED", vehicle)
        AdvisorQuoteAppendLog("VEHICLE_DEFERRED_DB_ADD_UNSAFE", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", reason=add-click-failed")
        return "DEFERRED"
    }

    postAddStatus := AdvisorQuoteWaitForGatherVehicleConfirmedStatus(vehicle, db, idx)
    AdvisorQuoteLogGatherVehicleAddStatus(postAddStatus, "VEHICLE_DB_ADD_STATUS_FINAL", vehicle)
    if AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(postAddStatus) {
        AdvisorQuoteAppendLog("VEHICLE_DB_ADD_COMMITTED", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", method=confirmed-card, matchedText=" AdvisorQuoteStatusValue(postAddStatus, "matchedText"))
        return "ADDED"
    }

    editFailureReason := ""
    editFailureScanPath := ""
    editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &editFailureReason, &editFailureScanPath, "db-add")
    AdvisorQuoteAppendLog("VEHICLE_DB_ADD_SUBMODEL_STATUS", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", editOutcome=" editOutcome ", editFailureReason=" editFailureReason)
    if (editOutcome = "CONFIRMED") {
        AdvisorQuoteAppendLog("VEHICLE_DB_ADD_COMMITTED", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", method=edit-vehicle-update")
        return "ADDED"
    }

    failureReason := "VEHICLE_DB_ADD_DID_NOT_COMMIT: Add Car/Truck did not produce a matching confirmed vehicle card for " vehicle["displayKey"] "."
    failureScanPath := (editFailureScanPath != "") ? editFailureScanPath : AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-db-add-did-not-commit")
    AdvisorQuoteAppendLog("VEHICLE_DB_ADD_DID_NOT_COMMIT", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", postAddResult=" AdvisorQuoteStatusValue(postAddStatus, "result") ", editOutcome=" editOutcome)
    return "FAILED"
}

AdvisorQuoteCloneVehicleWithModel(vehicle, model, statusLabel := "") {
    clone := Map()
    if IsObject(vehicle) {
        for key, value in vehicle
            clone[key] := value
    }
    clone["model"] := Trim(String(model))
    clone["displayKey"] := Trim(String(clone.Has("year") ? clone["year"] : "") "|" String(clone.Has("make") ? clone["make"] : "") "|" String(model), "|")
    if (statusLabel != "")
        clone["rapportLedgerStatus"] := statusLabel
    return clone
}

AdvisorQuoteAddPartialYearMakeVehicleWithModelFallback(vehicle, db, &addedVehicle := "", &failureReason := "", &failureScanPath := "") {
    addedVehicle := ""
    failureReason := ""
    failureScanPath := ""
    if !AdvisorQuoteRapportModelPlaceholderFallbackEnabled(db)
        return "SCRAP_MODEL_UNAVAILABLE"
    if !AdvisorQuoteVehicleHasPartialYearMakeFields(vehicle)
        return "FAILED_UNSAFE"

    AdvisorQuoteAppendLog(
        "RAPPORT_VEHICLE_LEDGER_NEXT_ACTION",
        AdvisorQuoteGetLastStep(),
        "vehicle=" AdvisorQuoteVehicleLabel(vehicle)
            . ", action=add_model_placeholder"
            . ", fallbackMode=" AdvisorQuoteRapportModelFallbackMode(db)
    )
    AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus("", vehicle["year"]), "VEHICLE_MODEL_PLACEHOLDER_ROW_STATUS_BEFORE_PREPARE", vehicle)
    idx := AdvisorQuotePrepareVehicleRow(vehicle["year"])
    if (idx < 0)
        return "FAILED_UNSAFE"

    yearCascadeStatus := AdvisorQuoteSetVehicleYearAndWaitManufacturer(idx, vehicle["year"], db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"])
    AdvisorQuoteLogVehicleYearCascadeStatus(yearCascadeStatus, "VEHICLE_MODEL_PLACEHOLDER_YEAR_CASCADE", vehicle)
    if (AdvisorQuoteStatusValue(yearCascadeStatus, "yearVerified") != "1")
        return "FAILED_UNSAFE"

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Manufacturer", db["timeouts"]["transitionMs"], 2)
        return "SCRAP_MAKE_UNAVAILABLE"

    makeArgs := Map("allowedMakeLabels", AdvisorVehicleAllowedMakeLabelsText(vehicle["make"], "", vehicle["year"]))
    makeResult := AdvisorQuoteSelectVehicleDropdownOptionResult(idx, "Manufacturer", vehicle["make"], false, vehicle, makeArgs)
    if (makeResult = "NO_OPTION")
        return "SCRAP_MAKE_UNAVAILABLE"
    if (makeResult != "OK")
        return "FAILED_UNSAFE"

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Model", db["timeouts"]["transitionMs"], 2)
        return "SCRAP_MODEL_UNAVAILABLE"

    modelStatus := AdvisorQuoteSelectVehicleDropdownFirstValidNonPlaceholder(idx, "Model", vehicle)
    if (AdvisorQuoteStatusValue(modelStatus, "result") = "NO_OPTIONS")
        return "SCRAP_MODEL_UNAVAILABLE"
    if (AdvisorQuoteStatusValue(modelStatus, "result") != "OK" || AdvisorQuoteStatusValue(modelStatus, "selectedValuePresent") != "1")
        return "FAILED_UNSAFE"

    selectedModel := AdvisorQuoteStatusValue(modelStatus, "selectedValue")
    addedVehicle := AdvisorQuoteCloneVehicleWithModel(vehicle, selectedModel, "MODEL_PLACEHOLDER_FALLBACK")
    AdvisorQuoteAppendLog(
        "RAPPORT_VEHICLE_ADDED_MODEL_PLACEHOLDER",
        AdvisorQuoteGetLastStep(),
        "vehicle=" AdvisorQuoteVehicleLabel(addedVehicle)
            . ", sourceVehicle=" AdvisorQuoteVehicleLabel(vehicle)
            . ", fallbackMode=" AdvisorQuoteRapportModelFallbackMode(db)
            . ", selectedModelPresent=1"
            . ", optionCount=" AdvisorQuoteStatusValue(modelStatus, "optionCount")
    )

    AdvisorQuoteWaitForVehicleSelectEnabled(idx, "SubModel", db["timeouts"]["shortMs"], 1)
    rowStatus := AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"])
    AdvisorQuoteLogGatherVehicleRowStatus(rowStatus, "VEHICLE_MODEL_PLACEHOLDER_SUBMODEL_STATUS", addedVehicle)
    if (AdvisorQuoteStatusValue(rowStatus, "hasSubModel") = "1" && AdvisorQuoteStatusValue(rowStatus, "subModelValue") = "") {
        subModelStatus := AdvisorQuoteSelectVehicleDropdownFirstValidNonPlaceholder(idx, "SubModel", addedVehicle)
        if (AdvisorQuoteStatusValue(subModelStatus, "result") != "OK")
            return "FAILED_UNSAFE"
        AdvisorQuoteAppendLog(
            "RAPPORT_VEHICLE_ADDED_SUBMODEL_PLACEHOLDER",
            AdvisorQuoteGetLastStep(),
            "vehicle=" AdvisorQuoteVehicleLabel(addedVehicle)
                . ", fallbackMode=" AdvisorQuoteRapportSubModelFallbackMode(db)
                . ", selectedValuePresent=" AdvisorQuoteStatusValue(subModelStatus, "selectedValuePresent")
                . ", optionCount=" AdvisorQuoteStatusValue(subModelStatus, "optionCount")
        )
    }

    readyStatus := AdvisorQuoteGetGatherVehicleAddStatus(addedVehicle, idx)
    AdvisorQuoteLogGatherVehicleAddStatus(readyStatus, "VEHICLE_MODEL_PLACEHOLDER_READY_STATUS", addedVehicle)
    if (AdvisorQuoteStatusValue(readyStatus, "rowComplete") != "1")
        return "FAILED_UNSAFE"

    addStatus := AdvisorQuoteClickGatherAddRowAddButton(true)
    AdvisorQuoteAppendLog("RAPPORT_ADD_ROW_ADD_CLICKED", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherAddRowAddClickDetail(addStatus))
    if (AdvisorQuoteStatusValue(addStatus, "result") != "CLICKED" || AdvisorQuoteStatusValue(addStatus, "clicked") != "1")
        return "FAILED_UNSAFE"

    postAddStatus := AdvisorQuoteWaitForGatherVehicleConfirmedStatus(addedVehicle, db, idx)
    AdvisorQuoteLogGatherVehicleAddStatus(postAddStatus, "VEHICLE_MODEL_PLACEHOLDER_STATUS_FINAL", addedVehicle)
    if AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(postAddStatus)
        return "ADDED"

    editFailureReason := ""
    editFailureScanPath := ""
    editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(addedVehicle, db, &editFailureReason, &editFailureScanPath, "model-placeholder-add")
    if (editOutcome = "CONFIRMED")
        return "ADDED"
    if (editOutcome = "FAILED") {
        failureReason := editFailureReason
        failureScanPath := editFailureScanPath
        return "FAILED_UNSAFE"
    }

    return "FAILED_UNSAFE"
}

AdvisorQuoteAddVehicleInGatherData(vehicle, db) {
    AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus("", vehicle["year"]), "VEHICLE_ROW_STATUS_BEFORE_PREPARE", vehicle)
    idx := AdvisorQuotePrepareVehicleRow(vehicle["year"])
    if (idx < 0) {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus("", vehicle["year"]), "VEHICLE_ROW_PREPARE_FAILED", vehicle)
        return false
    }

    status := AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"])
    AdvisorQuoteLogGatherVehicleRowStatus(status, "VEHICLE_ROW_STATUS_AFTER_PREPARE", vehicle)

    if (AdvisorQuoteStatusValue(status, "hasVehicleType") = "1" && Trim(String(AdvisorQuoteStatusValue(status, "vehicleTypeValue"))) = "") {
        typeResult := AdvisorQuoteSelectVehicleDropdownOptionRaw(idx, "VehTypeCd", "Car or Truck", true)
        AdvisorQuoteAppendLog("VEHICLE_DROPDOWN_SELECT", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", field=VehTypeCd, wanted=Car or Truck, result=" typeResult)
        if (typeResult != "OK") {
            AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_TYPE_SELECT_FAILED", vehicle)
            return false
        }
    }

    yearCascadeStatus := AdvisorQuoteSetVehicleYearAndWaitManufacturer(idx, vehicle["year"], db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"])
    AdvisorQuoteLogVehicleYearCascadeStatus(yearCascadeStatus, "VEHICLE_YEAR_CASCADE", vehicle)
    if (AdvisorQuoteStatusValue(yearCascadeStatus, "yearVerified") != "1") {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_YEAR_CASCADE_FAILED", vehicle)
        return false
    }

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Manufacturer", db["timeouts"]["transitionMs"], 2) {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_MAKE_OPTIONS_TIMEOUT", vehicle)
        return false
    }

    if !AdvisorQuoteSelectVehicleDropdownOption(idx, "Manufacturer", vehicle["make"], false, vehicle)
        return false

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Model", db["timeouts"]["transitionMs"], 2) {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_MODEL_OPTIONS_TIMEOUT", vehicle)
        return false
    }

    if !AdvisorQuoteSelectVehicleDropdownOption(idx, "Model", vehicle["model"], false, vehicle)
        return false

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "SubModel", db["timeouts"]["transitionMs"], 1) {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_SUBMODEL_OPTIONS_TIMEOUT", vehicle)
        return false
    }

    subModelResult := ""
    if (vehicle.Has("trimHint") && Trim(String(vehicle["trimHint"])) != "")
        subModelResult := AdvisorQuoteSelectVehicleDropdownOptionResult(idx, "SubModel", vehicle["trimHint"], false, vehicle)
    else {
        subModelStatus := AdvisorQuoteSelectVehicleDropdownFirstValidNonPlaceholder(idx, "SubModel", vehicle)
        subModelResult := AdvisorQuoteStatusValue(subModelStatus, "result")
        if (subModelResult = "OK") {
            AdvisorQuoteAppendLog(
                "RAPPORT_VEHICLE_ADDED_SUBMODEL_PLACEHOLDER",
                AdvisorQuoteGetLastStep(),
                "vehicle=" AdvisorQuoteVehicleLabel(vehicle)
                    . ", fallbackMode=" AdvisorQuoteRapportSubModelFallbackMode(db)
                    . ", selectedValuePresent=" AdvisorQuoteStatusValue(subModelStatus, "selectedValuePresent")
                    . ", optionCount=" AdvisorQuoteStatusValue(subModelStatus, "optionCount")
            )
        }
    }
    if (subModelResult != "OK")
        return false

    addStatus := AdvisorQuoteClickGatherAddRowAddButton(true)
    AdvisorQuoteAppendLog("RAPPORT_ADD_ROW_ADD_CLICKED", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherAddRowAddClickDetail(addStatus))
    if (AdvisorQuoteStatusValue(addStatus, "result") != "CLICKED" || AdvisorQuoteStatusValue(addStatus, "clicked") != "1") {
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_ADD_CLICK_FAILED", vehicle)
        return false
    }

    waitArgs := AdvisorQuoteBuildVehicleJsArgs(vehicle)
    addStatus := AdvisorQuoteWaitForGatherVehicleAddStatus(vehicle, db, idx)
    AdvisorQuoteLogGatherVehicleAddStatus(addStatus, "VEHICLE_ADD_STATUS_FINAL", vehicle)
    if AdvisorQuoteGatherVehicleAddStatusComplete(addStatus)
        return true
    editFailureReason := ""
    editFailureScanPath := ""
    editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &editFailureReason, &editFailureScanPath, "post-add")
    if (editOutcome = "CONFIRMED")
        return true
    AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(idx, vehicle["year"]), "VEHICLE_ADD_VERIFY_FAILED", vehicle)
    return false
}

AdvisorQuotePrepareVehicleRow(year) {
    if (Trim(String(year)) = "")
        return -1
    result := AdvisorQuoteRunOp("prepare_vehicle_row", Map("year", year))
    if !RegExMatch(result, "^-?\d+$")
        return -1
    return Integer(result)
}

AdvisorQuoteWaitForVehicleSelectEnabled(index, fieldName, timeoutMs, minOptions := 1) {
    args := Map(
        "index", index,
        "fieldName", fieldName,
        "minOptions", minOptions
    )
    return AdvisorQuoteWaitForCondition("vehicle_select_enabled", timeoutMs, 300, args)
}

AdvisorQuoteSelectVehicleDropdownOptionRaw(index, fieldName, wantedText, allowFirstNonEmpty := false, extraArgs := "") {
    args := Map(
        "index", index,
        "fieldName", fieldName,
        "wantedText", wantedText,
        "allowFirstNonEmpty", allowFirstNonEmpty
    )
    if IsObject(extraArgs) {
        for key, value in extraArgs
            args[key] := value
    }
    return AdvisorQuoteRunOp("select_vehicle_dropdown_option", args)
}

AdvisorQuoteSelectVehicleDropdownOptionResult(index, fieldName, wantedText, allowFirstNonEmpty := false, vehicle := "", extraArgs := "") {
    result := AdvisorQuoteSelectVehicleDropdownOptionRaw(index, fieldName, wantedText, allowFirstNonEmpty, extraArgs)
    vehicleKey := IsObject(vehicle) && vehicle.Has("displayKey") ? vehicle["displayKey"] : ""
    AdvisorQuoteAppendLog("VEHICLE_DROPDOWN_SELECT", AdvisorQuoteGetLastStep(), "vehicle=" vehicleKey ", field=" fieldName ", wanted=" wantedText ", allowFirstNonEmpty=" (allowFirstNonEmpty ? "1" : "0") ", result=" result)
    if (result != "OK" && IsObject(vehicle))
        AdvisorQuoteLogGatherVehicleRowStatus(AdvisorQuoteGetGatherVehicleRowStatus(index, vehicle["year"]), "VEHICLE_DROPDOWN_SELECT_FAILED", vehicle)
    return result
}

AdvisorQuoteSelectVehicleDropdownOption(index, fieldName, wantedText, allowFirstNonEmpty := false, vehicle := "") {
    result := AdvisorQuoteSelectVehicleDropdownOptionResult(index, fieldName, wantedText, allowFirstNonEmpty, vehicle)
    return result = "OK"
}

AdvisorQuoteSelectVehicleDropdownFirstValidNonPlaceholder(index, fieldName, vehicle := "") {
    args := Map(
        "index", index,
        "fieldName", fieldName
    )
    status := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("select_vehicle_dropdown_first_valid_nonplaceholder", args))
    vehicleKey := IsObject(vehicle) && vehicle.Has("displayKey") ? vehicle["displayKey"] : ""
    AdvisorQuoteAppendLog(
        "VEHICLE_DROPDOWN_FIRST_VALID_SELECT",
        AdvisorQuoteGetLastStep(),
        "vehicle=" vehicleKey
            . ", field=" fieldName
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", selectedValue=" AdvisorQuoteStatusValue(status, "selectedValue")
            . ", selectedMode=" AdvisorQuoteStatusValue(status, "selectedMode")
            . ", optionCount=" AdvisorQuoteStatusValue(status, "optionCount")
    )
    return status
}

AdvisorQuoteGetGatherVehicleRowStatus(index := "", year := "") {
    args := Map()
    if (Trim(String(index)) != "")
        args["index"] := index
    if (Trim(String(year)) != "")
        args["year"] := year
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_vehicle_row_status", args))
}

AdvisorQuoteSetVehicleYearAndWaitManufacturer(index, year, timeoutMs, pollMs) {
    args := Map(
        "index", index,
        "year", year,
        "timeoutMs", timeoutMs,
        "pollMs", pollMs
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("set_vehicle_year_and_wait_manufacturer", args))
}

AdvisorQuoteGetGatherVehicleAddStatus(vehicle, index := "") {
    args := AdvisorQuoteBuildVehicleJsArgs(vehicle, true)
    if (Trim(String(index)) != "")
        args["index"] := index
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_vehicle_add_status", args))
}

AdvisorQuoteGetGatherPartialVehicleConfirmedStatus(vehicle, index := "") {
    args := AdvisorQuoteBuildVehicleJsArgs(vehicle, true)
    args["partialYearMakeMode"] := "1"
    if (Trim(String(index)) != "")
        args["index"] := index
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_vehicle_add_status", args))
}

AdvisorQuoteGetGatherVehicleEditStatus(vehicle := "") {
    args := IsObject(vehicle) ? AdvisorQuoteBuildVehicleJsArgs(vehicle) : Map()
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_vehicle_edit_status", args, 2, 120))
}

AdvisorQuoteHandleVehicleEditModal(vehicle) {
    args := AdvisorQuoteBuildVehicleJsArgs(vehicle)
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("handle_vehicle_edit_modal", args))
}

AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &failureReason := "", &failureScanPath := "", context := "") {
    failureReason := ""
    failureScanPath := ""
    Loop 2 {
        attemptContext := context "-attempt-" A_Index
        status := AdvisorQuoteGetGatherVehicleEditStatus(vehicle)
        AdvisorQuoteLogGatherVehicleEditStatus(status, "VEHICLE_EDIT_STATUS", vehicle, attemptContext)
        statusResult := AdvisorQuoteStatusValue(status, "result")
        if (statusResult = "" || statusResult = "NO_MODAL") {
            if (A_Index = 1)
                return "NO_MODAL"
            return "CONFIRMED"
        }

        resultStatus := AdvisorQuoteHandleVehicleEditModal(vehicle)
        AdvisorQuoteLogGatherVehicleEditStatus(resultStatus, "VEHICLE_EDIT_RESULT", vehicle, attemptContext)
        result := AdvisorQuoteStatusValue(resultStatus, "result")
        switch result {
            case "UPDATED":
                postUpdateStatus := AdvisorQuoteWaitForGatherVehicleConfirmedStatus(vehicle, db)
                AdvisorQuoteLogGatherVehicleAddStatus(postUpdateStatus, "VEHICLE_EDIT_POST_UPDATE_STATUS", vehicle)
                if AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(postUpdateStatus)
                    return "CONFIRMED"
                afterEditStatus := AdvisorQuoteGetGatherVehicleEditStatus(vehicle)
                AdvisorQuoteLogGatherVehicleEditStatus(afterEditStatus, "VEHICLE_EDIT_AFTER_UPDATE_STATUS", vehicle, attemptContext)
                if (AdvisorQuoteStatusValue(afterEditStatus, "result") = "NO_MODAL")
                    return "CONFIRMED"
                if (A_Index < 2)
                    continue
                failureReason := "VEHICLE_EDIT_UPDATE_DID_NOT_COMMIT: Update clicked but the Edit Vehicle panel stayed open and no matching confirmed vehicle card appeared for " vehicle["displayKey"] "."
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-edit-update-did-not-commit")
                return "FAILED"
            case "NO_ACTION_NEEDED", "NO_MODAL":
                if (statusResult = "UPDATE_REQUIRED_READY") {
                    failureReason := "VEHICLE_EDIT_UPDATE_DID_NOT_COMMIT: Edit Vehicle panel is complete and Update is enabled but no Update click occurred for " vehicle["displayKey"] "."
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-edit-update-ready-no-click")
                    return "FAILED"
                }
                return "NO_ACTION"
            case "NO_SUBMODEL_OPTIONS":
                failureReason := "VEHICLE_SUBMODEL_REQUIRED_UNRESOLVED: Sub-Model is required but no valid Sub-Model options were available for " vehicle["displayKey"] "."
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-edit-no-submodel-options")
                return "FAILED"
            default:
                failureReason := "VEHICLE_SUBMODEL_REQUIRED_UNRESOLVED: Could not complete Edit Vehicle Sub-Model for " vehicle["displayKey"] "."
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-edit-submodel-failed")
                return "FAILED"
        }
    }
    failureReason := "VEHICLE_EDIT_UPDATE_DID_NOT_COMMIT: Edit Vehicle update loop exceeded the two-attempt guard for " vehicle["displayKey"] "."
    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-edit-update-loop-guard")
    return "FAILED"
}

AdvisorQuoteGatherVehicleAddStatusComplete(status) {
    result := AdvisorQuoteStatusValue(status, "result")
    if (result = "ADDED")
        return true
    return result = "READY_ROW" && AdvisorQuoteStatusValue(status, "warningStillPresent") != "1"
}

AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(status) {
    return AdvisorQuoteStatusValue(status, "result") = "ADDED"
        && AdvisorQuoteStatusValue(status, "confirmedVehicleMatched") = "1"
        && AdvisorQuoteStatusValue(status, "confirmedStatusMatched") = "1"
        && AdvisorQuoteStatusValue(status, "yearMatched") = "1"
        && AdvisorQuoteStatusValue(status, "makeMatched") = "1"
        && AdvisorQuoteStatusValue(status, "modelMatched") = "1"
}

AdvisorQuoteGatherVehiclePartialStatusPromoted(status) {
    return AdvisorQuoteStatusValue(status, "result") = "ADDED"
        && AdvisorQuoteStatusValue(status, "partialPromoted") = "1"
        && AdvisorQuoteStatusValue(status, "confirmedVehicleMatched") = "1"
        && AdvisorQuoteStatusValue(status, "confirmedStatusMatched") = "1"
        && AdvisorQuoteStatusValue(status, "yearMatched") = "1"
        && AdvisorQuoteStatusValue(status, "makeMatched") = "1"
        && AdvisorQuoteStatusValue(status, "modelMatched") = "1"
        && AdvisorQuoteStatusValue(status, "promotedVinEvidence") = "1"
        && Trim(String(AdvisorQuoteStatusValue(status, "promotedModel"))) != ""
}

AdvisorQuoteBuildGatherPromotedPartialVehicle(vehicle, status) {
    year := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
    make := IsObject(vehicle) && vehicle.Has("make") ? Trim(String(vehicle["make"])) : ""
    promotedModel := Trim(String(AdvisorQuoteStatusValue(status, "promotedModel")))
    raw := IsObject(vehicle) && vehicle.Has("raw") ? Trim(String(vehicle["raw"])) : ""
    if (raw = "")
        raw := Trim(year " " make)
    return Map(
        "year", year,
        "make", make,
        "model", promotedModel,
        "trimHint", "",
        "vin", "",
        "vinSuffix", "",
        "raw", raw,
        "displayKey", AdvisorBuildVehicleDisplayKey(year, make, promotedModel),
        "originalLeadText", raw,
        "promotedFromPartial", "1",
        "promotionSource", AdvisorQuoteStatusValue(status, "promotionSource"),
        "promotedVehicleText", AdvisorQuoteStatusValue(status, "promotedVehicleText"),
        "promotedVinEvidence", AdvisorQuoteStatusValue(status, "promotedVinEvidence")
    )
}

AdvisorQuoteGatherVehicleDuplicateAddRowOpen(status) {
    return AdvisorQuoteStatusValue(status, "duplicateAddRowOpenForConfirmedVehicle") = "1"
}

AdvisorQuoteWaitForGatherVehicleAddStatus(vehicle, db, index := "") {
    start := A_TickCount
    timeoutMs := db["timeouts"]["transitionMs"]
    pollMs := db["timeouts"]["pollMs"]
    lastStatus := Map()
    emptyCount := 0
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return lastStatus
        status := AdvisorQuoteGetGatherVehicleAddStatus(vehicle, index)
        if !IsObject(status) || status.Count = 0 {
            emptyCount += 1
            AdvisorQuoteAppendLog("VEHICLE_ADD_STATUS_EMPTY", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", emptyCount=" emptyCount)
            if (emptyCount >= 3)
                return status
        } else {
            lastStatus := status
            AdvisorQuoteLogGatherVehicleAddStatus(status, "VEHICLE_ADD_STATUS", vehicle)
            result := AdvisorQuoteStatusValue(status, "result")
            if AdvisorQuoteGatherVehicleAddStatusComplete(status)
                return status
            if (result = "FAILED" || result = "MISSING")
                return status
        }
        if !SafeSleep(pollMs)
            return lastStatus
    }
    return lastStatus
}

AdvisorQuoteWaitForGatherVehicleConfirmedStatus(vehicle, db, index := "") {
    start := A_TickCount
    timeoutMs := db["timeouts"]["transitionMs"]
    pollMs := db["timeouts"]["pollMs"]
    lastStatus := Map()
    emptyCount := 0
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return lastStatus
        status := AdvisorQuoteGetGatherVehicleAddStatus(vehicle, index)
        if !IsObject(status) || status.Count = 0 {
            emptyCount += 1
            AdvisorQuoteAppendLog("VEHICLE_CONFIRMED_STATUS_EMPTY", AdvisorQuoteGetLastStep(), "vehicle=" vehicle["displayKey"] ", emptyCount=" emptyCount)
            if (emptyCount >= 3)
                return status
        } else {
            lastStatus := status
            AdvisorQuoteLogGatherVehicleAddStatus(status, "VEHICLE_CONFIRMED_STATUS", vehicle)
            result := AdvisorQuoteStatusValue(status, "result")
            if AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(status)
                return status
            if (result = "FAILED" || result = "MISSING")
                return status
        }
        if !SafeSleep(pollMs)
            return lastStatus
    }
    return lastStatus
}

AdvisorQuoteLogGatherVehicleAddStatus(status, eventType, vehicle := "") {
    vehicleKey := IsObject(vehicle) && vehicle.Has("displayKey") ? vehicle["displayKey"] : ""
    AdvisorQuoteAppendLog(
        eventType,
        AdvisorQuoteGetLastStep(),
        "vehicle=" vehicleKey
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", vehicleMatched=" AdvisorQuoteStatusValue(status, "vehicleMatched")
            . ", confirmedVehicleMatched=" AdvisorQuoteStatusValue(status, "confirmedVehicleMatched")
            . ", confirmedStatusMatched=" AdvisorQuoteStatusValue(status, "confirmedStatusMatched")
            . ", yearMatched=" AdvisorQuoteStatusValue(status, "yearMatched")
            . ", makeMatched=" AdvisorQuoteStatusValue(status, "makeMatched")
            . ", modelMatched=" AdvisorQuoteStatusValue(status, "modelMatched")
            . ", vinMatched=" AdvisorQuoteStatusValue(status, "vinMatched")
            . ", vinEvidence=" AdvisorQuoteStatusValue(status, "vinEvidence")
            . ", partialPromoted=" AdvisorQuoteStatusValue(status, "partialPromoted")
            . ", promotedModel=" AdvisorQuoteStatusValue(status, "promotedModel")
            . ", promotedVinEvidence=" AdvisorQuoteStatusValue(status, "promotedVinEvidence")
            . ", promotionSource=" AdvisorQuoteStatusValue(status, "promotionSource")
            . ", rowOpen=" AdvisorQuoteStatusValue(status, "rowOpen")
            . ", rowGone=" AdvisorQuoteStatusValue(status, "rowGone")
            . ", rowComplete=" AdvisorQuoteStatusValue(status, "rowComplete")
            . ", rowIncomplete=" AdvisorQuoteStatusValue(status, "rowIncomplete")
            . ", duplicateAddRowOpenForConfirmedVehicle=" AdvisorQuoteStatusValue(status, "duplicateAddRowOpenForConfirmedVehicle")
            . ", duplicateAddRowDetails=" AdvisorQuoteStatusValue(status, "duplicateAddRowDetails")
            . ", warningStillPresent=" AdvisorQuoteStatusValue(status, "warningStillPresent")
            . ", method=" AdvisorQuoteStatusValue(status, "method")
            . ", expectedModelKey=" AdvisorQuoteStatusValue(status, "expectedModelKey")
            . ", matchedText=" AdvisorQuoteStatusValue(status, "matchedText")
            . ", promotedVehicleText=" AdvisorQuoteStatusValue(status, "promotedVehicleText")
            . ", candidateCount=" AdvisorQuoteStatusValue(status, "candidateCount")
            . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
            . ", candidateTexts=" AdvisorQuoteStatusValue(status, "candidateTexts")
            . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
    )
}

AdvisorQuoteLogGatherVehicleEditStatus(status, eventType, vehicle := "", context := "") {
    vehicleKey := IsObject(vehicle) && vehicle.Has("displayKey") ? vehicle["displayKey"] : ""
    AdvisorQuoteAppendLog(
        eventType,
        AdvisorQuoteGetLastStep(),
        "context=" context
            . ", vehicle=" vehicleKey
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", method=" AdvisorQuoteStatusValue(status, "method")
            . ", vehicleText=" AdvisorQuoteStatusValue(status, "vehicleText")
            . ", yearValue=" AdvisorQuoteStatusValue(status, "yearValue")
            . ", vinValue=" AdvisorQuoteStatusValue(status, "vinValue")
            . ", manufacturerValue=" AdvisorQuoteStatusValue(status, "manufacturerValue")
            . ", modelValue=" AdvisorQuoteStatusValue(status, "modelValue")
            . ", subModelPresent=" AdvisorQuoteStatusValue(status, "subModelPresent")
            . ", subModelValue=" AdvisorQuoteStatusValue(status, "subModelValue")
            . ", subModelText=" AdvisorQuoteStatusValue(status, "subModelText")
            . ", subModelSelectedValue=" AdvisorQuoteStatusValue(status, "subModelSelectedValue")
            . ", subModelSelectedText=" AdvisorQuoteStatusValue(status, "subModelSelectedText")
            . ", subModelSelectionMethod=" AdvisorQuoteStatusValue(status, "subModelSelectionMethod")
            . ", subModelOptionCount=" AdvisorQuoteStatusValue(status, "subModelOptionCount")
            . ", updateButtonPresent=" AdvisorQuoteStatusValue(status, "updateButtonPresent")
            . ", updateButtonEnabled=" AdvisorQuoteStatusValue(status, "updateButtonEnabled")
            . ", updateClicked=" AdvisorQuoteStatusValue(status, "updateClicked")
            . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
            . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
            . ", missing=" AdvisorQuoteStatusValue(status, "missing")
            . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
    )
}

AdvisorQuoteLogVehicleYearCascadeStatus(status, eventType, vehicle := "") {
    vehicleKey := IsObject(vehicle) && vehicle.Has("displayKey") ? vehicle["displayKey"] : ""
    AdvisorQuoteAppendLog(
        eventType,
        AdvisorQuoteGetLastStep(),
        "vehicle=" vehicleKey
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", index=" AdvisorQuoteStatusValue(status, "index")
            . ", yearWanted=" AdvisorQuoteStatusValue(status, "yearWanted")
            . ", yearValue=" AdvisorQuoteStatusValue(status, "yearValue")
            . ", yearVerified=" AdvisorQuoteStatusValue(status, "yearVerified")
            . ", manufacturerEnabled=" AdvisorQuoteStatusValue(status, "manufacturerEnabled")
            . ", manufacturerOptionCount=" AdvisorQuoteStatusValue(status, "manufacturerOptionCount")
            . ", manufacturerOptions=" AdvisorQuoteStatusValue(status, "manufacturerOptions")
            . ", method=" AdvisorQuoteStatusValue(status, "method")
            . ", eventsFired=" AdvisorQuoteStatusValue(status, "eventsFired")
            . ", attempts=" AdvisorQuoteStatusValue(status, "attempts")
            . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
            . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
    )
}

AdvisorQuoteLogGatherVehicleRowStatus(status, eventType, vehicle := "") {
    vehicleKey := IsObject(vehicle) && vehicle.Has("displayKey") ? vehicle["displayKey"] : ""
    AdvisorQuoteAppendLog(
        eventType,
        AdvisorQuoteGetLastStep(),
        "vehicle=" vehicleKey
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
            . ", hasVehicleType=" AdvisorQuoteStatusValue(status, "hasVehicleType")
            . ", hasYear=" AdvisorQuoteStatusValue(status, "hasYear")
            . ", hasManufacturer=" AdvisorQuoteStatusValue(status, "hasManufacturer")
            . ", hasModel=" AdvisorQuoteStatusValue(status, "hasModel")
            . ", hasSubModel=" AdvisorQuoteStatusValue(status, "hasSubModel")
            . ", vehicleTypeValue=" AdvisorQuoteStatusValue(status, "vehicleTypeValue")
            . ", yearValue=" AdvisorQuoteStatusValue(status, "yearValue")
            . ", manufacturerValue=" AdvisorQuoteStatusValue(status, "manufacturerValue")
            . ", modelValue=" AdvisorQuoteStatusValue(status, "modelValue")
            . ", subModelValue=" AdvisorQuoteStatusValue(status, "subModelValue")
            . ", yearOptions=" AdvisorQuoteStatusValue(status, "yearOptions")
            . ", manufacturerOptions=" AdvisorQuoteStatusValue(status, "manufacturerOptions")
            . ", modelOptions=" AdvisorQuoteStatusValue(status, "modelOptions")
            . ", subModelOptions=" AdvisorQuoteStatusValue(status, "subModelOptions")
            . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
            . ", addButtonText=" AdvisorQuoteStatusValue(status, "addButtonText")
            . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
    )
}

AdvisorQuoteEnsureAutoStartQuotingState(db) {
    args := Map(
        "ratingState", db["defaults"]["ratingState"],
        "selectors", db["selectors"]
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("ensure_auto_start_quoting_state", args))
}

AdvisorQuoteEnsureStartQuotingAutoCheckbox() {
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("ensure_start_quoting_auto_checkbox", Map()))
}

AdvisorQuoteBuildStartQuotingAutoCheckboxDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", autoPresent=" AdvisorQuoteStatusValue(status, "autoPresent")
        . ", autoCheckedBefore=" AdvisorQuoteStatusValue(status, "autoCheckedBefore")
        . ", autoCheckedAfter=" AdvisorQuoteStatusValue(status, "autoCheckedAfter")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", directSetUsed=" AdvisorQuoteStatusValue(status, "directSetUsed")
        . ", method=" AdvisorQuoteStatusValue(status, "method")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
        . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
}

AdvisorQuoteClickCreateQuotesOrderReports(db) {
    return AdvisorQuoteRunOp("click_create_quotes_order_reports", Map("selectors", db["selectors"]), 1, 100)
}

AdvisorQuoteClickStartQuotingScopedAddProduct(db) {
    return AdvisorQuoteRunOp("click_start_quoting_add_product", Map("selectors", db["selectors"]), 1, 100)
}

AdvisorQuoteRunScopedStartQuotingAddProductHandoff(db, beforeStatus, handoffPath, &afterStatus, &afterReason := "", &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    afterStatus := beforeStatus
    afterReason := ""

    clickResult := AdvisorQuoteClickStartQuotingScopedAddProduct(db)
    AdvisorQuoteAppendLog(
        "GATHER_START_QUOTING_SCOPED_ADD_PRODUCT_HANDOFF",
        AdvisorQuoteGetLastStep(),
        "startQuotingHandoffPath=" handoffPath
            . ", startQuotingCreateQuotesEnabledBefore=" (AdvisorQuoteStartQuotingCreateQuotesEnabled(beforeStatus) ? "1" : "0")
            . ", startQuotingScopedAddProductPresent=" (AdvisorQuoteStartQuotingScopedAddProductPresent(beforeStatus) ? "1" : "0")
            . ", startQuotingScopedAddProductClicked=" (clickResult = "OK" ? "1" : "0")
            . ", startQuotingScopedAddProductResult=" clickResult
            . ", startQuotingScopedAddProductHandoff=1"
            . ", statusBefore=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(beforeStatus)
    )
    if (clickResult != "OK") {
        if (clickResult = "NO_BUTTON")
            failureReason := "START_QUOTING_SCOPED_ADD_PRODUCT_NOT_FOUND: scoped Start Quoting Add product link was not found."
        else if (clickResult = "DISABLED")
            failureReason := "START_QUOTING_SCOPED_ADD_PRODUCT_DISABLED: scoped Start Quoting Add product link is disabled."
        else
            failureReason := "START_QUOTING_SCOPED_ADD_PRODUCT_CLICK_FAILED: scoped Start Quoting Add product link could not be clicked."
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "start-quoting-scoped-add-product-click-failed")
        AdvisorQuoteAppendLog(
            "GATHER_START_QUOTING_HANDOFF_FAILED",
            AdvisorQuoteGetLastStep(),
            "startQuotingHandoffPath=failed, startQuotingScopedAddProductResult=" clickResult . ", failureReason=" failureReason
        )
        return false
    }

    if !AdvisorQuoteWaitForStartQuotingCreateQuotesEnabled(db, &afterStatus, &afterReason) {
        failureReason := "START_QUOTING_CREATE_QUOTES_DISABLED_AFTER_SCOPED_ADD_PRODUCT: " afterReason
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "start-quoting-create-quotes-still-disabled")
        AdvisorQuoteAppendLog(
            "GATHER_START_QUOTING_HANDOFF_FAILED",
            AdvisorQuoteGetLastStep(),
            "startQuotingHandoffPath=failed"
                . ", startQuotingScopedAddProductClicked=1"
                . ", startQuotingScopedAddProductResult=OK"
                . ", startQuotingCreateQuotesEnabledAfter=" (AdvisorQuoteStartQuotingCreateQuotesEnabled(afterStatus) ? "1" : "0")
                . ", failureReason=" failureReason
                . ", statusAfter=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(afterStatus)
                . ", scan=" failureScanPath
        )
        return false
    }

    AdvisorQuoteAppendLog(
        "GATHER_START_QUOTING_HANDOFF_READY",
        AdvisorQuoteGetLastStep(),
        "startQuotingHandoffPath=" handoffPath
            . ", startQuotingScopedAddProductClicked=1"
            . ", startQuotingScopedAddProductResult=OK"
            . ", startQuotingCreateQuotesEnabledAfter=1"
            . ", statusAfter=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(afterStatus)
    )
    return true
}

AdvisorQuoteWaitForStartQuotingCreateQuotesEnabled(db, &statusOut, &reasonOut := "") {
    start := A_TickCount
    timeoutMs := db["timeouts"]["transitionMs"]
    pollMs := db["timeouts"]["pollMs"]
    statusOut := Map()
    reasonOut := ""
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested() {
            reasonOut := "Stopped manually."
            return false
        }
        statusOut := AdvisorQuoteGetGatherStartQuotingStatus(db)
        AdvisorQuoteAppendLog(
            "GATHER_START_QUOTING_STATUS",
            AdvisorQuoteGetLastStep(),
            "phase=after-scoped-add-product, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(statusOut)
        )
        if AdvisorQuoteGatherStartQuotingStatusValid(statusOut, db, &reasonOut)
            return true
        Sleep(pollMs)
    }
    if (reasonOut = "")
        reasonOut := "Create Quotes & Order Reports did not become enabled after scoped Start Quoting Add product."
    return false
}

AdvisorQuoteClickProductOverviewSubnavFromRapport(db) {
    args := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("click_product_overview_subnav_from_rapport", args, 1, 160))
}

AdvisorQuoteRecoverProductTileAutoFromRapport(db, startQuotingStatus, startQuotingReason := "", &failureReason := "", &failureScanPath := "") {
    global advisorQuoteProductTileRecoveryAttempted, advisorQuoteGatherAutoCommitted
    failureReason := ""
    failureScanPath := ""

    if advisorQuoteProductTileRecoveryAttempted {
        if (AdvisorQuoteStatusValue(startQuotingStatus, "autoProductPresent") = "1")
            failureReason := "START_QUOTING_AUTO_STILL_UNCHECKED_AFTER_RECOVERY: Auto was still not selected in Gather Data after Product Tile recovery."
        else
            failureReason := "START_QUOTING_AUTO_STILL_MISSING_AFTER_RECOVERY: Auto was still missing in Gather Data after Product Tile recovery."
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "product-tile-recovery-already-used")
        AdvisorQuoteAppendLog(
            "PRODUCT_TILE_RECOVERY_SKIPPED",
            AdvisorQuoteGetLastStep(),
            "productRecoveryAttempted=1, productRecoveryResult=already-used, status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" failureScanPath
        )
        return false
    }

    advisorQuoteProductTileRecoveryAttempted := true
    advisorQuoteGatherAutoCommitted := false
    AdvisorQuoteAppendLog(
        "PRODUCT_TILE_RECOVERY_START",
        AdvisorQuoteGetLastStep(),
        "productRecoveryAttempted=1, GatherAutoCommitted=0, reason=" startQuotingReason . ", status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus)
    )

    clickStatus := AdvisorQuoteClickProductOverviewSubnavFromRapport(db)
    clickResult := AdvisorQuoteStatusValue(clickStatus, "result")
    AdvisorQuoteAppendLog(
        "PRODUCT_TILE_RECOVERY_SELECT_PRODUCT",
        AdvisorQuoteGetLastStep(),
        "productRecoveryUsedSelectProductSubnav=1, startHereClickResult=" clickResult
            . ", result=" clickResult
            . ", clicked=" AdvisorQuoteStatusValue(clickStatus, "clicked")
            . ", targetText=" AdvisorQuoteStatusValue(clickStatus, "targetText")
            . ", targetClass=" AdvisorQuoteStatusValue(clickStatus, "targetClass")
            . ", targetTag=" AdvisorQuoteStatusValue(clickStatus, "targetTag")
            . ", evidence=" AdvisorQuoteStatusValue(clickStatus, "evidence")
    )
    if (clickResult != "OK") {
        failureReason := (clickResult = "CLICK_FAILED")
            ? "PRODUCT_TILE_RECOVERY_SELECT_PRODUCT_TAB_NOT_FOUND: SELECT PRODUCT subnav was found but could not be clicked."
            : "PRODUCT_TILE_RECOVERY_SELECT_PRODUCT_TAB_NOT_FOUND: SELECT PRODUCT subnav was not found; sidebar Add Product fallback refused."
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "product-tile-recovery-select-product-failed")
        return false
    }

    overviewResult := AdvisorQuoteHandleProductOverview(db)
    if (overviewResult != "") {
        if (overviewResult = "OVERVIEW_NOT_READY")
            failureReason := "PRODUCT_TILE_RECOVERY_TO_OVERVIEW_TIMEOUT: SELECT PRODUCT did not return to Product Tile Grid."
        else if (overviewResult = "RAPPORT_TRANSITION_TIMEOUT")
            failureReason := "PRODUCT_TILE_RECOVERY_TO_RAPPORT_TIMEOUT: Product Tile Grid did not return to Gather Data after Save & Continue."
        else
            failureReason := "PRODUCT_TILE_RECOVERY_AUTO_VERIFY_FAILED: " overviewResult
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "product-tile-recovery-product-overview-failed")
        AdvisorQuoteAppendLog(
            "PRODUCT_TILE_RECOVERY_FAILED",
            AdvisorQuoteGetLastStep(),
            "productRecoveryResult=" overviewResult . ", failureReason=" failureReason . ", scan=" failureScanPath
        )
        return false
    }

    postStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
    AdvisorQuoteAppendLog(
        "PRODUCT_TILE_RECOVERY_GATHER_STATUS",
        AdvisorQuoteGetLastStep(),
        "phase=after-overview-save, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(postStatus)
    )
    postReason := ""
    postReady := AdvisorQuoteGatherStartQuotingStatusValid(postStatus, db, &postReason)
    if (!postReady && AdvisorQuoteStatusValue(postStatus, "hasStartQuotingText") = "1") {
        checkboxStatus := AdvisorQuoteEnsureStartQuotingAutoCheckbox()
        AdvisorQuoteAppendLog("PRODUCT_TILE_RECOVERY_AUTO_CHECKBOX", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildStartQuotingAutoCheckboxDetail(checkboxStatus))

        applyStatus := AdvisorQuoteEnsureAutoStartQuotingState(db)
        AdvisorQuoteAppendLog("PRODUCT_TILE_RECOVERY_AUTO_SET", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingApplyDetail(applyStatus))

        postStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
        AdvisorQuoteAppendLog(
            "PRODUCT_TILE_RECOVERY_GATHER_STATUS",
            AdvisorQuoteGetLastStep(),
            "phase=after-auto-ensure, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(postStatus)
        )
        postReady := AdvisorQuoteGatherStartQuotingStatusValid(postStatus, db, &postReason)
    }

    if postReady {
        advisorQuoteGatherAutoCommitted := true
        AdvisorQuoteAppendLog(
            "PRODUCT_TILE_RECOVERY_DONE",
            AdvisorQuoteGetLastStep(),
            "productRecoveryResult=OK, GatherAutoCommitted=1, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(postStatus)
        )
        return true
    }

    if (AdvisorQuoteStatusValue(postStatus, "autoProductPresent") != "1")
        failureReason := "START_QUOTING_AUTO_STILL_MISSING_AFTER_RECOVERY: Auto is still missing after Product Tile recovery."
    else if !AdvisorQuoteGatherStartQuotingAutoSelected(postStatus)
        failureReason := "START_QUOTING_AUTO_STILL_UNCHECKED_AFTER_RECOVERY: Auto is still unchecked after Product Tile recovery."
    else
        failureReason := AdvisorQuoteStartQuotingFailureCode(postStatus, postReason)
    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "product-tile-recovery-still-not-ready")
    AdvisorQuoteAppendLog(
        "PRODUCT_TILE_RECOVERY_FAILED",
        AdvisorQuoteGetLastStep(),
        "productRecoveryResult=not-ready, failureReason=" failureReason . ", addProductFallbackRefusedReason=product-tile-auto-gate, status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(postStatus) . ", scan=" failureScanPath
    )
    return false
}

AdvisorQuoteOpenSelectProductFallbackFromGatherData(db, fallbackReason := "", &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""

    clickResult := AdvisorQuoteRunOp("click_start_quoting_add_product", Map("selectors", db["selectors"]), 1, 100)
    AdvisorQuoteAppendLog("SELECT_PRODUCT_FALLBACK_USED", AdvisorQuoteGetLastStep(), "reason=" fallbackReason . ", clickResult=" clickResult)
    if (clickResult != "OK") {
        if (clickResult = "NO_BUTTON")
            failureReason := "Start Quoting could not be made valid and Add Product fallback was not found."
        else if (clickResult = "DISABLED")
            failureReason := "Start Quoting could not be made valid and Add Product fallback is disabled."
        else
            failureReason := "Start Quoting could not be made valid and Add Product fallback could not be clicked."
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "add-product-missing")
        return false
    }

    waitArgs := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    if !AdvisorQuoteWaitForCondition("to_select_product", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
        failureReason := "Gather Data did not transition to Select Product after Add Product fallback."
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "to-select-product-timeout")
        return false
    }
    return true
}

AdvisorQuoteHandleSelectProduct(db, &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    waitArgs := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    if !AdvisorQuoteWaitForCondition("on_select_product", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
        failureReason := "Select Product page did not become ready."
        return false
    }

    applyArgs := Map(
        "selectProductProductId", db["selectors"]["selectProductProductId"],
        "selectProductRatingStateId", db["selectors"]["selectProductRatingStateId"],
        "selectProductContinueId", db["selectors"]["selectProductContinueId"],
        "productValue", "AUTO",
        "ratingState", db["defaults"]["ratingState"],
        "currentInsured", db["defaults"]["currentInsured"],
        "ownOrRent", db["defaults"]["ownOrRent"],
        "currentInsuredQuestionText", db["texts"]["selectProductCurrentInsuredQuestion"],
        "currentInsuredAnswerText", db["texts"]["selectProductAnswerYesText"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    applyStatus := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("set_select_product_defaults", applyArgs))
    applyResult := AdvisorQuoteStatusValue(applyStatus, "result")
    if (applyResult = "FAILED" || applyResult = "ERROR" || applyResult = "") {
        failureReason := "Could not apply Select Product defaults."
        return false
    }

    AdvisorQuoteAppendLog(
        "SELECT_PRODUCT_DEFAULTS_APPLIED",
        AdvisorQuoteGetLastStep(),
        "result=" applyResult
            . ", productSet=" AdvisorQuoteStatusValue(applyStatus, "productSet")
            . ", ratingStateSet=" AdvisorQuoteStatusValue(applyStatus, "ratingStateSet")
            . ", currentInsuredSet=" AdvisorQuoteStatusValue(applyStatus, "currentInsuredSet")
            . ", currentInsuredMethod=" AdvisorQuoteStatusValue(applyStatus, "currentInsuredMethod")
            . ", ownOrRentSet=" AdvisorQuoteStatusValue(applyStatus, "ownOrRentSet")
            . ", ownOrRentMethod=" AdvisorQuoteStatusValue(applyStatus, "ownOrRentMethod")
    )

    status := AdvisorQuoteGetSelectProductStatus(db)
    AdvisorQuoteAppendLog("SELECT_PRODUCT_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildSelectProductStatusDetail(status))
    if !AdvisorQuoteSelectProductStatusValid(status, db, false, &failureReason) {
        failureScanPath := AdvisorQuoteScanCurrentPage("SELECT_PRODUCT", "select-product-defaults-invalid")
        AdvisorQuoteAppendLog("SELECT_PRODUCT_DEFAULTS_FAILED", AdvisorQuoteGetLastStep(), failureReason)
        return false
    }

    if !AdvisorQuoteClickById(db["selectors"]["selectProductContinueId"], db["timeouts"]["actionMs"])
        if !AdvisorQuoteClickByText("Continue", "button,a", db["timeouts"]["actionMs"]) {
            failureReason := "Could not click Continue on Select Product."
            failureScanPath := AdvisorQuoteScanCurrentPage("SELECT_PRODUCT", "select-product-continue-missing")
            return false
        }

    waitArgs := Map("ascProductContains", db["urls"]["ascProductContains"])
    if AdvisorQuoteWaitForCondition("select_product_to_consumer", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
        return true

    status := AdvisorQuoteGetSelectProductStatus(db)
    AdvisorQuoteAppendLog("SELECT_PRODUCT_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildSelectProductStatusDetail(status))
    if !AdvisorQuoteSelectProductStatusValid(status, db, true, &failureReason)
        AdvisorQuoteAppendLog("SELECT_PRODUCT_DEFAULTS_FAILED", AdvisorQuoteGetLastStep(), failureReason)
    else
        failureReason := "Select Product Continue did not transition to the next quote state."
    failureScanPath := AdvisorQuoteScanCurrentPage("SELECT_PRODUCT", "select-product-transition-timeout")
    return false
}

AdvisorQuoteGetSelectProductStatus(db) {
    args := Map(
        "texts", db["texts"],
        "selectors", db["selectors"],
        "selectProductProductId", db["selectors"]["selectProductProductId"],
        "selectProductRatingStateId", db["selectors"]["selectProductRatingStateId"],
        "selectProductContinueId", db["selectors"]["selectProductContinueId"],
        "currentInsuredQuestionText", db["texts"]["selectProductCurrentInsuredQuestion"]
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("select_product_status", args, 2, 120))
}

AdvisorQuoteBuildSelectProductStatusDetail(status) {
    return "ratingStateValue=" AdvisorQuoteStatusValue(status, "ratingStateValue")
        . ", ratingStateText=" AdvisorQuoteStatusValue(status, "ratingStateText")
        . ", productValue=" AdvisorQuoteStatusValue(status, "productValue")
        . ", productText=" AdvisorQuoteStatusValue(status, "productText")
        . ", currentInsuredValue=" AdvisorQuoteStatusValue(status, "currentInsuredValue")
        . ", currentInsuredSelected=" AdvisorQuoteStatusValue(status, "currentInsuredSelected")
        . ", currentInsuredSource=" AdvisorQuoteStatusValue(status, "currentInsuredSource")
        . ", currentInsuredAlert=" AdvisorQuoteStatusValue(status, "currentInsuredAlert")
        . ", ownOrRentValue=" AdvisorQuoteStatusValue(status, "ownOrRentValue")
        . ", ownOrRentSelected=" AdvisorQuoteStatusValue(status, "ownOrRentSelected")
        . ", ownOrRentSource=" AdvisorQuoteStatusValue(status, "ownOrRentSource")
        . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
        . ", continuePresent=" AdvisorQuoteStatusValue(status, "continuePresent")
        . ", continueEnabled=" AdvisorQuoteStatusValue(status, "continueEnabled")
}

AdvisorQuoteGetProductOverviewTileStatus(db) {
    args := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"],
        "productText", db["texts"]["productOverviewAutoTile"]
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("product_overview_tile_status", args, 2, 120))
}

AdvisorQuoteProductOverviewAutoSelected(status) {
    return (
        IsObject(status)
        && AdvisorQuoteStatusValue(status, "present") = "1"
        && AdvisorQuoteStatusValue(status, "selected") = "1"
    )
}

AdvisorQuoteBuildProductOverviewTileStatusDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", present=" AdvisorQuoteStatusValue(status, "present")
        . ", selected=" AdvisorQuoteStatusValue(status, "selected")
        . ", productText=" AdvisorQuoteStatusValue(status, "productText")
        . ", tileText=" AdvisorQuoteStatusValue(status, "tileText")
        . ", method=" AdvisorQuoteStatusValue(status, "method")
        . ", resolverMethod=" AdvisorQuoteStatusValue(status, "resolverMethod")
        . ", textSeedTag=" AdvisorQuoteStatusValue(status, "textSeedTag")
        . ", textSeedText=" AdvisorQuoteStatusValue(status, "textSeedText")
        . ", textSeedClass=" AdvisorQuoteStatusValue(status, "textSeedClass")
        . ", selectedEvidence=" AdvisorQuoteStatusValue(status, "selectedEvidence")
        . ", targetClass=" AdvisorQuoteStatusValue(status, "targetClass")
        . ", tileContainerText=" AdvisorQuoteStatusValue(status, "tileContainerText")
        . ", tileContainerClass=" AdvisorQuoteStatusValue(status, "tileContainerClass")
        . ", tileProductLabelCount=" AdvisorQuoteStatusValue(status, "tileProductLabelCount")
        . ", rejectedBroadContainer=" AdvisorQuoteStatusValue(status, "rejectedBroadContainer")
        . ", clickableClass=" AdvisorQuoteStatusValue(status, "clickableClass")
        . ", clickTargetTag=" AdvisorQuoteStatusValue(status, "clickTargetTag")
        . ", clickTargetClass=" AdvisorQuoteStatusValue(status, "clickTargetClass")
        . ", clickTargetRole=" AdvisorQuoteStatusValue(status, "clickTargetRole")
        . ", clickAttemptCount=" AdvisorQuoteStatusValue(status, "clickAttemptCount")
        . ", selectedBefore=" AdvisorQuoteStatusValue(status, "selectedBefore")
        . ", selectedAfter=" AdvisorQuoteStatusValue(status, "selectedAfter")
        . ", selectedClassSource=" AdvisorQuoteStatusValue(status, "selectedClassSource")
        . ", selectedAriaSource=" AdvisorQuoteStatusValue(status, "selectedAriaSource")
        . ", selectedDataStateSource=" AdvisorQuoteStatusValue(status, "selectedDataStateSource")
        . ", checkmarkEvidence=" AdvisorQuoteStatusValue(status, "checkmarkEvidence")
        . ", elementFromPointClass=" AdvisorQuoteStatusValue(status, "elementFromPointClass")
        . ", ancestorSummary=" AdvisorQuoteStatusValue(status, "ancestorSummary")
        . ", checkedDescendant=" AdvisorQuoteStatusValue(status, "checkedDescendant")
        . ", selectedDescendant=" AdvisorQuoteStatusValue(status, "selectedDescendant")
}

AdvisorQuoteWaitForProductOverviewAutoSelected(db, timeoutMs, &status := "") {
    status := Map()
    start := A_TickCount
    pollMs := db["timeouts"]["pollMs"]
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested()
            return false
        status := AdvisorQuoteGetProductOverviewTileStatus(db)
        if AdvisorQuoteProductOverviewAutoSelected(status)
            return true
        if !SafeSleep(pollMs)
            return false
    }
    status := AdvisorQuoteGetProductOverviewTileStatus(db)
    return AdvisorQuoteProductOverviewAutoSelected(status)
}

AdvisorQuoteSelectProductStatusValid(status, db, afterContinue := false, &failureReason := "") {
    failureReason := ""
    if !IsObject(status) || (status.Count = 0) {
        failureReason := "Select Product status could not be read back from the page."
        return false
    }

    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "ratingStateValue"),
        AdvisorQuoteStatusValue(status, "ratingStateText"),
        db["defaults"]["ratingState"],
        db["defaults"]["ratingState"]
    ) {
        failureReason := "Rating State did not stay on " db["defaults"]["ratingState"] "."
        return false
    }

    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "productValue"),
        AdvisorQuoteStatusValue(status, "productText"),
        "AUTO",
        db["texts"]["productOverviewAutoTile"]
    ) {
        failureReason := "Select Product did not stay on Auto."
        return false
    }

    if (AdvisorQuoteStatusValue(status, "continuePresent") != "1") {
        failureReason := "Select Product Continue button is not present."
        return false
    }
    if (AdvisorQuoteStatusValue(status, "continueEnabled") != "1") {
        failureReason := "Select Product Continue button is not enabled."
        return false
    }

    currentInsuredWanted := AdvisorNormalizeLooseToken(db["defaults"]["currentInsured"])
    currentInsuredValue := AdvisorNormalizeLooseToken(AdvisorQuoteStatusValue(status, "currentInsuredValue"))
    currentInsuredSelected := (
        AdvisorQuoteStatusValue(status, "currentInsuredSelected") = "1"
        || currentInsuredValue = currentInsuredWanted
    )
    if (!currentInsuredSelected || currentInsuredValue != currentInsuredWanted) {
        failureReason := "Current insured Yes default did not stick on Select Product."
        return false
    }

    ownOrRentWanted := AdvisorNormalizeLooseToken(db["defaults"]["ownOrRent"])
    ownOrRentValue := AdvisorNormalizeLooseToken(AdvisorQuoteStatusValue(status, "ownOrRentValue"))
    ownOrRentSelected := (
        AdvisorQuoteStatusValue(status, "ownOrRentSelected") = "1"
        || ownOrRentValue = ownOrRentWanted
    )
    if (!ownOrRentSelected || ownOrRentValue != ownOrRentWanted) {
        failureReason := "Own/Rent Own default did not stick on Select Product."
        return false
    }

    return true
}

AdvisorQuoteHandleProductOverview(db) {
    global advisorQuoteProductOverviewAutoPending, advisorQuoteProductOverviewAutoVerified
    global advisorQuoteProductTileAutoSelectedOnOverview, advisorQuoteProductOverviewSaved, advisorQuoteGatherAutoCommitted
    waitArgs := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    if !AdvisorQuoteWaitForCondition("on_product_overview", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
        return "OVERVIEW_NOT_READY"

    advisorQuoteProductOverviewAutoPending := false
    advisorQuoteProductOverviewAutoVerified := false
    advisorQuoteProductTileAutoSelectedOnOverview := false
    advisorQuoteProductOverviewSaved := false
    advisorQuoteGatherAutoCommitted := false
    preStatus := AdvisorQuoteGetProductOverviewTileStatus(db)
    AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_AUTO_STATUS", "PRODUCT_OVERVIEW", "phase=before-click, " AdvisorQuoteBuildProductOverviewTileStatusDetail(preStatus))
    tileStatus := preStatus
    tileResult := "SKIPPED_ALREADY_SELECTED"
    idempotentPath := "already-selected"
    clickSkipped := "1"

    if AdvisorQuoteProductOverviewAutoSelected(preStatus) {
        AdvisorQuoteAppendLog(
            "PRODUCT_TILE_AUTO_ALREADY_SELECTED",
            "PRODUCT_OVERVIEW",
            "productTileStatusBeforeClick=" AdvisorQuoteStatusValue(preStatus, "result")
                . ", productTileSelectedBeforeClick=1"
                . ", productTileClickSkipped=1"
                . ", productTileIdempotentPath=already-selected"
                . ", productTileSelectedEvidence=" AdvisorQuoteStatusValue(preStatus, "selectedEvidence")
        )
    } else {
        clickSkipped := "0"
        idempotentPath := "clicked-to-select"
        if (AdvisorQuoteStatusValue(preStatus, "present") != "1") {
            AdvisorQuoteAppendLog(
                "PRODUCT_OVERVIEW_AUTO_NOT_PRESENT",
                "PRODUCT_OVERVIEW",
                "productTileStatusBeforeClick=" AdvisorQuoteStatusValue(preStatus, "result")
                    . ", productTileSelectedBeforeClick=" AdvisorQuoteStatusValue(preStatus, "selected")
                    . ", productTileClickSkipped=1"
                    . ", productTileIdempotentPath=failed, "
                    . AdvisorQuoteBuildProductOverviewTileStatusDetail(preStatus)
            )
            return "PRODUCT_TILE_AUTO_NOT_PRESENT"
        }

        AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_ACTION", "PRODUCT_OVERVIEW", "action=select-auto-tile, match=text:Auto")
        tileArgs := Map(
            "urls", db["urls"],
            "texts", db["texts"],
            "selectors", db["selectors"],
            "productText", db["texts"]["productOverviewAutoTile"]
        )
        tileResult := AdvisorQuoteRunOp("click_product_overview_tile", tileArgs)
        AdvisorQuoteAppendLog(
            "PRODUCT_OVERVIEW_AUTO_CLICK_RESULT",
            "PRODUCT_OVERVIEW",
            "productTileClickResult=" tileResult
                . ", productTileStatusBeforeClick=" AdvisorQuoteStatusValue(preStatus, "result")
                . ", productTileSelectedBeforeClick=" AdvisorQuoteStatusValue(preStatus, "selected")
                . ", productTileClickSkipped=0"
                . ", productTileIdempotentPath=clicked-to-select"
        )
        if (tileResult = "NO_TILE")
            return "PRODUCT_TILE_AUTO_NOT_PRESENT"
        if (tileResult != "OK")
            return "PRODUCT_TILE_AUTO_CLICK_FAILED"

        if !SafeSleep(db["timeouts"]["shortMs"])
            return "PRODUCT_TILE_AUTO_CLICK_FAILED"

        if !AdvisorQuoteWaitForProductOverviewAutoSelected(db, db["timeouts"]["actionMs"], &tileStatus) {
            AdvisorQuoteAppendLog(
                "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED",
                "PRODUCT_OVERVIEW",
                "productTileClickResult=" tileResult
                    . ", productTileStatusBeforeClick=" AdvisorQuoteStatusValue(preStatus, "result")
                    . ", productTileSelectedBeforeClick=" AdvisorQuoteStatusValue(preStatus, "selected")
                    . ", productTileStatusAfterClick=" AdvisorQuoteStatusValue(tileStatus, "result")
                    . ", productTileSelectedAfterClick=" AdvisorQuoteStatusValue(tileStatus, "selected")
                    . ", productTileSelectedEvidence=" AdvisorQuoteStatusValue(tileStatus, "selectedEvidence")
                    . ", productTileClickSkipped=0"
                    . ", productTileIdempotentPath=failed, "
                    . AdvisorQuoteBuildProductOverviewTileStatusDetail(tileStatus)
            )
            if (AdvisorQuoteStatusValue(preStatus, "selected") = "1" && AdvisorQuoteStatusValue(tileStatus, "selected") != "1")
                return "PRODUCT_TILE_AUTO_UNSELECTED_BY_CLICK"
            return "PRODUCT_TILE_AUTO_VERIFY_FAILED"
        }
    }
    AdvisorQuoteAppendLog(
        "PRODUCT_OVERVIEW_AUTO_VERIFIED",
        "PRODUCT_OVERVIEW",
        "productTileClickResult=" tileResult
            . ", productTileStatusBeforeClick=" AdvisorQuoteStatusValue(preStatus, "result")
            . ", productTileSelectedBeforeClick=" AdvisorQuoteStatusValue(preStatus, "selected")
            . ", productTileStatusAfterClick=" AdvisorQuoteStatusValue(tileStatus, "result")
            . ", productTileSelectedAfterClick=" AdvisorQuoteStatusValue(tileStatus, "selected")
            . ", productTileSelectedEvidence=" AdvisorQuoteStatusValue(tileStatus, "selectedEvidence")
            . ", productTileClickSkipped=" clickSkipped
            . ", productTileIdempotentPath=" idempotentPath
            . ", " AdvisorQuoteBuildProductOverviewTileStatusDetail(tileStatus)
    )
    advisorQuoteProductTileAutoSelectedOnOverview := true
    AdvisorQuoteAppendLog(
        "PRODUCT_TILE_AUTO_SELECTED_ON_OVERVIEW",
        "PRODUCT_OVERVIEW",
        "ProductTileAutoSelectedOnOverview=1, productTileSelectedEvidenceAfter=" AdvisorQuoteStatusValue(tileStatus, "selectedEvidence")
    )

    AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_ACTION", "PRODUCT_OVERVIEW", "action=click-primary, match=text:" db["texts"]["productOverviewContinueText"])
    if !AdvisorQuoteClickByText(db["texts"]["productOverviewContinueText"], "button,a,[role=button]", db["timeouts"]["actionMs"]) {
        AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_SAVE_CONTINUE", "PRODUCT_OVERVIEW", "result=FAILED")
        return "CONTINUE_BUTTON_NOT_FOUND"
    }
    advisorQuoteProductOverviewSaved := true
    AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_SAVE_CONTINUE", "PRODUCT_OVERVIEW", "result=OK, productTileSaveContinueClicked=1, ProductOverviewSaved=1")

    waitArgs := Map("rapportContains", db["urls"]["rapportContains"])
    if !AdvisorQuoteWaitForCondition("gather_data", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
        return "RAPPORT_TRANSITION_TIMEOUT"

    advisorQuoteProductOverviewAutoPending := true
    advisorQuoteProductOverviewAutoVerified := true
    AdvisorQuoteAppendLog(
        "PRODUCT_OVERVIEW_AUTO_PATH_VERIFIED",
        "PRODUCT_OVERVIEW",
        "selected=1, saveContinue=1, reached=RAPPORT, ProductTileAutoSelectedOnOverview=1, ProductOverviewSaved=1, GatherAutoCommitted=0"
    )
    return ""
}

AdvisorQuoteHandleConsumerReports(db, &failureReason := "") {
    failureReason := ""
    waitArgs := AdvisorQuoteAscWaitArgs(db, Map("consumerReportsConsentYesId", db["selectors"]["consumerReportsConsentYesId"]))
    if !AdvisorQuoteWaitForCondition("consumer_reports_ready", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
        failureReason := "CONSUMER_REPORTS_READY_TIMEOUT"
        return false
    }

    if !AdvisorQuoteClickById(db["selectors"]["consumerReportsConsentYesId"], db["timeouts"]["actionMs"])
        if !AdvisorQuoteClickByText("yes", "button,a", db["timeouts"]["actionMs"]) {
            failureReason := "CONSUMER_REPORTS_CONSENT_CLICK_FAILED"
            return false
        }

    if !AdvisorQuoteWaitForCondition("drivers_or_incidents", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], AdvisorQuoteAscWaitArgs(db)) {
        failureReason := "CONSUMER_REPORTS_TO_DRIVERS_OR_INCIDENTS_TIMEOUT"
        return false
    }
    return true
}

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
        . ", maritalStatusPresent=" AdvisorQuoteStatusValue(status, "maritalStatusPresent")
        . ", maritalStatusSelected=" AdvisorQuoteStatusValue(status, "maritalStatusSelected")
        . ", spouseDropdownPresent=" AdvisorQuoteStatusValue(status, "spouseDropdownPresent")
        . ", spouseOptionCount=" AdvisorQuoteStatusValue(status, "spouseOptionCount")
        . ", propertyOwnershipValue=" AdvisorQuoteStatusValue(status, "propertyOwnershipValue")
        . ", ageFirstLicensedValue=" AdvisorQuoteStatusValue(status, "ageFirstLicensedValue")
        . ", emailPresent=" AdvisorQuoteStatusValue(status, "emailPresent")
        . ", phonePresent=" AdvisorQuoteStatusValue(status, "phonePresent")
        . ", saveButtonPresent=" AdvisorQuoteStatusValue(status, "saveButtonPresent")
        . ", saveButtonEnabled=" AdvisorQuoteStatusValue(status, "saveButtonEnabled")
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
        failureReason := "ASC_INLINE_PARTICIPANT_SAVE_FAILED: fill failed."
        failureScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "asc-inline-fill-failed")
        return false
    }
    if !AdvisorQuoteClickById(db["selectors"]["participantSaveId"], db["timeouts"]["actionMs"]) {
        failureReason := "ASC_INLINE_PARTICIPANT_SAVE_FAILED: save click failed."
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
    if (AdvisorQuoteStatusValue(participantStatus, "result") != "FOUND")
        return false
    if (AdvisorQuoteStatusValue(participantStatus, "ageFirstLicensedValue") = "")
        return false
    if (AdvisorQuoteStatusValue(participantStatus, "propertyOwnershipValue") = "" && AdvisorQuoteStatusValue(participantStatus, "propertyOwnershipText") = "")
        return false
    return AdvisorQuoteStatusValue(participantStatus, "missing") = ""
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
