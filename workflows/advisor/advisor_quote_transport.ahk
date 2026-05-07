; Advisor quote JavaScript transport helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

AdvisorQuoteResidentOperatorVersion() {
    return "phase1"
}

AdvisorQuoteResidentOperatorBuildHash() {
    return "advisor-resident-operator-phase1-command-bus"
}

AdvisorQuoteResidentTransportEnabled() {
    global advisorQuoteUseResidentOperatorTransport
    return advisorQuoteUseResidentOperatorTransport = true
}

AdvisorQuoteResidentReadOnlyTransportEnabled() {
    global advisorQuoteResidentTransportReadOnlyEnabled
    return advisorQuoteResidentTransportReadOnlyEnabled = true
}

AdvisorQuoteResidentMutationTransportEnabled() {
    global advisorQuoteResidentTransportMutationEnabled
    return advisorQuoteResidentTransportMutationEnabled = true
}

AdvisorQuoteResidentReadOnlyStatusAllowlist() {
    return [
        "detect_state",
        "gather_rapport_snapshot",
        "gather_confirmed_vehicles_status",
        "gather_start_quoting_status",
        "gather_vehicle_add_status",
        "gather_vehicle_row_status",
        "gather_vehicle_edit_status",
        "product_overview_tile_status",
        "customer_summary_overview_status",
        "address_verification_status",
        "prospect_form_status"
    ]
}

AdvisorQuoteResidentReadOnlyWaitAllowlist() {
    return [
        "gather_data",
        "is_rapport",
        "duplicate_to_next",
        "vehicle_select_enabled"
    ]
}

AdvisorQuoteResidentMutationCandidateAllowlist() {
    return [
        "click_by_id",
        "click_by_text",
        "click_customer_summary_start_here",
        "click_product_overview_tile",
        "select_vehicle_dropdown_option",
        "prepare_vehicle_row",
        "confirm_potential_vehicle",
        "fill_gather_defaults",
        "fill_participant_modal"
    ]
}

AdvisorQuoteResidentWaitConditionName(args) {
    if IsObject(args) && args.Has("name")
        return Trim(String(args["name"]))
    if IsObject(args) && args.Has("conditionName")
        return Trim(String(args["conditionName"]))
    return ""
}

AdvisorQuoteResidentTransportOpKey(op, args := Map()) {
    opName := Trim(String(op ?? ""))
    if (opName = "wait_condition")
        return "wait_condition:" AdvisorQuoteResidentWaitConditionName(args)
    return opName
}

AdvisorQuoteResidentTransportReadOnlyCandidate(op, args := Map()) {
    opName := Trim(String(op ?? ""))
    if (opName = "wait_condition")
        return AdvisorQuoteIsStateInList(AdvisorQuoteResidentWaitConditionName(args), AdvisorQuoteResidentReadOnlyWaitAllowlist())
    return AdvisorQuoteIsStateInList(opName, AdvisorQuoteResidentReadOnlyStatusAllowlist())
}

AdvisorQuoteResidentTransportMutationCandidate(op, args := Map()) {
    opName := Trim(String(op ?? ""))
    return AdvisorQuoteIsStateInList(opName, AdvisorQuoteResidentMutationCandidateAllowlist())
}

AdvisorQuoteResidentTransportAdvisorContext(state) {
    stateName := AdvisorQuoteJsMetricSafeToken(state, "")
    if (stateName = "" || stateName = "INIT" || stateName = "UNKNOWN")
        return true
    return !AdvisorQuoteIsStateInList(stateName, ["GATEWAY", "NO_CONTEXT"])
}

AdvisorQuoteResidentTransportGate(op, args := Map(), state := "") {
    opName := Trim(String(op ?? ""))
    if !AdvisorQuoteResidentTransportEnabled()
        return Map("ok", "0", "reason", "resident-transport-disabled", "kind", "", "candidate", "0")
    if StopRequested()
        return Map("ok", "0", "reason", "stop-requested", "kind", "", "candidate", "0")

    if AdvisorQuoteResidentTransportMutationCandidate(opName, args) {
        if !AdvisorQuoteResidentMutationTransportEnabled()
            return Map("ok", "0", "reason", "mutation-disabled", "kind", "mutation", "candidate", "1", "mutationCandidate", "1")
        return Map("ok", "1", "reason", "", "kind", "mutation", "candidate", "1", "mutationCandidate", "1")
    }

    if !AdvisorQuoteResidentReadOnlyTransportEnabled()
        return Map("ok", "0", "reason", "resident-readonly-disabled", "kind", "read_only", "candidate", "0")
    if !AdvisorQuoteResidentTransportReadOnlyCandidate(opName, args)
        return Map("ok", "0", "reason", "not-allowlisted", "kind", "read_only", "candidate", "0")
    if !AdvisorQuoteResidentTransportAdvisorContext(state)
        return Map("ok", "0", "reason", "not-advisor-context", "kind", "read_only", "candidate", "1")
    return Map("ok", "1", "reason", "", "kind", "read_only", "candidate", "1", "mutationCandidate", "0")
}

AdvisorQuoteResidentTraceDetail(op, args := Map(), suffix := "") {
    opName := AdvisorQuoteJsMetricSafeToken(op, "unknown")
    detail := "op=" opName
        . ", opKey=" AdvisorQuoteJsMetricSafeToken(AdvisorQuoteResidentTransportOpKey(opName, args), "unknown")
        . ", category=" AdvisorQuoteJsMetricCategory(opName)
    if (opName = "wait_condition")
        detail .= ", waitConditionName=" AdvisorQuoteJsMetricSafeToken(AdvisorQuoteResidentWaitConditionName(args), "")
    if (suffix != "")
        detail .= ", " suffix
    return detail
}

AdvisorQuoteResidentRequestId(op) {
    return "resident-" AdvisorQuoteJsMetricSafeToken(op, "op") "-" A_TickCount
}


AdvisorQuoteResidentRouteFamily(state := "", status := "") {
    stateName := AdvisorQuoteJsMetricSafeToken(state, "")
    if IsObject(status) {
        routeFamily := AdvisorQuoteJsMetricSafeToken(AdvisorQuoteStatusValue(status, "routeFamily"), "")
        detectedState := AdvisorQuoteJsMetricSafeToken(AdvisorQuoteStatusValue(status, "detectedState"), "")
        url := StrLower(AdvisorQuoteStatusValue(status, "url"))
        if (routeFamily != "") {
            routeLower := StrLower(routeFamily)
            if InStr(routeLower, "ascproduct") || InStr(url, "/apps/ascproduct/") {
                if InStr(detectedState, "DRIVERS") || InStr(detectedState, "VEHICLES")
                    return "ascproduct-drivers-vehicles"
                if InStr(detectedState, "INCIDENT")
                    return "ascproduct-incidents"
                if InStr(detectedState, "COVERAGE") || InStr(detectedState, "DRIVEWISE")
                    return "ascproduct-coverages"
                if InStr(detectedState, "QUOTE")
                    return "ascproduct-quote"
                return "ascproduct-unknown"
            }
            if InStr(routeLower, "select")
                return "intel-select-product"
            if InStr(routeLower, "rapport") || InStr(routeLower, "gather")
                return "intel-rapport"
            if InStr(routeLower, "customer")
                return "customer-summary"
            if InStr(routeLower, "product")
                return "product-overview"
        }
        if InStr(url, "/apps/intel/") && InStr(url, "/rapport")
            return "intel-rapport"
        if InStr(url, "/apps/intel/") && InStr(url, "/selectproduct")
            return "intel-select-product"
        if InStr(url, "/apps/customer-summary/")
            return "customer-summary"
        if InStr(url, "/apps/product") || InStr(url, "productoverview")
            return "product-overview"
    }

    if InStr(stateName, "ASC_PRODUCT") || InStr(stateName, "ASCPRODUCT") {
        if InStr(stateName, "DRIVER") || InStr(stateName, "VEHICLE")
            return "ascproduct-drivers-vehicles"
        if InStr(stateName, "INCIDENT")
            return "ascproduct-incidents"
        if InStr(stateName, "COVERAGE") || InStr(stateName, "DRIVEWISE")
            return "ascproduct-coverages"
        if InStr(stateName, "QUOTE")
            return "ascproduct-quote"
        return "ascproduct-unknown"
    }
    if InStr(stateName, "SELECT_PRODUCT")
        return "intel-select-product"
    if InStr(stateName, "RAPPORT") || InStr(stateName, "GATHER")
        return "intel-rapport"
    if InStr(stateName, "CUSTOMER_SUMMARY")
        return "customer-summary"
    if InStr(stateName, "PRODUCT_OVERVIEW")
        return "product-overview"
    return "unknown"
}

