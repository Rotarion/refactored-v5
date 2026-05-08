; Advisor quote page-state helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

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

    handoffReachedSelectProduct := false
    if !AdvisorQuoteWaitForStartQuotingScopedHandoffReady(db, &afterStatus, &afterReason, &handoffReachedSelectProduct) {
        failureReason := "START_QUOTING_CREATE_QUOTES_DISABLED_AFTER_SCOPED_ADD_PRODUCT: " afterReason
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "start-quoting-create-quotes-still-disabled")
        AdvisorQuoteAppendLog(
            "GATHER_START_QUOTING_HANDOFF_FAILED",
            AdvisorQuoteGetLastStep(),
            "startQuotingHandoffPath=failed"
                . ", startQuotingScopedAddProductClicked=1"
                . ", startQuotingScopedAddProductResult=OK"
                . ", startQuotingCreateQuotesEnabledAfter=" (AdvisorQuoteStartQuotingCreateQuotesEnabled(afterStatus) ? "1" : "0")
                . ", handoffReachedSelectProduct=" (handoffReachedSelectProduct ? "1" : "0")
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
            . ", startQuotingCreateQuotesEnabledAfter=" (AdvisorQuoteStartQuotingCreateQuotesEnabled(afterStatus) ? "1" : "0")
            . ", handoffReachedSelectProduct=" (handoffReachedSelectProduct ? "1" : "0")
            . ", statusAfter=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(afterStatus)
    )
    return true
}

