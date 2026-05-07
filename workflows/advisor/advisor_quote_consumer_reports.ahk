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