AdvisorQuoteBuildResidentOperatorHealthArgs(routeFamily := "") {
    return Map(
        "command", "health",
        "version", AdvisorQuoteResidentOperatorVersion(),
        "buildHash", AdvisorQuoteResidentOperatorBuildHash(),
        "__residentExpectedBuildHash", AdvisorQuoteResidentOperatorBuildHash(),
        "__residentExpectedHost", "advisorpro",
        "__residentExpectedRouteFamily", AdvisorQuoteJsMetricSafeToken(routeFamily, "unknown")
    )
}

AdvisorQuoteBuildResidentHealthCheckJs(routeFamily := "") {
    argLiteral := JsLiteral(AdvisorQuoteBuildResidentOperatorHealthArgs(routeFamily))
    return "copy(String((() => { try { const h = (typeof globalThis !== 'undefined') ? globalThis : window; const r = h && h.__advisorQuoteResidentOperator; const pageUrl = String(location && location.href || ''); const route = pageUrl.includes('/apps/ASCPRODUCT/') ? 'ASCPRODUCT' : (pageUrl.toLowerCase().includes('/selectproduct') ? 'SELECT_PRODUCT' : (pageUrl.toLowerCase().includes('/rapport') ? 'RAPPORT' : 'UNKNOWN')); if (!r || typeof r.status !== 'function') return 'result=MISSING\nblockedReason=missing-resident-operator\nversion=\nbuildHash=\nurl=' + pageUrl + '\nrouteFamily=' + route + '\ndetectedState=UNKNOWN\nrequestCount=0'; return Object.entries(r.status(" argLiteral ")).map(([k,v]) => k + '=' + String(v == null ? '' : v).replace(/[\r\n]+/g, ' ')).join('\n'); } catch (e) { return 'result=ERROR\nblockedReason=js-error\nmessage=' + String(e && e.message || e); } })()))"
}

AdvisorQuoteResidentHealthCheck(routeFamily := "", step := "") {
    logStep := Trim(String(step ?? "")) != "" ? step : AdvisorQuoteGetLastStep()
    requestedRoute := AdvisorQuoteJsMetricSafeToken(routeFamily, "unknown")
    AdvisorQuoteRecordResidentRouteMetric("health_attempt", requestedRoute, "", false)
    AdvisorQuoteAppendLog("ADVISOR_RESIDENT_ROUTE_HEALTH_ATTEMPT", logStep, "routeFamily=" requestedRoute)

    raw := AdvisorQuoteExecuteResidentTinyJs(AdvisorQuoteBuildResidentHealthCheckJs(requestedRoute), 1200)
    status := AdvisorQuoteParseKeyValueLines(raw)
    observedRoute := AdvisorQuoteResidentRouteFamily(logStep, status)
    if (observedRoute = "")
        observedRoute := requestedRoute
    result := AdvisorQuoteStatusValue(status, "result")
    fallbackReason := AdvisorQuoteResidentFallbackReason(status)

    if (result = "OK") {
        AdvisorQuoteRecordResidentRouteMetric("health_success", observedRoute, "", true)
        AdvisorQuoteAppendLog("ADVISOR_RESIDENT_ROUTE_HEALTH_OK", logStep, "routeFamily=" observedRoute ", requestCount=" AdvisorQuoteStatusValue(status, "requestCount"))
        return Map("ok", "1", "result", result, "routeFamily", observedRoute, "status", status, "fallbackReason", "")
    }

    AdvisorQuoteRecordResidentRouteMetric("health_fallback", observedRoute, fallbackReason, true)
    eventName := (result = "MISSING") ? "ADVISOR_RESIDENT_ROUTE_HEALTH_MISSING" : "ADVISOR_RESIDENT_ROUTE_HEALTH_STALE"
    AdvisorQuoteAppendLog(eventName, logStep, "routeFamily=" observedRoute ", result=" (result = "" ? "EMPTY" : result) ", fallbackReason=" fallbackReason)
    return Map("ok", "0", "result", (result = "" ? "EMPTY" : result), "routeFamily", observedRoute, "status", status, "fallbackReason", fallbackReason)
}

AdvisorQuoteEnsureResidentForRoute(routeFamily := "", step := "") {
    global advisorQuoteResidentOperatorBootstrapped, advisorQuoteResidentContextRouteFamily
    logStep := Trim(String(step ?? "")) != "" ? step : AdvisorQuoteGetLastStep()
    requestedRoute := AdvisorQuoteJsMetricSafeToken(routeFamily, AdvisorQuoteResidentRouteFamily(logStep))
    if (requestedRoute = "")
        requestedRoute := "unknown"

    health := AdvisorQuoteResidentHealthCheck(requestedRoute, logStep)
    observedRoute := AdvisorQuoteStatusValue(health, "routeFamily")
    if (observedRoute = "")
        observedRoute := requestedRoute

    if (AdvisorQuoteStatusValue(health, "ok") = "1") {
        advisorQuoteResidentOperatorBootstrapped := true
        advisorQuoteResidentContextRouteFamily := observedRoute
        AdvisorQuoteRecordResidentRouteMetric("route_reuse", observedRoute, "", true)
        AdvisorQuoteAppendLog("ADVISOR_RESIDENT_ROUTE_REUSE", logStep, "routeFamily=" observedRoute)
        return true
    }

    advisorQuoteResidentOperatorBootstrapped := false
    AdvisorQuoteRecordResidentRouteMetric("route_bootstrap", observedRoute, AdvisorQuoteStatusValue(health, "fallbackReason"), false)
    AdvisorQuoteAppendLog("ADVISOR_RESIDENT_ROUTE_BOOTSTRAP", logStep, "routeFamily=" observedRoute ", fallbackReason=" AdvisorQuoteStatusValue(health, "fallbackReason"))
    ok := AdvisorQuoteEnsureResidentOperator(logStep)
    if ok {
        advisorQuoteResidentContextRouteFamily := observedRoute
        AdvisorQuoteRecordResidentRouteMetric("route_bootstrap_success", observedRoute, "", true)
    } else {
        AdvisorQuoteRecordResidentRouteMetric("route_bootstrap_fallback", observedRoute, "bootstrap-failed", true)
    }
    return ok
}

AdvisorQuoteBuildResidentOperatorBootstrapArgs() {
    return Map(
        "command", "bootstrap",
        "version", AdvisorQuoteResidentOperatorVersion(),
        "buildHash", AdvisorQuoteResidentOperatorBuildHash(),
        "replaceStale", "1"
    )
}

AdvisorQuoteEnsureResidentOperator(step := "") {
    global advisorQuoteResidentOperatorBootstrapped
    if (advisorQuoteResidentOperatorBootstrapped = true)
        return true

    logStep := Trim(String(step ?? "")) != "" ? step : AdvisorQuoteGetLastStep()
    AdvisorQuoteRecordResidentBootstrapMetric("attempt", "", false)
    AdvisorQuoteAppendLog(
        "ADVISOR_RESIDENT_BOOTSTRAP_ATTEMPT",
        logStep,
        "version=" AdvisorQuoteResidentOperatorVersion() ", buildHash=" AdvisorQuoteResidentOperatorBuildHash()
    )

    raw := AdvisorQuoteRunJsOpFullInjection("resident_operator_bootstrap", AdvisorQuoteBuildResidentOperatorBootstrapArgs(), 2, 120)
    status := AdvisorQuoteParseKeyValueLines(raw)
    result := AdvisorQuoteStatusValue(status, "result")
    ok := result = "OK" || result = "ALREADY_BOOTSTRAPPED" || result = "STALE_REPLACED"
    if ok {
        advisorQuoteResidentOperatorBootstrapped := true
        AdvisorQuoteRecordResidentBootstrapMetric("success", "", true)
        AdvisorQuoteAppendLog(
            "ADVISOR_RESIDENT_BOOTSTRAP_OK",
            logStep,
            "result=" result
                . ", version=" AdvisorQuoteStatusValue(status, "version")
                . ", buildHash=" AdvisorQuoteStatusValue(status, "buildHash")
                . ", readOnlyStatusOpCount=" AdvisorQuoteStatusValue(status, "readOnlyStatusOpCount")
                . ", readOnlyWaitConditionCount=" AdvisorQuoteStatusValue(status, "readOnlyWaitConditionCount")
                . ", mutationOpCount=" AdvisorQuoteStatusValue(status, "mutationOpCount")
        )
        return true
    }

    advisorQuoteResidentOperatorBootstrapped := false
    fallbackReason := result = "" ? "empty-result" : AdvisorQuoteResidentFallbackReason(status)
    AdvisorQuoteRecordResidentBootstrapMetric("fallback", fallbackReason, true)
    AdvisorQuoteAppendLog(
        "ADVISOR_RESIDENT_BOOTSTRAP_FAILED",
        logStep,
        "result=" (result = "" ? "EMPTY" : result) ", fallbackReason=" fallbackReason
    )
    return false
}

