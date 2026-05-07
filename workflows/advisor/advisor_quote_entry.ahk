; Advisor quote page-state helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

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

