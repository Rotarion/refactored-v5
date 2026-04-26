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
        AdvisorQuoteLogStop("manual-stop-detected-after-run")
        return AdvisorQuoteResultFail(AdvisorQuoteGetLastStep(), AdvisorQuoteGetLastStep(), "Stopped manually.", false, AdvisorQuoteResultValue(result, "scanPath"))
    }

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
            return AdvisorQuoteStateConsumerReports(db, attempt, entryScanPath)
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

    if AdvisorQuoteIsStateInList(state, ["CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS", "DUPLICATE"])
        return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create-form state already satisfied.", entryScanPath, state)

    if (state = "BEGIN_QUOTING_SEARCH") {
        createResult := AdvisorQuoteOpenCreateNewProspectFromSearchResult(db)
        if !AdvisorQuoteResultOk(createResult)
            return createResult
        state := AdvisorQuoteResultValue(createResult, "observedState")
        if (state = "")
            state := AdvisorQuoteDetectState(db)
        if AdvisorQuoteIsStateInList(state, ["CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS", "DUPLICATE"])
            return AdvisorQuoteResultOkValue("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Create New Prospect advanced beyond the form.", AdvisorQuoteResultValue(createResult, "scanPath"), state)
    }

    if (state != "BEGIN_QUOTING_FORM")
        return AdvisorQuoteResultFail("ENTRY_CREATE_FORM", "ENTRY_CREATE_FORM", "Expected the Create New Prospect form.", true, entryScanPath, state)

    fields := profile["fields"]
    if !AdvisorQuoteWaitForProspectFormReady(db) {
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

    nextState := AdvisorQuoteWaitForObservedState(
        db,
        ["DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"],
        db["timeouts"]["transitionMs"]
    )
    if (nextState = "")
        nextState := AdvisorQuoteDetectState(db)

    AdvisorQuoteAppendLog("CLICK_TRANSITION", "ENTRY_CREATE_FORM", "target=" clickTarget . ", beforeState=BEGIN_QUOTING_FORM, afterState=" nextState)
    if AdvisorQuoteIsStateInList(nextState, ["DUPLICATE", "CUSTOMER_SUMMARY_OVERVIEW", "PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
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
    if (state != "CUSTOMER_SUMMARY_OVERVIEW")
        return AdvisorQuoteResultFail("CUSTOMER_SUMMARY_OVERVIEW", "CUSTOMER_SUMMARY_OVERVIEW", "Expected Customer Summary Overview before START HERE routing.", true, entryScanPath, state)

    AdvisorQuoteAppendLog("CUSTOMER_SUMMARY_ACTION", "CUSTOMER_SUMMARY_OVERVIEW", "action=click-start-here, match=text:" db["texts"]["customerSummaryStartHereText"])
    if !AdvisorQuoteClickByText(db["texts"]["customerSummaryStartHereText"], "button,a,[role=button]", db["timeouts"]["actionMs"]) {
        failScan := AdvisorQuoteScanCurrentPage("CUSTOMER_SUMMARY_OVERVIEW", "start-here-missing")
        return AdvisorQuoteResultFail("CUSTOMER_SUMMARY_OVERVIEW", "CUSTOMER_SUMMARY_OVERVIEW", "Could not click START HERE (Pre-fill included) on Customer Summary Overview.", true, failScan, state)
    }

    nextState := AdvisorQuoteWaitForObservedState(
        db,
        ["PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"],
        db["timeouts"]["transitionMs"]
    )
    if (nextState = "")
        nextState := AdvisorQuoteDetectState(db)

    AdvisorQuoteAppendLog("CLICK_TRANSITION", "CUSTOMER_SUMMARY_OVERVIEW", "target=text:" db["texts"]["customerSummaryStartHereText"] . ", beforeState=" state . ", afterState=" nextState)
    if AdvisorQuoteIsStateInList(nextState, ["PRODUCT_OVERVIEW", "RAPPORT", "SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("CUSTOMER_SUMMARY_OVERVIEW", "CUSTOMER_SUMMARY_OVERVIEW", "Customer Summary Overview advanced through START HERE.", entryScanPath, nextState)

    failScan := AdvisorQuoteScanCurrentPage("CUSTOMER_SUMMARY_OVERVIEW", "start-here-transition-failed")
    return AdvisorQuoteResultFail("CUSTOMER_SUMMARY_OVERVIEW", "CUSTOMER_SUMMARY_OVERVIEW", "START HERE did not reach Product Overview or a later quote state.", true, failScan, nextState)
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

AdvisorQuoteStateConsumerReports(db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("CONSUMER_REPORTS", "Accepting consumer reports consent.")
    state := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(state, ["INCIDENTS"]) || AdvisorQuoteIsDriversVehiclesState(db)
        return AdvisorQuoteResultOkValue("CONSUMER_REPORTS", "CONSUMER_REPORTS", "Consumer reports stage already satisfied.", entryScanPath, state)

    if !AdvisorQuoteHandleConsumerReports(db) {
        failScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "consumer-reports-failed")
        return AdvisorQuoteResultFail("CONSUMER_REPORTS", "CONSUMER_REPORTS", "Consumer Reports consent did not complete.", true, failScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("CONSUMER_REPORTS", "CONSUMER_REPORTS", "Consumer Reports completed.", entryScanPath, AdvisorQuoteDetectState(db))
}

AdvisorQuoteStateDriversVehicles(profile, db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("DRIVERS_VEHICLES", "Resolving drivers and vehicles.")
    state := AdvisorQuoteDetectState(db)
    if (state = "INCIDENTS")
        return AdvisorQuoteResultOkValue("DRIVERS_VEHICLES", "DRIVERS_VEHICLES", "Drivers and Vehicles already completed.", entryScanPath, state)

    if !AdvisorQuoteHandleDriversVehicles(profile, db) {
        failScan := AdvisorQuoteScanCurrentPage("DRIVERS_VEHICLES", "drivers-vehicles-failed")
        return AdvisorQuoteResultFail("DRIVERS_VEHICLES", "DRIVERS_VEHICLES", "Drivers and Vehicles stage did not complete.", true, failScan, AdvisorQuoteDetectState(db))
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
    return AdvisorQuoteWaitForCondition("drivers_or_incidents", 500, 150, Map()) && !AdvisorQuoteIsIncidentsPage(db)
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

AdvisorQuoteClickCreateProspectPrimaryButton(db) {
    return AdvisorQuoteClickCreateProspectPrimaryButtonDetailed(db) != ""
}

AdvisorQuoteHandleDuplicateProspect(profile, db) {
    person := profile["person"]
    address := profile["address"]
    args := Map(
        "firstName", person["firstName"],
        "lastName", person["lastName"],
        "street", address["street"],
        "zip", address["zip"],
        "dob", person["dob"]
    )
    result := AdvisorQuoteRunOp("handle_duplicate_prospect", args)
    if (result = "NO_ACTION")
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
    global advisorQuoteProductOverviewAutoPending
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

    vehicles := profile["vehicles"]
    for _, vehicle in vehicles {
        if StopRequested() {
            failureReason := "Stopped manually."
            return false
        }

        AdvisorQuoteSetStep("GATHER_DATA_VEHICLE_CHECK", "Checking vehicle: " vehicle["displayKey"])
        AdvisorQuoteAppendLog(
            "VEHICLE_NORMALIZED",
            AdvisorQuoteGetLastStep(),
            "raw=" vehicle["raw"]
                . ", displayKey=" vehicle["displayKey"]
                . ", year=" vehicle["year"]
                . ", make=" vehicle["make"]
                . ", model=" vehicle["model"]
                . ", trimHint=" vehicle["trimHint"]
        )

        if AdvisorQuoteVehicleAlreadyListed(vehicle)
            continue

        confirmOutcome := AdvisorQuoteConfirmPotentialVehicle(vehicle, db, &failureReason, &failureScanPath)
        if (confirmOutcome = "CONFIRMED")
            continue
        if (confirmOutcome = "FAILED")
            return false

        AdvisorQuoteSetStep("GATHER_DATA_VEHICLE_ADD", "Adding vehicle: " vehicle["displayKey"])
        if !AdvisorQuoteAddVehicleInGatherData(vehicle, db) {
            failureReason := "Could not add vehicle " vehicle["displayKey"] " on Gather Data."
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-add-failed")
            return false
        }
    }

    startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
    AdvisorQuoteAppendLog("GATHER_START_QUOTING_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))

    startQuotingReason := ""
    startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
    if !startQuotingReady {
        if (advisorQuoteProductOverviewAutoPending && !AdvisorQuoteGatherStartQuotingAutoSelected(startQuotingStatus)) {
            AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_AUTO_NOT_COMMITTED", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))
            advisorQuoteProductOverviewAutoPending := false
        }

        if (AdvisorQuoteStatusValue(startQuotingStatus, "hasStartQuotingText") = "1") {
            applyStatus := AdvisorQuoteEnsureAutoStartQuotingState(db)
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_AUTO_SET", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingApplyDetail(applyStatus))

            startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))
            startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
        }
    }

    if startQuotingReady {
        advisorQuoteProductOverviewAutoPending := false
        AdvisorQuoteAppendLog("GATHER_START_QUOTING_READY", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))

        clickResult := AdvisorQuoteClickCreateQuotesOrderReports(db)
        AdvisorQuoteAppendLog("GATHER_START_QUOTING_CREATE_QUOTES_CLICK", AdvisorQuoteGetLastStep(), "result=" clickResult)
        if (clickResult != "OK") {
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

    if !AdvisorQuoteOpenSelectProductFallbackFromGatherData(db, startQuotingReason, &failureReason, &failureScanPath) {
        if (failureScanPath = "")
            failureScanPath := notReadyScan
        return false
    }
    return true
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
    if (AdvisorQuoteStatusValue(applyStatus, "result") != "OK") {
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
        . ", autoProductPresent=" AdvisorQuoteStatusValue(status, "autoProductPresent")
        . ", autoProductChecked=" AdvisorQuoteStatusValue(status, "autoProductChecked")
        . ", autoProductSelected=" AdvisorQuoteStatusValue(status, "autoProductSelected")
        . ", autoProductSource=" AdvisorQuoteStatusValue(status, "autoProductSource")
        . ", ratingStateValue=" AdvisorQuoteStatusValue(status, "ratingStateValue")
        . ", ratingStateText=" AdvisorQuoteStatusValue(status, "ratingStateText")
        . ", ratingStateSource=" AdvisorQuoteStatusValue(status, "ratingStateSource")
        . ", createQuoteButtonPresent=" AdvisorQuoteStatusValue(status, "createQuoteButtonPresent")
        . ", createQuoteButtonEnabled=" AdvisorQuoteStatusValue(status, "createQuoteButtonEnabled")
        . ", addProductLinkPresent=" AdvisorQuoteStatusValue(status, "addProductLinkPresent")
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

AdvisorQuoteGatherStartQuotingStatusValid(status, db, &failureReason := "") {
    failureReason := ""
    if !IsObject(status) || (status.Count = 0) {
        failureReason := "Gather Data Start Quoting status could not be read back from the page."
        return false
    }
    if (AdvisorQuoteStatusValue(status, "hasStartQuotingText") != "1") {
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
    if (AdvisorQuoteStatusValue(status, "createQuoteButtonPresent") != "1") {
        failureReason := "Create Quotes & Order Reports is not present on Gather Data."
        return false
    }
    if (AdvisorQuoteStatusValue(status, "createQuoteButtonEnabled") != "1") {
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

AdvisorQuoteVehicleAlreadyListed(vehicle) {
    args := Map(
        "year", vehicle["year"],
        "make", vehicle["make"],
        "model", vehicle["model"]
    )
    return AdvisorQuoteRunOp("vehicle_already_listed", args) = "1"
}

AdvisorQuoteConfirmPotentialVehicle(vehicle, db, &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    args := Map(
        "year", vehicle["year"],
        "make", vehicle["make"],
        "model", vehicle["model"]
    )
    status := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("confirm_potential_vehicle", args))
    result := AdvisorQuoteStatusValue(status, "result")
    cardText := AdvisorQuoteStatusValue(status, "cardText")
    matches := AdvisorQuoteStatusValue(status, "matches")

    switch result {
        case "", "NO_MATCH":
            return "NO_MATCH"
        case "CONFIRMED":
            AdvisorQuoteAppendLog(
                "VEHICLE_POTENTIAL_CONFIRM",
                AdvisorQuoteGetLastStep(),
                "year=" vehicle["year"]
                    . ", make=" vehicle["make"]
                    . ", model=" vehicle["model"]
                    . ", matches=" matches
                    . ", cardText=" cardText
            )
            waitArgs := Map(
                "year", vehicle["year"],
                "make", vehicle["make"],
                "model", vehicle["model"]
            )
            if !AdvisorQuoteWaitForCondition("vehicle_confirmed", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
                failureReason := "Potential vehicle confirmation did not stick for " vehicle["displayKey"] "."
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-confirm-timeout")
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
                    . ", cards=" AdvisorQuoteStatusValue(status, "cards")
            )
            failureReason := "Potential vehicle match is ambiguous for " vehicle["displayKey"] "."
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "vehicle-potential-ambiguous")
            return "FAILED"
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

AdvisorQuoteAddVehicleInGatherData(vehicle, db) {
    idx := AdvisorQuotePrepareVehicleRow(vehicle["year"])
    if (idx < 0)
        return false

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Manufacturer", db["timeouts"]["transitionMs"], 2)
        return false

    if !AdvisorQuoteSelectVehicleDropdownOption(idx, "Manufacturer", vehicle["make"], false)
        return false

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "Model", db["timeouts"]["transitionMs"], 2)
        return false

    if !AdvisorQuoteSelectVehicleDropdownOption(idx, "Model", vehicle["model"], false)
        return false

    if !AdvisorQuoteWaitForVehicleSelectEnabled(idx, "SubModel", db["timeouts"]["transitionMs"], 1)
        return false

    if !AdvisorQuoteSelectVehicleDropdownOption(idx, "SubModel", vehicle["trimHint"], true)
        return false

    if !AdvisorQuoteClickById(db["selectors"]["confirmVehicleId"], db["timeouts"]["actionMs"]) {
        if !AdvisorQuoteClickByText("Add", "button,a", db["timeouts"]["actionMs"])
            return false
    }

    waitArgs := Map(
        "year", vehicle["year"],
        "make", vehicle["make"],
        "model", vehicle["model"]
    )
    return AdvisorQuoteWaitForCondition("vehicle_added_tile", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
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

AdvisorQuoteSelectVehicleDropdownOption(index, fieldName, wantedText, allowFirstNonEmpty := false) {
    args := Map(
        "index", index,
        "fieldName", fieldName,
        "wantedText", wantedText,
        "allowFirstNonEmpty", allowFirstNonEmpty
    )
    result := AdvisorQuoteRunOp("select_vehicle_dropdown_option", args)
    return result = "OK"
}

AdvisorQuoteEnsureAutoStartQuotingState(db) {
    args := Map(
        "ratingState", db["defaults"]["ratingState"],
        "selectors", db["selectors"]
    )
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("ensure_auto_start_quoting_state", args))
}

AdvisorQuoteClickCreateQuotesOrderReports(db) {
    return AdvisorQuoteRunOp("click_create_quotes_order_reports", Map("selectors", db["selectors"]), 1, 100)
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
    if (AdvisorQuoteStatusValue(applyStatus, "result") != "OK") {
        failureReason := "Could not apply Select Product defaults."
        return false
    }

    AdvisorQuoteAppendLog(
        "SELECT_PRODUCT_DEFAULTS_APPLIED",
        AdvisorQuoteGetLastStep(),
        "productSet=" AdvisorQuoteStatusValue(applyStatus, "productSet")
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
        . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
        . ", continuePresent=" AdvisorQuoteStatusValue(status, "continuePresent")
        . ", continueEnabled=" AdvisorQuoteStatusValue(status, "continueEnabled")
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

    currentInsuredValue := AdvisorNormalizeLooseToken(AdvisorQuoteStatusValue(status, "currentInsuredValue"))
    currentInsuredSelected := (
        AdvisorQuoteStatusValue(status, "currentInsuredSelected") = "1"
        || currentInsuredValue = AdvisorNormalizeLooseToken(db["defaults"]["currentInsured"])
    )
    currentInsuredAlert := (
        AdvisorQuoteStatusValue(status, "currentInsuredAlert") = "1"
        || InStr(AdvisorNormalizeLooseToken(AdvisorQuoteStatusValue(status, "alerts")), "CURRENTLY INSURED")
    )

    if (!currentInsuredSelected && currentInsuredAlert) {
        failureReason := "Current insured Yes default did not stick on Select Product."
        return false
    }
    if (afterContinue && !currentInsuredSelected) {
        failureReason := "Current insured Yes was not selected after Continue was attempted."
        return false
    }

    return true
}

AdvisorQuoteHandleProductOverview(db) {
    global advisorQuoteProductOverviewAutoPending
    waitArgs := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    if !AdvisorQuoteWaitForCondition("on_product_overview", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
        return "OVERVIEW_NOT_READY"

    advisorQuoteProductOverviewAutoPending := false
    AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_ACTION", "PRODUCT_OVERVIEW", "action=select-auto-tile, match=text:Auto")
    tileArgs := Map(
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"],
        "productText", db["texts"]["productOverviewAutoTile"]
    )
    tileResult := AdvisorQuoteRunOp("click_product_overview_tile", tileArgs)
    if (tileResult = "NO_TILE")
        return "AUTO_TILE_NOT_FOUND"
    if (tileResult != "OK")
        return "AUTO_TILE_CLICK_FAILED"

    if !SafeSleep(db["timeouts"]["shortMs"])
        return "AUTO_TILE_CLICK_FAILED"

    AdvisorQuoteAppendLog("PRODUCT_OVERVIEW_ACTION", "PRODUCT_OVERVIEW", "action=click-primary, match=text:" db["texts"]["productOverviewContinueText"])
    if !AdvisorQuoteClickByText(db["texts"]["productOverviewContinueText"], "button,a,[role=button]", db["timeouts"]["actionMs"])
        return "CONTINUE_BUTTON_NOT_FOUND"

    waitArgs := Map("rapportContains", db["urls"]["rapportContains"])
    if !AdvisorQuoteWaitForCondition("gather_data", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
        return "RAPPORT_TRANSITION_TIMEOUT"

    advisorQuoteProductOverviewAutoPending := true
    return ""
}

AdvisorQuoteHandleConsumerReports(db) {
    waitArgs := Map("consumerReportsConsentYesId", db["selectors"]["consumerReportsConsentYesId"])
    if !AdvisorQuoteWaitForCondition("consumer_reports_ready", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
        return false

    if !AdvisorQuoteClickById(db["selectors"]["consumerReportsConsentYesId"], db["timeouts"]["actionMs"])
        if !AdvisorQuoteClickByText("yes", "button,a", db["timeouts"]["actionMs"])
            return false

    return AdvisorQuoteWaitForCondition("drivers_or_incidents", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], Map())
}

AdvisorQuoteHandleDriversVehicles(profile, db) {
    AdvisorQuoteSetStep("DRIVERS_VEHICLES", "Waiting for Drivers and vehicles stage.")
    if !AdvisorQuoteWaitForCondition("drivers_or_incidents", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], Map())
        return false

    if AdvisorQuoteIsIncidentsPage(db)
        return true

    if !AdvisorQuoteResolveDrivers(profile, db)
        return false

    if !AdvisorQuoteResolveVehicles(profile, db)
        return false

    if !AdvisorQuoteHandleOpenModals(profile, db, 12000)
        return false

    if !AdvisorQuoteWaitForContinueEnabled(db["selectors"]["driverVehicleContinueId"], db["timeouts"]["transitionMs"])
        return false

    if !AdvisorQuoteClickById(db["selectors"]["driverVehicleContinueId"], db["timeouts"]["actionMs"])
        return false

    return AdvisorQuoteWaitForCondition("after_driver_vehicle_continue", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], Map())
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
    args := Map(
        "year", vehicle["year"],
        "make", vehicle["make"],
        "model", vehicle["model"]
    )
    return AdvisorQuoteRunOp("find_vehicle_add_button", args)
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
        "spouseSelectId", db["texts"]["spouseSelectId"]
    )
    return AdvisorQuoteRunOp("fill_participant_modal", args) = "OK"
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

AdvisorQuoteSelectRemoveReason(reasonCode) {
    result := AdvisorQuoteRunOp("select_remove_reason", Map("reasonCode", reasonCode))
    return result = "OK"
}

AdvisorQuoteFillVehicleModal(profile, db) {
    threshold := Integer(db["defaults"]["vehicleFinanceYearThreshold"])
    return AdvisorQuoteRunOp("fill_vehicle_modal", Map("threshold", threshold)) = "OK"
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

    return AdvisorQuoteWaitForCondition("incidents_done", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], Map())
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
    args := Map("incidentsHeading", db["texts"]["incidentsHeading"])
    return AdvisorQuoteWaitForCondition("is_incidents", 500, 150, args)
}

AdvisorQuoteRunOp(op, args := Map(), retries := 1, retryDelayMs := 200) {
    return AdvisorQuoteRunJsOp(op, args, retries, retryDelayMs)
}

AdvisorQuoteRunJsOp(op, args := Map(), retries := 1, retryDelayMs := 200) {
    attempts := Max(1, Integer(retries))
    rendered := AdvisorQuoteRenderOpJs(op, args)
    if (rendered = "")
        return ""

    Loop attempts {
        if StopRequested()
            return ""
        AdvisorQuoteLogJsBridgeOp(op, args, A_Index, attempts)
        if !AdvisorQuoteEnsureConsoleBridge() {
            AdvisorQuoteInvalidateConsoleBridge("op=" op ", attempt=" A_Index "/" attempts ", reason=ensure-console-failed")
            return ""
        }

        result := Trim(String(AdvisorQuoteExecuteBridgeJs(rendered, true)))
        if (result != "") {
            AdvisorQuoteMarkConsoleBridgeFocused()
            return result
        }

        AdvisorQuoteInvalidateConsoleBridge("op=" op ", attempt=" A_Index "/" attempts ", reason=empty-result")
        if (attempts > 1 && A_Index < attempts)
            AdvisorQuoteAppendLog("JS_ASSET_RETRY", AdvisorQuoteGetLastStep(), "op=" op ", attempt=" A_Index "/" attempts)
        if (A_Index < attempts) {
            if !SafeSleep(retryDelayMs)
                return ""
        }
    }
    AdvisorQuoteAppendLog("JS_ASSET_EMPTY", AdvisorQuoteGetLastStep(), "op=" op ", attempts=" attempts)
    return ""
}

AdvisorQuoteRenderOpJs(op, args := Map()) {
    params := Map("OP", String(op), "ARGS", args)
    jsText := LoadJsAsset("advisor_quote/ops_result.js", true)
    if (jsText = "")
        return ""
    return RenderJsTemplate(jsText, params)
}

AdvisorQuoteEnsureConsoleBridge() {
    global advisorQuoteConsoleBridgeOpen, advisorQuoteConsoleBridgeFocus

    if StopRequested() {
        AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=stop-requested")
        return false
    }
    if !FocusEdge() {
        AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=edge-not-found")
        return false
    }

    if !advisorQuoteConsoleBridgeOpen {
        Send "^+j"
        if !SafeSleep(500) {
            AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=open-wait-interrupted")
            return false
        }
        advisorQuoteConsoleBridgeOpen := true
        advisorQuoteConsoleBridgeFocus := "console"
        AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_OPENED", AdvisorQuoteGetLastStep(), "mode=edge")
        return true
    }

    if (advisorQuoteConsoleBridgeFocus != "console") {
        Send "^+j"
        if !SafeSleep(350) {
            AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=reuse-focus-interrupted")
            return false
        }
    }

    advisorQuoteConsoleBridgeFocus := "console"
    AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_REUSED", AdvisorQuoteGetLastStep(), "mode=edge")
    return true
}

AdvisorQuoteRefocusPageForNativeInput(reason := "") {
    global advisorQuoteConsoleBridgeOpen, advisorQuoteConsoleBridgeFocus

    if StopRequested() {
        AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=stop-requested-before-native-input")
        return false
    }

    if advisorQuoteConsoleBridgeOpen {
        Send "^+j"
        if !SafeSleep(220) {
            AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=close-before-native-input-interrupted")
            return false
        }
        advisorQuoteConsoleBridgeOpen := false
    }

    if !FocusEdge() {
        AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=edge-refocus-failed")
        return false
    }
    if !WinActive("ahk_exe msedge.exe") {
        AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), "reason=edge-not-active-after-refocus")
        return false
    }

    advisorQuoteConsoleBridgeFocus := "page"
    AdvisorQuoteAppendLog("PAGE_REFOCUSED_FOR_NATIVE_INPUT", AdvisorQuoteGetLastStep(), "reason=" reason)
    return true
}

AdvisorQuoteExecuteBridgeJs(jsCode, expectResult := true) {
    global advisorQuoteConsoleBridgeFocus

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

        advisorQuoteConsoleBridgeFocus := "console"
        if !expectResult
            return true

        result := ""
        Loop 25 {
            if !SafeSleep(100)
                return ""
            if (A_Clipboard != sentCode && Trim(A_Clipboard) != "") {
                result := Trim(A_Clipboard)
                break
            }
        }
        return result
    } finally {
        A_Clipboard := savedClip
    }
}

AdvisorQuoteResetConsoleBridge() {
    global advisorQuoteConsoleBridgeOpen, advisorQuoteConsoleBridgeFocus
    advisorQuoteConsoleBridgeOpen := false
    advisorQuoteConsoleBridgeFocus := "page"
}

AdvisorQuoteMarkConsoleBridgeFocused() {
    global advisorQuoteConsoleBridgeOpen, advisorQuoteConsoleBridgeFocus
    advisorQuoteConsoleBridgeOpen := true
    advisorQuoteConsoleBridgeFocus := "console"
}

AdvisorQuoteInvalidateConsoleBridge(detail := "") {
    global advisorQuoteConsoleBridgeOpen, advisorQuoteConsoleBridgeFocus
    advisorQuoteConsoleBridgeOpen := false
    advisorQuoteConsoleBridgeFocus := "page"
    AdvisorQuoteAppendLog("DEVTOOLS_BRIDGE_FAILED", AdvisorQuoteGetLastStep(), detail)
}

AdvisorQuoteLogJsBridgeOp(op, args, attempt, attempts) {
    if (op = "wait_condition") {
        conditionName := ""
        if IsObject(args) && args.Has("name")
            conditionName := String(args["name"])
        AdvisorQuoteAppendLog("WAIT_POLL_JS", AdvisorQuoteGetLastStep(), "op=" op ", condition=" conditionName ", attempt=" attempt "/" attempts)
        return
    }

    if AdvisorQuoteIsJsActionOp(op)
        AdvisorQuoteAppendLog("ACTION_JS", AdvisorQuoteGetLastStep(), "op=" op ", attempt=" attempt "/" attempts)
}

AdvisorQuoteIsJsActionOp(op) {
    actionOps := [
        "click_by_id",
        "click_by_text",
        "click_product_overview_tile",
        "click_create_quotes_order_reports",
        "click_start_quoting_add_product",
        "handle_duplicate_prospect",
        "focus_prospect_first_input",
        "fill_gather_defaults",
        "confirm_potential_vehicle",
        "prepare_vehicle_row",
        "select_vehicle_dropdown_option",
        "ensure_auto_start_quoting_state",
        "set_select_product_defaults",
        "fill_participant_modal",
        "select_remove_reason",
        "fill_vehicle_modal",
        "handle_incidents"
    ]
    return AdvisorQuoteIsStateInList(String(op), actionOps)
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
    global advisorQuoteProductOverviewAutoPending
    AdvisorQuoteResetConsoleBridge()
    advisorQuoteProductOverviewAutoPending := false
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
    try FileDelete(latestPath)
    FileAppend(scanJson, latestPath, "UTF-8")

    stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss") . "_" . Format("{:03}", A_MSec)
    safeLabel := AdvisorQuoteSanitizeScanToken(label)
    safeReason := AdvisorQuoteSanitizeScanToken(reason)
    archivePath := logsRoot "\advisor_scan_" . stamp
    if (safeLabel != "")
        archivePath .= "_" . safeLabel
    if (safeReason != "")
        archivePath .= "_" . safeReason
    archivePath .= ".json"
    FileAppend(scanJson, archivePath, "UTF-8")
    return archivePath
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