AdvisorQuoteBuildResidentTinyCommandArgs(args := Map()) {
    return AdvisorQuoteMergeArgs(args, Map(
        "__residentExpectedBuildHash", AdvisorQuoteResidentOperatorBuildHash(),
        "__residentExpectedHost", "advisorpro",
        "__residentMutationEnabled", AdvisorQuoteResidentMutationTransportEnabled() ? "1" : "0"
    ))
}

AdvisorQuoteBuildResidentTinyCommandJs(op, args := Map(), requestId := "") {
    opLiteral := JsLiteral(Trim(String(op ?? "")))
    argLiteral := JsLiteral(args)
    requestLiteral := JsLiteral(requestId)
    return "copy(String((() => { try { const h = (typeof globalThis !== 'undefined') ? globalThis : window; const r = h && h.__advisorQuoteResidentOperator; if (!r || typeof r.run !== 'function') return 'result=MISSING\nblockedReason=missing-resident-operator\nreason=no-resident-operator'; return r.run(" opLiteral ", " argLiteral ", " requestLiteral "); } catch (e) { return 'result=ERROR\nblockedReason=js-error\nmessage=' + String(e && e.message || e); } })()))"
}

AdvisorQuoteExecuteResidentTinyJs(js, timeoutMs := 1500) {
    if StopRequested()
        return ""
    if !AdvisorQuoteEnsureConsoleBridge() {
        AdvisorQuoteAppendLog("ADVISOR_RESIDENT_OP_FALLBACK", AdvisorQuoteGetLastStep(), "fallbackReason=ensure-console-failed")
        return ""
    }
    result := Trim(String(AdvisorQuoteExecuteBridgeJs(js, true, timeoutMs)))
    if (result != "") {
        AdvisorQuoteMarkConsoleBridgeFocused()
        return result
    }
    AdvisorQuoteInvalidateConsoleBridge("resident-tiny-command-empty")
    return ""
}

AdvisorQuoteResidentFailureResult(result) {
    return AdvisorQuoteIsStateInList(String(result ?? ""), ["MISSING", "STALE", "STALE_BUILD", "WRONG_CONTEXT", "REFUSED", "ERROR", "EMPTY", "TIMEOUT", "STOPPED", "STOP_REQUESTED"])
}

AdvisorQuoteResidentPayloadValid(op, payload) {
    opName := Trim(String(op ?? ""))
    text := Trim(String(payload ?? ""))
    if (text = "")
        return false
    parsed := AdvisorQuoteParseKeyValueLines(text)
    if IsObject(parsed) && parsed.Count > 0 {
        result := AdvisorQuoteStatusValue(parsed, "result")
        if AdvisorQuoteResidentFailureResult(result)
            return false
        if (opName = "wait_condition")
            return false
        return true
    }
    if (opName = "wait_condition")
        return text = "0" || text = "1"
    if (opName = "detect_state")
        return RegExMatch(text, "^[A-Z0-9_]+$") ? true : false
    return false
}

AdvisorQuoteResidentFallbackReason(status) {
    if (!IsObject(status) || (status.Count = 0))
        return "empty-result"
    result := AdvisorQuoteStatusValue(status, "result")
    blockedReason := AdvisorQuoteStatusValue(status, "blockedReason")
    reason := AdvisorQuoteStatusValue(status, "reason")
    if (result = "MISSING")
        return "missing-resident-operator"
    if (result = "STALE" || result = "STALE_BUILD")
        return "stale-build"
    if (result = "WRONG_CONTEXT")
        return "wrong-context"
    if (result = "REFUSED")
        return blockedReason != "" ? blockedReason : (reason != "" ? reason : "refused-op")
    if (result = "ERROR")
        return blockedReason != "" ? blockedReason : "js-error"
    if (result = "EMPTY")
        return "empty-result"
    if (result = "TIMEOUT")
        return "timeout"
    if (result = "STOPPED" || result = "STOP_REQUESTED")
        return "stop-requested"
    return "invalid-result-shape"
}

