; Advisor quote page-state helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

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

AdvisorQuoteIsDriversVehiclesState(db) {
    return AdvisorQuoteWaitForCondition("drivers_or_incidents", 500, 150, AdvisorQuoteAscWaitArgs(db)) && !AdvisorQuoteIsIncidentsPage(db)
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

AdvisorQuoteTryRouteConsumerReportsAscProduct(profile, db, observedState, entryScanPath, &failureReason := "", &failureScan := "", insuranceGateDepth := 0) {
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

    insuranceGateRouteResult := AdvisorQuoteTryRouteRecognizedAscInsuranceGate(profile, db, entryScanPath, &failureReason, &failureScan, insuranceGateDepth)
    if (insuranceGateRouteResult != "CONTINUE")
        return insuranceGateRouteResult

    failureReason := "ASC_PRODUCT_SUBSTATE_UNKNOWN"
    failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "asc-product-substate-unknown")
    return "FAILED"
}

AdvisorQuoteTryRouteRecognizedAscInsuranceGate(profile, db, entryScanPath, &failureReason := "", &failureScan := "", insuranceGateDepth := 0) {
    global advisorQuoteRequiresClientVerification
    failureReason := ""
    failureScan := ""
    if (insuranceGateDepth >= 3) {
        failureReason := "ASC_INSURANCE_GATE_LOOP_GUARD"
        failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "asc-insurance-gate-loop-guard")
        return "FAILED"
    }

    snapshotRaw := Trim(String(AdvisorQuoteRunJsOpFullInjection("advisor_state_snapshot", Map("source", "asc-insurance-gate-router"), 1, 0)))
    route := AdvisorQuoteExtractJsonString(snapshotRaw, "route")
    gateKind := AdvisorQuoteExtractJsonString(snapshotRaw, "kind")
    if (route = "PURCHASE" && advisorQuoteRequiresClientVerification = true) {
        failureReason := "ASC_PURCHASE_BLOCKED_PENDING_CLIENT_VERIFICATION"
        failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "purchase-blocked-client-verification")
        AdvisorQuoteAppendLog("ASC_PURCHASE_BLOCKED_PENDING_CLIENT_VERIFICATION", AdvisorQuoteGetLastStep(), "requiresClientVerification=1")
        return "FAILED"
    }
    if !AdvisorQuoteIsStateInList(route, ["ASC_CREDIT_HIT_NOT_RECEIVED", "ASC_EXTRA_INFO_INSURANCE", "ASC_PRIOR_INSURANCE_NOT_FOUND"])
        return "CONTINUE"

    AdvisorQuoteAppendLog(
        "ASC_INSURANCE_GATE_STATUS",
        AdvisorQuoteGetLastStep(),
        "route=" route
            . ", insuranceGateKind=" gateKind
            . ", source=SYSTEM_DETECTED_GATE"
    )

    op := ""
    expectedResult := ""
    if (route = "ASC_CREDIT_HIT_NOT_RECEIVED" && gateKind = "CREDIT_HIT_NOT_RECEIVED") {
        op := "asc_credit_hit_not_received_continue"
        expectedResult := "ASC_CREDIT_HIT_NOT_RECEIVED_DETECTED"
    } else if (route = "ASC_EXTRA_INFO_INSURANCE" && gateKind = "EXTRA_INFO_INSURANCE") {
        op := "asc_extra_info_insurance_apply_provisional"
        expectedResult := "ASC_EXTRA_INFO_INSURANCE_PROVISIONAL_APPLIED"
    } else if (route = "ASC_PRIOR_INSURANCE_NOT_FOUND" && gateKind = "PRIOR_INSURANCE_NOT_FOUND") {
        op := "asc_prior_insurance_not_found_apply_provisional"
        expectedResult := "ASC_PRIOR_INSURANCE_NOT_FOUND_PROVISIONAL_APPLIED"
    } else {
        failureReason := "ASC_INSURANCE_GATE_UNKNOWN"
        failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "asc-insurance-gate-kind-mismatch")
        AdvisorQuoteAppendLog("ASC_INSURANCE_GATE_UNKNOWN", AdvisorQuoteGetLastStep(), "route=" route ", insuranceGateKind=" gateKind)
        return "FAILED"
    }

    result := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp(op, Map(), 2, 120))
    resultCode := AdvisorQuoteStatusValue(result, "result")
    AdvisorQuoteAppendLog(
        resultCode,
        AdvisorQuoteGetLastStep(),
        AdvisorQuoteBuildAscInsuranceGateResultDetail(result)
    )
    if (resultCode != expectedResult) {
        failureReason := resultCode != "" ? resultCode : "ASC_INSURANCE_GATE_UNSAFE_OR_AMBIGUOUS"
        failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "asc-insurance-gate-provisional-failed")
        return "FAILED"
    }

    if (route = "ASC_CREDIT_HIT_NOT_RECEIVED") {
        AdvisorQuoteMarkClientVerificationRequired("", "SYSTEM_DETECTED_GATE", true)
    } else {
        AdvisorQuoteMarkClientVerificationRequired(
            AdvisorQuoteStatusValue(result, "provisionalFields"),
            AdvisorQuoteStatusValue(result, "provisionalSource"),
            false
        )
    }
    AdvisorQuoteCaptureStateSnapshotObserver(StrLower(route) "_handled", Map(
        "route", route,
        "result", resultCode,
        "requiresClientVerification", "1",
        "creditHitNotReceived", (route = "ASC_CREDIT_HIT_NOT_RECEIVED") ? "1" : "0",
        "provisionalSource", AdvisorQuoteStatusValue(result, "provisionalSource"),
        "provisionalFields", AdvisorQuoteStatusValue(result, "provisionalFields")
    ))

    if !AdvisorQuoteWaitForCondition("gather_start_quoting_transition", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], AdvisorQuoteAscWaitArgs(db)) {
        failureReason := "ASC_INSURANCE_GATE_POST_CONTINUE_TIMEOUT"
        failureScan := AdvisorQuoteScanCurrentPage("CONSUMER_REPORTS", "asc-insurance-gate-post-continue-timeout")
        return "FAILED"
    }

    nextState := AdvisorQuoteDetectState(db)
    return AdvisorQuoteTryRouteConsumerReportsAscProduct(profile, db, nextState, entryScanPath, &failureReason, &failureScan, insuranceGateDepth + 1)
}

AdvisorQuoteBuildAscInsuranceGateResultDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", expectedRoute=" AdvisorQuoteStatusValue(status, "expectedRoute")
        . ", expectedKind=" AdvisorQuoteStatusValue(status, "expectedKind")
        . ", actualRoute=" AdvisorQuoteStatusValue(status, "actualRoute")
        . ", actualKind=" AdvisorQuoteStatusValue(status, "actualKind")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", source=" AdvisorQuoteStatusValue(status, "source")
        . ", requiresClientVerification=" AdvisorQuoteStatusValue(status, "requiresClientVerification")
        . ", creditHitNotReceived=" AdvisorQuoteStatusValue(status, "creditHitNotReceived")
        . ", provisionalSource=" AdvisorQuoteStatusValue(status, "provisionalSource")
        . ", provisionalFields=" AdvisorQuoteStatusValue(status, "provisionalFields")
        . ", readback=" AdvisorQuoteStatusValue(status, "readback")
        . ", continueVisible=" AdvisorQuoteStatusValue(status, "continueVisible")
        . ", continueEnabled=" AdvisorQuoteStatusValue(status, "continueEnabled")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
        . ", ambiguous=" AdvisorQuoteStatusValue(status, "ambiguous")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
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