AdvisorQuoteWaitForStartQuotingScopedHandoffReady(db, &statusOut, &reasonOut := "", &handoffReachedSelectProduct := false) {
    start := A_TickCount
    timeoutMs := db["timeouts"]["transitionMs"]
    pollMs := db["timeouts"]["pollMs"]
    statusOut := Map()
    reasonOut := ""
    handoffReachedSelectProduct := false
    while ((A_TickCount - start) < timeoutMs) {
        if StopRequested() {
            reasonOut := "Stopped manually."
            return false
        }
        if AdvisorQuoteIsOnSelectProductPage(db) {
            handoffReachedSelectProduct := true
            reasonOut := "Scoped Start Quoting Add Product transitioned to Select Product."
            return true
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
        reasonOut := "Scoped Start Quoting Add product did not enable Create Quotes or transition to Select Product."
    return false
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
    applyStatus := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("ensure_select_product_defaults", applyArgs))
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
            . ", insuredQuestionAnswered=" AdvisorQuoteStatusValue(applyStatus, "insuredQuestionAnswered")
            . ", insuredQuestionRequired=" AdvisorQuoteStatusValue(applyStatus, "insuredQuestionRequired")
            . ", insuredControlType=" AdvisorQuoteStatusValue(applyStatus, "insuredControlType")
            . ", insuredDetectionMethod=" AdvisorQuoteStatusValue(applyStatus, "insuredDetectionMethod")
            . ", ownOrRentSet=" AdvisorQuoteStatusValue(applyStatus, "ownOrRentSet")
            . ", ownOrRentMethod=" AdvisorQuoteStatusValue(applyStatus, "ownOrRentMethod")
    )
    if (AdvisorQuoteStatusValue(applyStatus, "currentInsuredSet") = "1") {
        insuredMethod := AdvisorQuoteStatusValue(applyStatus, "currentInsuredMethod")
        if (insuredMethod != "" && insuredMethod != "already-selected")
            AdvisorQuoteAppendLog("SELECT_PRODUCT_CURRENTLY_INSURED_DEFAULTED_YES", AdvisorQuoteGetLastStep(), "method=" insuredMethod . ", controlType=" AdvisorQuoteStatusValue(applyStatus, "insuredControlType") . ", detectionMethod=" AdvisorQuoteStatusValue(applyStatus, "insuredDetectionMethod"))
    }

    status := AdvisorQuoteGetSelectProductStatus(db)
    AdvisorQuoteAppendLog("SELECT_PRODUCT_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildSelectProductStatusDetail(status))
    if !AdvisorQuoteSelectProductStatusValid(status, db, false, &failureReason) {
        failureScanPath := AdvisorQuoteScanCurrentPage("SELECT_PRODUCT", "select-product-defaults-invalid")
        AdvisorQuoteAppendLog("SELECT_PRODUCT_DEFAULTS_FAILED", AdvisorQuoteGetLastStep(), failureReason)
        return false
    }
    if (AdvisorQuoteStatusValue(status, "readinessTrace") = "SELECT_PRODUCT_CONTINUE_ENABLED_CORE_READY")
        AdvisorQuoteAppendLog("SELECT_PRODUCT_CONTINUE_ENABLED_CORE_READY", AdvisorQuoteGetLastStep(), "coreReady=" AdvisorQuoteStatusValue(status, "coreReady") . ", continueEnabled=" AdvisorQuoteStatusValue(status, "continueEnabled"))
    if (AdvisorQuoteStatusValue(status, "customControlAmbiguous") = "1")
        AdvisorQuoteAppendLog("SELECT_PRODUCT_CUSTOM_CONTROL_STATE_AMBIGUOUS_CONTINUING", AdvisorQuoteGetLastStep(), "insuredQuestionAnswered=" AdvisorQuoteStatusValue(status, "insuredQuestionAnswered") . ", ownOrRentSelected=" AdvisorQuoteStatusValue(status, "ownOrRentSelected"))

    clickStatus := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("click_select_product_continue", applyArgs, 1, 120))
    clickResult := AdvisorQuoteStatusValue(clickStatus, "result")
    if (AdvisorQuoteStatusValue(clickStatus, "readinessTrace") = "SELECT_PRODUCT_CLICK_CONTINUE_READY")
        AdvisorQuoteAppendLog("SELECT_PRODUCT_CLICK_CONTINUE_READY", AdvisorQuoteGetLastStep(), "clicked=" AdvisorQuoteStatusValue(clickStatus, "clicked") . ", continueEnabled=" AdvisorQuoteStatusValue(clickStatus, "continueEnabled"))
    AdvisorQuoteAppendLog("SELECT_PRODUCT_CONTINUE_CLICK", AdvisorQuoteGetLastStep(), "result=" clickResult . ", clicked=" AdvisorQuoteStatusValue(clickStatus, "clicked") . ", missing=" AdvisorQuoteStatusValue(clickStatus, "missing"))
    if (clickResult != "OK") {
        failureReason := clickResult
        if (failureReason = "")
            failureReason := "SELECT_PRODUCT_FALLBACK_NOT_READY"
        failureScanPath := AdvisorQuoteScanCurrentPage("SELECT_PRODUCT", "select-product-continue-refused")
        return false
    }

    waitArgs := Map(
        "ascProductContains", db["urls"]["ascProductContains"],
        "urls", db["urls"],
        "texts", db["texts"],
        "selectors", db["selectors"]
    )
    if AdvisorQuoteWaitForCondition("select_product_to_consumer", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
        return true
    if AdvisorQuoteWaitForCondition("is_asc", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs)
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
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily")
        . ", ratingStatePresent=" AdvisorQuoteStatusValue(status, "ratingStatePresent")
        . ", ratingStateSelected=" AdvisorQuoteStatusValue(status, "ratingStateSelected")
        . ", ratingStateValue=" AdvisorQuoteStatusValue(status, "ratingStateValue")
        . ", productPresent=" AdvisorQuoteStatusValue(status, "productPresent")
        . ", productSelected=" AdvisorQuoteStatusValue(status, "productSelected")
        . ", productValue=" AdvisorQuoteStatusValue(status, "productValue")
        . ", autoSelected=" AdvisorQuoteStatusValue(status, "autoSelected")
        . ", effectiveDatePresent=" AdvisorQuoteStatusValue(status, "effectiveDatePresent")
        . ", effectiveDateFilled=" AdvisorQuoteStatusValue(status, "effectiveDateFilled")
        . ", currentAddressPresent=" AdvisorQuoteStatusValue(status, "currentAddressPresent")
        . ", currentAddressSelected=" AdvisorQuoteStatusValue(status, "currentAddressSelected")
        . ", insuredQuestionPresent=" AdvisorQuoteStatusValue(status, "insuredQuestionPresent")
        . ", insuredYesPresent=" AdvisorQuoteStatusValue(status, "insuredYesPresent")
        . ", insuredNoPresent=" AdvisorQuoteStatusValue(status, "insuredNoPresent")
        . ", insuredYesSelected=" AdvisorQuoteStatusValue(status, "insuredYesSelected")
        . ", insuredNoSelected=" AdvisorQuoteStatusValue(status, "insuredNoSelected")
        . ", insuredQuestionAnswered=" AdvisorQuoteStatusValue(status, "insuredQuestionAnswered")
        . ", insuredQuestionRequired=" AdvisorQuoteStatusValue(status, "insuredQuestionRequired")
        . ", insuredControlType=" AdvisorQuoteStatusValue(status, "insuredControlType")
        . ", insuredDetectionMethod=" AdvisorQuoteStatusValue(status, "insuredDetectionMethod")
        . ", ownOrRentSelected=" AdvisorQuoteStatusValue(status, "ownOrRentSelected")
        . ", continuePresent=" AdvisorQuoteStatusValue(status, "continuePresent")
        . ", continueEnabled=" AdvisorQuoteStatusValue(status, "continueEnabled")
        . ", coreReady=" AdvisorQuoteStatusValue(status, "coreReady")
        . ", customControlAmbiguous=" AdvisorQuoteStatusValue(status, "customControlAmbiguous")
        . ", readinessTrace=" AdvisorQuoteStatusValue(status, "readinessTrace")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
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
        failureReason := "SELECT_PRODUCT_FALLBACK_NOT_READY"
        return false
    }
    result := AdvisorQuoteStatusValue(status, "result")
    if (result = "READY")
        return true
    if (result != "") {
        if (result = "SELECT_PRODUCT_CONTINUE_DISABLED")
            failureReason := "SELECT_PRODUCT_CONTINUE_DISABLED"
        else if (result = "SELECT_PRODUCT_CORE_REQUIRED_FIELDS_MISSING")
            failureReason := "SELECT_PRODUCT_CORE_REQUIRED_FIELDS_MISSING"
        else
            failureReason := result
        return false
    }
    missing := AdvisorQuoteStatusValue(status, "missing")
    if InStr(missing, "continueEnabled")
        failureReason := "SELECT_PRODUCT_CONTINUE_DISABLED"
    else if (missing != "")
        failureReason := "SELECT_PRODUCT_CORE_REQUIRED_FIELDS_MISSING"
    else
        failureReason := "SELECT_PRODUCT_FALLBACK_NOT_READY"
    return false
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