AdvisorQuoteRunOpViaResidentTransport(op, args := Map(), state := "") {
    global advisorQuoteResidentOperatorBootstrapped
    opName := Trim(String(op ?? ""))
    step := Trim(String(state ?? "")) != "" ? state : AdvisorQuoteGetLastStep()
    gate := AdvisorQuoteResidentTransportGate(opName, args, step)
    gateOk := AdvisorQuoteStatusValue(gate, "ok") = "1"
    gateReason := AdvisorQuoteStatusValue(gate, "reason")
    kind := AdvisorQuoteStatusValue(gate, "kind")

    if !gateOk {
        if (gateReason = "mutation-disabled") {
            AdvisorQuoteRecordResidentMutationMetric(opName, args, "fallback", "mutation-disabled", true)
            AdvisorQuoteAppendLog(
                "ADVISOR_RESIDENT_MUTATION_DISABLED",
                step,
                AdvisorQuoteResidentTraceDetail(opName, args, "fallbackReason=mutation-disabled")
            )
        }
        return AdvisorQuoteRunnerNotUsed(gateReason)
    }

    routeFamily := AdvisorQuoteResidentRouteFamily(step)
    if !AdvisorQuoteEnsureResidentForRoute(routeFamily, step) {
        AdvisorQuoteRecordResidentTinyCommandMetric(opName, args, 0, "fallback", "bootstrap-failed", true)
        if (kind = "mutation")
            AdvisorQuoteRecordResidentMutationMetric(opName, args, "fallback", "bootstrap-failed", true)
        AdvisorQuoteAppendLog(
            "ADVISOR_RESIDENT_OP_FALLBACK",
            step,
            AdvisorQuoteResidentTraceDetail(opName, args, "fallbackReason=bootstrap-failed")
        )
        return AdvisorQuoteRunnerNotUsed("bootstrap-failed")
    }

    residentArgs := AdvisorQuoteBuildResidentTinyCommandArgs(args)
    requestId := AdvisorQuoteResidentRequestId(opName)
    js := AdvisorQuoteBuildResidentTinyCommandJs(opName, residentArgs, requestId)
    payloadLength := StrLen(js)
    start := A_TickCount
    AdvisorQuoteRecordResidentTinyCommandMetric(opName, args, payloadLength, "attempt", "", false)
    AdvisorQuoteRecordResidentRouteMetric("tiny_attempt", routeFamily, "", false)
    if (kind = "mutation")
        AdvisorQuoteRecordResidentMutationMetric(opName, args, "attempt", "", false)
    AdvisorQuoteAppendLog(
        "ADVISOR_RESIDENT_OP_ATTEMPT",
        step,
        AdvisorQuoteResidentTraceDetail(opName, args, "requestId=" requestId ", payloadLength=" payloadLength ", kind=" kind)
    )

    raw := AdvisorQuoteExecuteResidentTinyJs(js, 1500)
    elapsed := A_TickCount - start
    status := AdvisorQuoteParseKeyValueLines(raw)

    if AdvisorQuoteResidentPayloadValid(opName, raw) {
        AdvisorQuoteRecordResidentTinyCommandMetric(opName, args, payloadLength, "success", "", true)
        AdvisorQuoteRecordResidentRouteMetric("tiny_success", routeFamily, "", false)
        if (kind = "mutation")
            AdvisorQuoteRecordResidentMutationMetric(opName, args, "success", "", true)
        AdvisorQuoteAppendLog(
            "ADVISOR_RESIDENT_OP_OK",
            step,
            AdvisorQuoteResidentTraceDetail(opName, args, "requestId=" requestId ", payloadLength=" payloadLength ", resultLength=" StrLen(String(raw ?? "")) ", elapsedMs=" elapsed)
        )
        return AdvisorQuoteRunnerUsedResult(raw, Map("result", "OK", "requestId", requestId, "transport", "resident"))
    }

    fallbackReason := AdvisorQuoteResidentFallbackReason(status)
    result := AdvisorQuoteStatusValue(status, "result")
    if (fallbackReason = "stale-build") {
        advisorQuoteResidentOperatorBootstrapped := false
        AdvisorQuoteAppendLog(
            "ADVISOR_RESIDENT_STALE_BUILD",
            step,
            AdvisorQuoteResidentTraceDetail(opName, args, "requestId=" requestId ", buildHash=" AdvisorQuoteStatusValue(status, "buildHash"))
        )
    } else if (fallbackReason = "wrong-context") {
        AdvisorQuoteAppendLog(
            "ADVISOR_RESIDENT_WRONG_CONTEXT",
            step,
            AdvisorQuoteResidentTraceDetail(opName, args, "requestId=" requestId ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily") ", detectedState=" AdvisorQuoteStatusValue(status, "detectedState"))
        )
    }

    AdvisorQuoteRecordResidentTinyCommandMetric(opName, args, payloadLength, "fallback", fallbackReason, true)
    AdvisorQuoteRecordResidentRouteMetric("tiny_fallback", routeFamily, fallbackReason, false)
    if (kind = "mutation")
        AdvisorQuoteRecordResidentMutationMetric(opName, args, "fallback", fallbackReason, true)
    AdvisorQuoteAppendLog(
        "ADVISOR_RESIDENT_OP_FALLBACK",
        step,
        AdvisorQuoteResidentTraceDetail(opName, args, "requestId=" requestId ", result=" (result = "" ? "EMPTY" : result) ", fallbackReason=" fallbackReason ", elapsedMs=" elapsed)
    )
    return AdvisorQuoteRunnerNotUsed(fallbackReason, status)
}

AdvisorQuoteResidentRunnerEnabled() {
    global advisorQuoteResidentRunnerFeatureEnabled
    return advisorQuoteResidentRunnerFeatureEnabled = true
}

AdvisorQuoteResidentRunnerVersion() {
    return "phase2"
}

AdvisorQuoteResidentRunnerBuildHash() {
    return "advisor-resident-runner-phase2-tiny-bridge"
}

AdvisorQuoteRunnerBuildCommandArgs(command, args := Map()) {
    commandArgs := Map(
        "command", command,
        "version", AdvisorQuoteResidentRunnerVersion(),
        "buildHash", AdvisorQuoteResidentRunnerBuildHash()
    )
    if IsObject(args) {
        for key, value in args
            commandArgs[String(key)] := value
    }
    if !commandArgs.Has("expectedBuildHash")
        commandArgs["expectedBuildHash"] := AdvisorQuoteResidentRunnerBuildHash()
    return commandArgs
}

AdvisorQuoteRunnerCommand(command, args := Map(), eventName := "") {
    if (eventName = "")
        eventName := "ADVISOR_RUNNER_" StrUpper(command)
    if !AdvisorQuoteResidentRunnerEnabled() {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_FALLBACK", AdvisorQuoteGetLastStep(), "command=" command ", reason=feature-disabled")
        return Map("result", "DISABLED", "command", command)
    }
    if StopRequested() {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_FALLBACK", AdvisorQuoteGetLastStep(), "command=" command ", reason=stop-requested")
        return Map("result", "STOP_REQUESTED", "command", command)
    }
    global advisorQuoteResidentRunnerUseTinyBridge
    if (command != "bootstrap" && advisorQuoteResidentRunnerUseTinyBridge = true)
        return AdvisorQuoteRunnerTinyCommand(command, args, eventName)
    return AdvisorQuoteRunnerFullCommand(command, args, eventName)
}

AdvisorQuoteRunnerFullCommand(command, args := Map(), eventName := "") {
    raw := AdvisorQuoteRunOp("resident_runner_command", AdvisorQuoteRunnerBuildCommandArgs(command, args), 2, 120)
    status := AdvisorQuoteParseKeyValueLines(raw)
    if (status.Count = 0) {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_FALLBACK", AdvisorQuoteGetLastStep(), "command=" command ", reason=empty-result")
        return Map("result", "EMPTY", "command", command)
    }
    AdvisorQuoteAppendLog(
        eventName,
        AdvisorQuoteGetLastStep(),
        "command=" command
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily")
            . ", detectedState=" AdvisorQuoteStatusValue(status, "detectedState")
            . ", eventSeq=" AdvisorQuoteStatusValue(status, "eventSeq")
    )
    return status
}

AdvisorQuoteRunnerTinyCommand(command, args := Map(), eventName := "") {
    commandArgs := AdvisorQuoteRunnerBuildCommandArgs(command, args)
    js := AdvisorQuoteBuildTinyRunnerCommandJs(commandArgs)
    payloadLength := StrLen(js)
    start := A_TickCount
    AdvisorQuoteAppendLog("ADVISOR_RUNNER_TINY_PAYLOAD", AdvisorQuoteGetLastStep(), "command=" command ", payloadLength=" payloadLength)
    raw := AdvisorQuoteExecuteTinyRunnerJs(js, 1500)
    elapsed := A_TickCount - start
    resultLength := StrLen(String(raw ?? ""))
    status := AdvisorQuoteParseKeyValueLines(raw)
    if (status.Count = 0)
        status := Map("result", "EMPTY", "command", command, "fallbackReason", "empty-result")
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_TINY_RESULT",
        AdvisorQuoteGetLastStep(),
        "command=" command
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", payloadLength=" payloadLength
            . ", resultLength=" resultLength
            . ", elapsedMs=" elapsed
            . ", runnerPresent=" (AdvisorQuoteStatusValue(status, "result") = "MISSING" ? "0" : "1")
            . ", buildHash=" AdvisorQuoteStatusValue(status, "buildHash")
            . ", url=" AdvisorQuoteStatusValue(status, "url")
    )
    if (AdvisorQuoteStatusValue(status, "result") = "EMPTY") {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_TINY_FALLBACK", AdvisorQuoteGetLastStep(), "command=" command ", fallbackReason=empty-result")
        return status
    }
    AdvisorQuoteAppendLog(
        eventName,
        AdvisorQuoteGetLastStep(),
        "command=" command
            . ", result=" AdvisorQuoteStatusValue(status, "result")
            . ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily")
            . ", detectedState=" AdvisorQuoteStatusValue(status, "detectedState")
            . ", eventSeq=" AdvisorQuoteStatusValue(status, "eventSeq")
    )
    return status
}

AdvisorQuoteBuildTinyRunnerCommandJs(commandArgs) {
    argLiteral := JsLiteral(commandArgs)
    return "copy(String((() => { try { const h = (typeof globalThis !== 'undefined') ? globalThis : window; const r = h && h.__advisorRunner; if (!r || typeof r.handleTinyCommand !== 'function') return 'result=MISSING\nreason=no-runner'; return r.handleTinyCommand(" argLiteral "); } catch (e) { return 'result=ERROR\nmessage=' + String(e && e.message || e); } })()))"
}

AdvisorQuoteExecuteTinyRunnerJs(js, timeoutMs := 1500) {
    if StopRequested()
        return ""
    if !AdvisorQuoteEnsureConsoleBridge() {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_TINY_FALLBACK", AdvisorQuoteGetLastStep(), "command=tiny-js, fallbackReason=ensure-console-failed")
        return ""
    }
    result := Trim(String(AdvisorQuoteExecuteBridgeJs(js, true, timeoutMs)))
    if (result != "") {
        AdvisorQuoteMarkConsoleBridgeFocused()
        return result
    }
    AdvisorQuoteInvalidateConsoleBridge("tiny-runner-command-empty")
    return ""
}

