; Advisor quote page-state helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

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