AdvisorQuoteEnsureResidentRunner() {
    status := AdvisorQuoteRunnerCommand("bootstrap", Map("replaceStale", "1"), "ADVISOR_RUNNER_BOOTSTRAP")
    result := AdvisorQuoteStatusValue(status, "result")
    if (result = "STALE_REPLACED")
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_REBOOTSTRAP", AdvisorQuoteGetLastStep(), "result=STALE_REPLACED, runnerId=" AdvisorQuoteStatusValue(status, "runnerId"))
    return result = "OK" || result = "ALREADY_BOOTSTRAPPED" || result = "STALE_REPLACED"
}

AdvisorQuoteRunnerStatus() {
    return AdvisorQuoteRunnerCommand("status", Map(), "ADVISOR_RUNNER_STATUS")
}

AdvisorQuoteRunnerStop(reason := "ahk-stop") {
    return AdvisorQuoteRunnerCommand("stop", Map("reason", reason), "ADVISOR_RUNNER_STOP")
}

AdvisorQuoteRunnerReset(clearEvents := false) {
    return AdvisorQuoteRunnerCommand("reset", Map("clearEvents", clearEvents ? "1" : "0"), "ADVISOR_RUNNER_RESET")
}

AdvisorQuoteRunnerGetEvents(sinceSeq := 0, limit := 50) {
    return AdvisorQuoteRunnerCommand("getEvents", Map("sinceSeq", sinceSeq, "limit", limit), "ADVISOR_RUNNER_EVENTS")
}

AdvisorQuoteRunnerRunUntilBlocked(args := Map()) {
    global advisorQuoteResidentRunnerReadOnlyOnly
    runnerArgs := Map()
    if IsObject(args) {
        for key, value in args
            runnerArgs[String(key)] := value
    }
    if (advisorQuoteResidentRunnerReadOnlyOnly = true)
        runnerArgs["readOnly"] := "1"
    return AdvisorQuoteRunnerCommand("runUntilBlocked", runnerArgs, "ADVISOR_RUNNER_RUN_UNTIL_BLOCKED")
}

AdvisorQuoteRunnerWaitAllowlist() {
    return [
        "on_customer_summary_overview",
        "on_product_overview",
        "gather_data",
        "is_rapport",
        "is_select_product",
        "is_asc",
        "consumer_reports_ready",
        "drivers_or_incidents",
        "after_driver_vehicle_continue",
        "quote_landing",
        "incidents_done",
        "continue_enabled",
        "vehicle_select_enabled",
        "vehicle_added_tile",
        "vehicle_confirmed"
    ]
}

AdvisorQuoteRunnerStatusAllowlist() {
    return [
        "detect_state",
        "gather_start_quoting_status",
        "gather_confirmed_vehicles_status",
        "asc_participant_detail_status",
        "asc_driver_rows_status",
        "asc_vehicle_rows_status",
        "product_overview_tile_status",
        "customer_summary_overview_status",
        "gather_vehicle_add_status",
        "gather_vehicle_row_status",
        "gather_vehicle_edit_status"
    ]
}

AdvisorQuoteRunnerNotUsed(reason, extra := Map()) {
    result := Map("used", "0", "fallbackReason", reason)
    if IsObject(extra) {
        for key, value in extra
            result[String(key)] := value
    }
    return result
}

AdvisorQuoteRunnerUsedResult(value, status) {
    result := Map("used", "1", "value", value)
    if IsObject(status) {
        for key, val in status
            result[String(key)] := val
    }
    return result
}

AdvisorQuoteRunnerAllowedWaitCondition(name) {
    return AdvisorQuoteIsStateInList(String(name), AdvisorQuoteRunnerWaitAllowlist())
}

AdvisorQuoteRunnerAllowedStatusOp(opName) {
    return AdvisorQuoteIsStateInList(String(opName), AdvisorQuoteRunnerStatusAllowlist())
}

AdvisorQuoteReadOnlyRunnerWaitAllowlist() {
    return [
        "gather_data",
        "is_rapport"
    ]
}

AdvisorQuoteReadOnlyRunnerStatusAllowlist() {
    return [
        "detect_state",
        "gather_rapport_snapshot",
        "gather_start_quoting_status",
        "gather_confirmed_vehicles_status",
        "product_overview_tile_status",
        "customer_summary_overview_status"
    ]
}

AdvisorQuoteReadOnlyRunnerPilotEnvValue() {
    try {
        return Trim(String(EnvGet("ADVISOR_QUOTE_READONLY_RUNNER_PILOT")))
    } catch as err {
        return ""
    }
}

AdvisorQuoteReadOnlyRunnerPilotEnvEnabled() {
    return AdvisorQuoteReadOnlyRunnerPilotEnvValue() = "1"
}

AdvisorQuoteReadOnlyRunnerPilotEnabled() {
    global advisorQuoteUseRunnerForReadOnlyPolling
    return advisorQuoteUseRunnerForReadOnlyPolling = true
}

AdvisorQuoteMaybeLogReadOnlyRunnerPilotEnabled(step := "") {
    global advisorQuoteReadOnlyRunnerPilotLogged
    if (advisorQuoteReadOnlyRunnerPilotLogged = true)
        return
    if !AdvisorQuoteReadOnlyRunnerPilotEnabled()
        return
    advisorQuoteReadOnlyRunnerPilotLogged := true
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_READONLY_PILOT_ENABLED",
        step = "" ? AdvisorQuoteGetLastStep() : step,
        "advisorQuoteUseRunnerForReadOnlyPolling=1"
    )
}

AdvisorQuoteReadOnlyRunnerAllowedWaitCondition(name) {
    return AdvisorQuoteIsStateInList(String(name), AdvisorQuoteReadOnlyRunnerWaitAllowlist())
}

AdvisorQuoteReadOnlyRunnerAllowedStatusOp(opName) {
    return AdvisorQuoteIsStateInList(String(opName), AdvisorQuoteReadOnlyRunnerStatusAllowlist())
}

AdvisorQuoteReadOnlyRunnerConditionName(args) {
    if IsObject(args) && args.Has("name")
        return Trim(String(args["name"]))
    if IsObject(args) && args.Has("conditionName")
        return Trim(String(args["conditionName"]))
    return ""
}

AdvisorQuoteReadOnlyRunnerCandidate(op, args := Map()) {
    opName := Trim(String(op ?? ""))
    if (opName = "wait_condition")
        return AdvisorQuoteReadOnlyRunnerAllowedWaitCondition(AdvisorQuoteReadOnlyRunnerConditionName(args))
    return AdvisorQuoteReadOnlyRunnerAllowedStatusOp(opName)
}

AdvisorQuoteRunnerValueTruthy(value) {
    text := StrLower(Trim(String(value ?? "")))
    return !(text = "" || text = "0" || text = "false" || text = "no" || text = "off")
}

AdvisorQuoteReadOnlyRunnerArgsRequestMutation(args) {
    if !IsObject(args)
        return false
    readOnly := args.Has("readOnly") ? StrLower(Trim(String(args["readOnly"]))) : ""
    if (readOnly != "" && !(readOnly = "1" || readOnly = "true" || readOnly = "yes" || readOnly = "on"))
        return true
    mutationKeys := [
        "mutate",
        "mutation",
        "mutating",
        "click",
        "fill",
        "set",
        "select",
        "save",
        "confirm",
        "remove",
        "add",
        "reconcile",
        "resolve",
        "handle",
        "submit",
        "continue",
        "update",
        "delete"
    ]
    for key, value in args {
        keyName := StrLower(Trim(String(key)))
        if AdvisorQuoteIsStateInList(keyName, mutationKeys) && AdvisorQuoteRunnerValueTruthy(value)
            return true
    }
    return false
}

AdvisorQuoteReadOnlyRunnerMutationNameLike(op) {
    opName := Trim(String(op ?? ""))
    lowered := StrLower(opName)
    mutationTokens := [
        "click",
        "fill",
        "set",
        "select",
        "save",
        "confirm",
        "remove",
        "add",
        "reconcile",
        "resolve",
        "handle",
        "submit",
        "continue",
        "update",
        "delete"
    ]
    for token in StrSplit(lowered, "_") {
        if AdvisorQuoteIsStateInList(token, mutationTokens)
            return true
    }
    return false
}

AdvisorQuoteReadOnlyRunnerMutationLike(op, args := Map()) {
    if AdvisorQuoteReadOnlyRunnerMutationNameLike(op)
        return true
    return AdvisorQuoteReadOnlyRunnerArgsRequestMutation(args)
}

AdvisorQuoteReadOnlyRunnerAdvisorContext(state) {
    stateName := AdvisorQuoteJsMetricSafeToken(state, "")
    if (stateName = "" || stateName = "INIT" || stateName = "UNKNOWN")
        return true
    return !AdvisorQuoteIsStateInList(stateName, ["GATEWAY", "NO_CONTEXT"])
}

AdvisorQuoteReadOnlyRunnerGate(op, args := Map(), state := "") {
    global advisorQuoteResidentRunnerReadOnlyOnly
    opName := Trim(String(op ?? ""))
    candidate := AdvisorQuoteReadOnlyRunnerCandidate(opName, args)
    candidateValue := candidate ? "1" : "0"
    pilotEnabled := AdvisorQuoteReadOnlyRunnerPilotEnabled()
    if !pilotEnabled
        return Map("ok", "0", "reason", "read-only-runner-disabled", "candidate", candidateValue, "pilotEnabled", "0")
    if (advisorQuoteResidentRunnerReadOnlyOnly != true)
        return Map("ok", "0", "reason", "read-only-guard-disabled", "candidate", candidateValue, "pilotEnabled", "1")
    if AdvisorQuoteReadOnlyRunnerMutationLike(opName, args)
        return Map("ok", "0", "reason", "mutation-like-op", "candidate", candidateValue, "pilotEnabled", "1", "hardRefused", "1")
    if !candidate
        return Map("ok", "0", "reason", "not-allowlisted", "candidate", "0", "pilotEnabled", "1")
    if !AdvisorQuoteReadOnlyRunnerAdvisorContext(state)
        return Map("ok", "0", "reason", "not-advisor-context", "candidate", "1", "pilotEnabled", "1")
    if (opName = "wait_condition")
        return Map("ok", "1", "reason", "", "candidate", "1", "pilotEnabled", "1", "kind", "wait_poll", "conditionName", AdvisorQuoteReadOnlyRunnerConditionName(args))
    return Map("ok", "1", "reason", "", "candidate", "1", "pilotEnabled", "1", "kind", "status_read", "conditionName", "")
}

AdvisorQuoteCanUseRunnerForOp(op, args := Map(), state := "") {
    gate := AdvisorQuoteReadOnlyRunnerGate(op, args, state)
    return AdvisorQuoteStatusValue(gate, "ok") = "1"
}

AdvisorQuoteJsMetricTotalValue(key) {
    global advisorQuoteJsMetrics
    AdvisorQuoteEnsureJsMetricsCollector()
    return (IsObject(advisorQuoteJsMetrics) && advisorQuoteJsMetrics.Has(key)) ? Integer(advisorQuoteJsMetrics[key]) : 0
}

AdvisorQuoteRunReadOnlyRunnerPilotSelfTest() {
    global advisorQuoteUseRunnerForReadOnlyPolling, advisorQuoteResidentRunnerFeatureEnabled
    step := "RUNNER_PILOT_SELFTEST"
    opName := "detect_state"
    args := Map()
    AdvisorQuoteEnsureJsMetricsCollector()

    envValue := AdvisorQuoteReadOnlyRunnerPilotEnvValue()
    envVisible := envValue = "1"
    pilotResolved := AdvisorQuoteReadOnlyRunnerPilotEnabled()
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_PILOT_ENV_STATUS",
        step,
        "envName=ADVISOR_QUOTE_READONLY_RUNNER_PILOT"
            . ", envVisible=" (envVisible ? "1" : "0")
            . ", envValue=" (envValue = "" ? "EMPTY" : AdvisorQuoteJsMetricSafeToken(envValue, "set"))
            . ", advisorQuoteUseRunnerForReadOnlyPolling=" (advisorQuoteUseRunnerForReadOnlyPolling = true ? "1" : "0")
            . ", pilotResolved=" (pilotResolved ? "1" : "0")
            . ", residentRunnerFeatureEnabled=" (advisorQuoteResidentRunnerFeatureEnabled = true ? "1" : "0")
            . ", readOnlyPilotRequiresMutatingFeature=0"
    )

    gate := AdvisorQuoteReadOnlyRunnerGate(opName, args, step)
    gateAllowed := AdvisorQuoteStatusValue(gate, "ok") = "1"
    gateReason := AdvisorQuoteStatusValue(gate, "reason")
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_PILOT_GATE_STATUS",
        step,
        "op=" opName
            . ", allowed=" (gateAllowed ? "1" : "0")
            . ", reason=" gateReason
            . ", candidate=" AdvisorQuoteStatusValue(gate, "candidate")
            . ", pilotEnabled=" AdvisorQuoteStatusValue(gate, "pilotEnabled")
            . ", readOnlyPilotRequiresMutatingFeature=0"
    )

    beforeTinyAttempts := AdvisorQuoteJsMetricTotalValue("runnerTinyBridgeAttemptCount")
    beforeTinySuccesses := AdvisorQuoteJsMetricTotalValue("runnerTinyBridgeSuccessCount")
    beforeTinyFallbacks := AdvisorQuoteJsMetricTotalValue("runnerTinyBridgeFallbackCount")
    if !gateAllowed {
        AdvisorQuoteWriteJsMetricsFiles()
        AdvisorQuoteAppendLog(
            "ADVISOR_RUNNER_PILOT_SELFTEST_RESULT",
            step,
            "result=GATE_REFUSED"
                . ", op=" opName
                . ", envVisible=" (envVisible ? "1" : "0")
                . ", pilotResolved=" (pilotResolved ? "1" : "0")
                . ", fallbackReason=" gateReason
                . ", runnerTinyAttemptDelta=0"
        )
        return Map(
            "result", "GATE_REFUSED",
            "op", opName,
            "envVisible", envVisible ? "1" : "0",
            "pilotResolved", pilotResolved ? "1" : "0",
            "gateAllowed", "0",
            "fallbackReason", gateReason,
            "runnerTinyAttemptDelta", "0"
        )
    }

    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_PILOT_SELFTEST_ATTEMPT",
        step,
        "op=" opName ", gateAllowed=1, envVisible=" (envVisible ? "1" : "0")
    )
    runnerResult := AdvisorQuoteRunReadOnlyOpViaRunner(opName, args, step)
    afterTinyAttempts := AdvisorQuoteJsMetricTotalValue("runnerTinyBridgeAttemptCount")
    afterTinySuccesses := AdvisorQuoteJsMetricTotalValue("runnerTinyBridgeSuccessCount")
    afterTinyFallbacks := AdvisorQuoteJsMetricTotalValue("runnerTinyBridgeFallbackCount")
    attemptDelta := afterTinyAttempts - beforeTinyAttempts
    successDelta := afterTinySuccesses - beforeTinySuccesses
    fallbackDelta := afterTinyFallbacks - beforeTinyFallbacks
    used := AdvisorQuoteStatusValue(runnerResult, "used") = "1"
    runnerStatus := AdvisorQuoteStatusValue(runnerResult, "result")
    fallbackReason := AdvisorQuoteStatusValue(runnerResult, "fallbackReason")
    if (fallbackReason = "" && !used)
        fallbackReason := runnerStatus = "" ? "EMPTY" : runnerStatus
    AdvisorQuoteWriteJsMetricsFiles()
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_PILOT_SELFTEST_RESULT",
        step,
        "result=" (used ? "OK" : "FALLBACK")
            . ", op=" opName
            . ", runnerResult=" runnerStatus
            . ", used=" (used ? "1" : "0")
            . ", fallbackReason=" fallbackReason
            . ", runnerTinyAttemptDelta=" attemptDelta
            . ", runnerTinySuccessDelta=" successDelta
            . ", runnerTinyFallbackDelta=" fallbackDelta
    )
    return Map(
        "result", used ? "OK" : "FALLBACK",
        "op", opName,
        "envVisible", envVisible ? "1" : "0",
        "pilotResolved", pilotResolved ? "1" : "0",
        "gateAllowed", "1",
        "runnerResult", runnerStatus,
        "used", used ? "1" : "0",
        "fallbackReason", fallbackReason,
        "runnerTinyAttemptDelta", String(attemptDelta),
        "runnerTinySuccessDelta", String(successDelta),
        "runnerTinyFallbackDelta", String(fallbackDelta)
    )
}

AdvisorQuoteReadOnlyRunnerCommand(command, args := Map(), eventName := "") {
    if (eventName = "")
        eventName := "ADVISOR_RUNNER_READONLY_" StrUpper(command)
    if StopRequested() {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_READONLY_FALLBACK", AdvisorQuoteGetLastStep(), "command=" command ", fallbackReason=stop-requested")
        return Map("result", "STOP_REQUESTED", "command", command)
    }
    global advisorQuoteResidentRunnerUseTinyBridge
    if (command != "bootstrap" && advisorQuoteResidentRunnerUseTinyBridge = true)
        return AdvisorQuoteRunnerTinyCommand(command, args, eventName)
    return AdvisorQuoteRunnerFullCommand(command, args, eventName)
}

AdvisorQuoteEnsureReadOnlyResidentRunner() {
    global advisorQuoteReadOnlyRunnerBootstrapped
    if (advisorQuoteReadOnlyRunnerBootstrapped = true)
        return true
    status := AdvisorQuoteReadOnlyRunnerCommand("bootstrap", Map("replaceStale", "1"), "ADVISOR_RUNNER_READONLY_BOOTSTRAP")
    result := AdvisorQuoteStatusValue(status, "result")
    if (result = "STALE_REPLACED")
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_READONLY_REBOOTSTRAP", AdvisorQuoteGetLastStep(), "result=STALE_REPLACED, runnerId=" AdvisorQuoteStatusValue(status, "runnerId"))
    advisorQuoteReadOnlyRunnerBootstrapped := result = "OK" || result = "ALREADY_BOOTSTRAPPED" || result = "STALE_REPLACED"
    return advisorQuoteReadOnlyRunnerBootstrapped
}

AdvisorQuoteBuildReadOnlyRunnerArgs(op, args := Map()) {
    opName := Trim(String(op ?? ""))
    runnerArgs := AdvisorQuoteMergeArgs(args, Map(
        "conditionArgs", args,
        "readOnly", "1",
        "timeoutMs", "1",
        "pollMs", "0",
        "maxSteps", "1",
        "requireKnownRoute", "1",
        "expectedHost", "advisorpro"
    ))
    if (opName = "wait_condition") {
        conditionName := AdvisorQuoteReadOnlyRunnerConditionName(args)
        runnerArgs["conditionName"] := conditionName
        runnerArgs["allowedConditions"] := conditionName
    } else {
        runnerArgs["statusOp"] := opName
        runnerArgs["allowedStatusOps"] := opName
        runnerArgs["returnPayloadLines"] := "1"
    }
    return runnerArgs
}

AdvisorQuoteRunnerTinyPayloadLength(command, args := Map()) {
    try {
        return StrLen(AdvisorQuoteBuildTinyRunnerCommandJs(AdvisorQuoteRunnerBuildCommandArgs(command, args)))
    } catch as err {
        return 0
    }
}

AdvisorQuoteReadOnlyRunnerPayload(op, status) {
    opName := Trim(String(op ?? ""))
    if (opName = "wait_condition")
        return AdvisorQuoteStatusValue(status, "lastValue")

    countText := AdvisorQuoteStatusValue(status, "payloadLineCount")
    if RegExMatch(countText, "^\d+$") {
        lineCount := Integer(countText)
        if (lineCount > 0) {
            lines := []
            Loop lineCount {
                key := "payloadLine" A_Index
                if IsObject(status) && status.Has(key)
                    lines.Push(String(status[key]))
            }
            if (lines.Length > 0)
                return JoinArray(lines, "`n")
        }
    }
    return AdvisorQuoteStatusValue(status, "lastValue")
}

AdvisorQuoteReadOnlyRunnerPayloadValid(op, payload) {
    opName := Trim(String(op ?? ""))
    text := Trim(String(payload ?? ""))
    if (text = "")
        return false
    if (opName = "wait_condition")
        return text = "0" || text = "1"
    if (opName = "detect_state")
        return RegExMatch(text, "^[A-Z0-9_]+$") ? true : false
    parsed := AdvisorQuoteParseKeyValueLines(text)
    return IsObject(parsed) && parsed.Count > 0
}

AdvisorQuoteReadOnlyRunnerTraceDetail(op, args, suffix := "") {
    opName := AdvisorQuoteJsMetricSafeToken(op, "unknown")
    conditionName := (opName = "wait_condition") ? AdvisorQuoteJsMetricSafeToken(AdvisorQuoteReadOnlyRunnerConditionName(args), "") : ""
    detail := "op=" opName
        . ", category=" AdvisorQuoteJsMetricCategory(opName)
        . ", waitConditionName=" conditionName
    if (suffix != "")
        detail .= ", " suffix
    return detail
}

AdvisorQuoteRunReadOnlyOpViaRunner(op, args := Map(), state := "") {
    global advisorQuoteResidentRunnerUseTinyBridge, advisorQuoteReadOnlyRunnerBootstrapped
    opName := Trim(String(op ?? ""))
    step := (Trim(String(state ?? "")) != "") ? state : AdvisorQuoteGetLastStep()
    AdvisorQuoteMaybeLogReadOnlyRunnerPilotEnabled(step)
    gate := AdvisorQuoteReadOnlyRunnerGate(opName, args, step)
    reason := AdvisorQuoteStatusValue(gate, "reason")

    if (AdvisorQuoteStatusValue(gate, "ok") != "1") {
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_READONLY_GATE_REFUSED", step, AdvisorQuoteReadOnlyRunnerTraceDetail(opName, args, "reason=" reason))
        if (reason = "mutation-like-op") {
            AdvisorQuoteAppendLog("ADVISOR_RUNNER_READONLY_REFUSED", step, AdvisorQuoteReadOnlyRunnerTraceDetail(opName, args, "reason=mutation-like-op"))
        }
        return AdvisorQuoteRunnerNotUsed(reason)
    }

    runnerArgs := AdvisorQuoteBuildReadOnlyRunnerArgs(opName, args)
    tinyBridge := advisorQuoteResidentRunnerUseTinyBridge = true
    tinyPayloadLength := tinyBridge ? AdvisorQuoteRunnerTinyPayloadLength("runReadOnlyPoll", runnerArgs) : 0
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_READONLY_GATE_ALLOWED",
        step,
        AdvisorQuoteReadOnlyRunnerTraceDetail(opName, args, "gate=pilot, tinyBridge=" (tinyBridge ? "1" : "0"))
    )
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_READONLY_ATTEMPT",
        step,
        AdvisorQuoteReadOnlyRunnerTraceDetail(opName, args, "tinyBridge=" (tinyBridge ? "1" : "0") ", tinyPayloadLength=" tinyPayloadLength)
    )

    if tinyBridge
        AdvisorQuoteRecordRunnerTinyBridgeMetric(opName, args, tinyPayloadLength, "attempt", "", false)

    if !AdvisorQuoteEnsureReadOnlyResidentRunner() {
        if tinyBridge
            AdvisorQuoteRecordRunnerTinyBridgeMetric(opName, args, tinyPayloadLength, "fallback", "bootstrap-failed", true)
        AdvisorQuoteAppendLog("ADVISOR_RUNNER_READONLY_FALLBACK", step, AdvisorQuoteReadOnlyRunnerTraceDetail(opName, args, "fallbackReason=bootstrap-failed"))
        return AdvisorQuoteRunnerNotUsed("bootstrap-failed")
    }

    status := AdvisorQuoteReadOnlyRunnerCommand("runReadOnlyPoll", runnerArgs, "ADVISOR_RUNNER_READONLY_RESULT")
    result := AdvisorQuoteStatusValue(status, "result")
    matched := AdvisorQuoteStatusValue(status, "matched")
    blockedReason := AdvisorQuoteStatusValue(status, "blockedReason")
    payload := AdvisorQuoteReadOnlyRunnerPayload(opName, status)
    payloadLength := StrLen(String(payload ?? ""))

    if (opName = "wait_condition" && result = "MAX_STEPS")
        payload := "0"

    usable := false
    if (opName = "wait_condition") {
        usable := (result = "OK" && matched = "1") || result = "MAX_STEPS"
    } else {
        usable := result = "OK" && matched = "1" && AdvisorQuoteReadOnlyRunnerPayloadValid(opName, payload)
    }

    if usable {
        if tinyBridge
            AdvisorQuoteRecordRunnerTinyBridgeMetric(opName, args, tinyPayloadLength, "success", "", true)
        AdvisorQuoteAppendLog(
            "ADVISOR_RUNNER_READONLY_OK",
            step,
            AdvisorQuoteReadOnlyRunnerTraceDetail(opName, args, "result=" result ", matched=" matched ", payloadLength=" payloadLength)
        )
        return AdvisorQuoteRunnerUsedResult(payload, status)
    }

    fallbackReason := result = "" ? "EMPTY" : result
    if (result = "OK")
        fallbackReason := "invalid-payload"
    if AdvisorQuoteIsStateInList(result, ["MISSING", "STALE", "STALE_BUILD"])
        advisorQuoteReadOnlyRunnerBootstrapped := false
    if tinyBridge
        AdvisorQuoteRecordRunnerTinyBridgeMetric(opName, args, tinyPayloadLength, "fallback", fallbackReason, true)
    AdvisorQuoteAppendLog(
        "ADVISOR_RUNNER_READONLY_FALLBACK",
        step,
        AdvisorQuoteReadOnlyRunnerTraceDetail(opName, args, "result=" result ", blockedReason=" blockedReason ", fallbackReason=" fallbackReason)
    )
    return AdvisorQuoteRunnerNotUsed(fallbackReason, status)
}

AdvisorQuoteRunnerWaitCondition(name, args, timeoutMs := "", pollMs := "") {
    global advisorQuoteResidentRunnerReadOnlyOnly
    if !AdvisorQuoteResidentRunnerEnabled()
        return AdvisorQuoteRunnerNotUsed("feature-disabled")
    if (advisorQuoteResidentRunnerReadOnlyOnly != true)
        return AdvisorQuoteRunnerNotUsed("read-only-guard-disabled")
    if !AdvisorQuoteRunnerAllowedWaitCondition(name)
        return AdvisorQuoteRunnerNotUsed("condition-not-allowlisted")
    if StopRequested()
        return AdvisorQuoteRunnerNotUsed("stop-requested")
    if !AdvisorQuoteEnsureResidentRunner()
        return AdvisorQuoteRunnerNotUsed("bootstrap-failed")

    waitTimeoutMs := Trim(String(timeoutMs)) != "" ? Max(1, Integer(timeoutMs)) : 1000
    waitPollMs := Trim(String(pollMs)) != "" ? Max(0, Integer(pollMs)) : 100
    start := A_TickCount
    steps := 0
    lastStatus := Map()
    while ((A_TickCount - start) < waitTimeoutMs) {
        if StopRequested()
            return AdvisorQuoteRunnerUsedResult(false, Map("result", "STOPPED", "matched", "0", "steps", steps, "elapsedMs", A_TickCount - start))
        runnerArgs := AdvisorQuoteMergeArgs(args, Map(
            "conditionName", name,
            "conditionArgs", args,
            "readOnly", "1",
            "allowedConditions", name,
            "timeoutMs", "1",
            "pollMs", "0",
            "maxSteps", "1"
        ))
        lastStatus := AdvisorQuoteRunnerCommand("runReadOnlyPoll", runnerArgs, "ADVISOR_RUNNER_WAIT_RESULT")
        result := AdvisorQuoteStatusValue(lastStatus, "result")
        matched := AdvisorQuoteStatusValue(lastStatus, "matched")
        stepValue := AdvisorQuoteStatusValue(lastStatus, "steps")
        steps += Max(1, Integer(stepValue = "" ? "1" : stepValue))
        if (result = "OK" && matched = "1")
            return AdvisorQuoteRunnerUsedResult(true, lastStatus)
        if (result = "STOPPED")
            return AdvisorQuoteRunnerUsedResult(false, lastStatus)
        if AdvisorQuoteIsStateInList(result, ["", "MISSING", "STALE", "STALE_BUILD", "WRONG_CONTEXT", "ERROR", "EMPTY", "DISABLED", "STOP_REQUESTED", "REFUSED"])
            return AdvisorQuoteRunnerNotUsed(result = "" ? "empty-result" : result, lastStatus)
        if !SafeSleep(waitPollMs)
            return AdvisorQuoteRunnerUsedResult(false, Map("result", "STOPPED", "matched", "0", "steps", steps, "elapsedMs", A_TickCount - start))
    }
    timeoutStatus := Map(
        "result", "TIMEOUT",
        "matched", "0",
        "steps", steps,
        "elapsedMs", A_TickCount - start,
        "blockedReason", "timeout",
        "conditionName", name,
        "lastValue", AdvisorQuoteStatusValue(lastStatus, "lastValue")
    )
    return AdvisorQuoteRunnerUsedResult(false, timeoutStatus)
}

AdvisorQuoteRunnerReadStatus(opName, args := Map()) {
    global advisorQuoteResidentRunnerReadOnlyOnly
    if !AdvisorQuoteResidentRunnerEnabled()
        return AdvisorQuoteRunnerNotUsed("feature-disabled")
    if (advisorQuoteResidentRunnerReadOnlyOnly != true)
        return AdvisorQuoteRunnerNotUsed("read-only-guard-disabled")
    if !AdvisorQuoteRunnerAllowedStatusOp(opName)
        return AdvisorQuoteRunnerNotUsed("status-op-not-allowlisted")
    if StopRequested()
        return AdvisorQuoteRunnerNotUsed("stop-requested")
    if !AdvisorQuoteEnsureResidentRunner()
        return AdvisorQuoteRunnerNotUsed("bootstrap-failed")

    runnerArgs := AdvisorQuoteMergeArgs(args, Map(
        "statusOp", opName,
        "conditionArgs", args,
        "readOnly", "1",
        "allowedStatusOps", opName,
        "timeoutMs", "1",
        "pollMs", "0",
        "maxSteps", "1"
    ))
    status := AdvisorQuoteRunnerCommand("runReadOnlyPoll", runnerArgs, "ADVISOR_RUNNER_STATUS_POLL")
    result := AdvisorQuoteStatusValue(status, "result")
    matched := AdvisorQuoteStatusValue(status, "matched")
    if (result = "OK" && matched = "1")
        return AdvisorQuoteRunnerUsedResult(true, status)
    return AdvisorQuoteRunnerNotUsed(result = "" ? "empty-result" : result, status)
}

AdvisorQuoteRunJsOp(op, args := Map(), retries := 1, retryDelayMs := 200) {
    residentAttempt := AdvisorQuoteRunOpViaResidentTransport(op, args, AdvisorQuoteGetLastStep())
    if (AdvisorQuoteStatusValue(residentAttempt, "used") = "1")
        return residentAttempt["value"]

    return AdvisorQuoteRunJsOpFullInjection(op, args, retries, retryDelayMs)
}

AdvisorQuoteRunJsOpFullInjection(op, args := Map(), retries := 1, retryDelayMs := 200) {
    global advisorQuoteConsoleBridgeOpen
    attempts := Max(1, Integer(retries))

    rendered := AdvisorQuoteRenderOpJs(op, args)
    if (rendered = "")
        return ""
    renderedLength := StrLen(rendered)

    Loop attempts {
        if StopRequested()
            return ""
        AdvisorQuoteLogJsBridgeOp(op, args, A_Index, attempts)
        bridgeWasOpen := (advisorQuoteConsoleBridgeOpen ?? false) = true
        if !AdvisorQuoteEnsureConsoleBridge() {
            AdvisorQuoteRecordJsInjectionMetric(op, args, A_Index, attempts, renderedLength, false, false, true, false, false, false)
            AdvisorQuoteInvalidateConsoleBridge("op=" op ", attempt=" A_Index "/" attempts ", reason=ensure-console-failed")
            return ""
        }

        result := Trim(String(AdvisorQuoteExecuteBridgeJs(rendered, true)))
        emptyResult := result = ""
        AdvisorQuoteRecordJsInjectionMetric(op, args, A_Index, attempts, renderedLength, !bridgeWasOpen, bridgeWasOpen, emptyResult, true, emptyResult, false)
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

AdvisorQuoteExecuteBridgeJs(jsCode, expectResult := true, resultTimeoutMs := 2500) {
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
        waitUntil := A_TickCount + Max(100, Integer(resultTimeoutMs))
        while (A_TickCount < waitUntil) {
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
