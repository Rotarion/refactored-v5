; Advisor quote JavaScript transport metrics helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

AdvisorQuoteResetJsMetricsCollector(writeNow := true) {
    global advisorQuoteRunId, advisorQuoteRunStartedAt, advisorQuoteJsMetrics, advisorQuoteJsMetricOps

    runId := AdvisorQuoteSanitizeScanToken(advisorQuoteRunId)
    if (runId = "")
        runId := "run-" . FormatTime(A_Now, "yyyyMMdd-HHmmss")
    startedAt := Trim(String(advisorQuoteRunStartedAt ?? ""))
    if (startedAt = "")
        startedAt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    advisorQuoteJsMetrics := Map(
        "schema", "advisor-js-injection-metrics-v1",
        "runId", runId,
        "startedAt", startedAt,
        "attemptCount", 0,
        "submittedCount", 0,
        "fullOperatorInjectionAttemptCount", 0,
        "fullOperatorInjectionSubmittedCount", 0,
        "renderedLengthTotal", 0,
        "submittedLengthTotal", 0,
        "renderedLengthMax", 0,
        "bridgeOpenedCount", 0,
        "bridgeReusedCount", 0,
        "bridgeFailedCount", 0,
        "emptyResultCount", 0,
        "retryCount", 0,
        "runnerTinyBridgeAttemptCount", 0,
        "runnerTinyBridgeSuccessCount", 0,
        "runnerTinyBridgeFallbackCount", 0,
        "runnerTinyPayloadLengthTotal", 0,
        "runnerTinyPayloadLengthMax", 0,
        "residentBootstrapAttemptCount", 0,
        "residentBootstrapSuccessCount", 0,
        "residentBootstrapFallbackCount", 0,
        "residentTinyCommandAttemptCount", 0,
        "residentTinyCommandSuccessCount", 0,
        "residentTinyCommandFallbackCount", 0,
        "residentTinyPayloadLengthTotal", 0,
        "residentTinyPayloadLengthMax", 0,
        "residentMutationAttemptCount", 0,
        "residentMutationSuccessCount", 0,
        "residentMutationFallbackCount", 0,
        "residentHealthCheckAttemptCount", 0,
        "residentHealthCheckSuccessCount", 0,
        "residentHealthCheckFallbackCount", 0,
        "residentBootstrapByRoute", Map(),
        "residentTinyCommandByRoute", Map(),
        "fullInjectionByRoute", Map(),
        "residentContextRouteFamily", "unknown"
    )
    advisorQuoteJsMetricOps := Map()
    if writeNow
        AdvisorQuoteWriteJsMetricsFiles()
}

AdvisorQuoteEnsureJsMetricsCollector() {
    global advisorQuoteJsMetrics
    if !IsObject(advisorQuoteJsMetrics) || !advisorQuoteJsMetrics.Has("runId")
        AdvisorQuoteResetJsMetricsCollector()
    AdvisorQuoteEnsureJsMetricCounterFields(advisorQuoteJsMetrics)
}

AdvisorQuoteEnsureJsMetricCounterFields(target) {
    if !IsObject(target)
        return
    keys := [
        "fullOperatorInjectionAttemptCount",
        "fullOperatorInjectionSubmittedCount",
        "residentBootstrapAttemptCount",
        "residentBootstrapSuccessCount",
        "residentBootstrapFallbackCount",
        "residentTinyCommandAttemptCount",
        "residentTinyCommandSuccessCount",
        "residentTinyCommandFallbackCount",
        "residentTinyPayloadLengthTotal",
        "residentTinyPayloadLengthMax",
        "residentMutationAttemptCount",
        "residentMutationSuccessCount",
        "residentMutationFallbackCount",
        "residentHealthCheckAttemptCount",
        "residentHealthCheckSuccessCount",
        "residentHealthCheckFallbackCount"
    ]
    for _, key in keys {
        if !target.Has(key)
            target[key] := 0
    }
    mapKeys := ["residentBootstrapByRoute", "residentTinyCommandByRoute", "fullInjectionByRoute"]
    for _, key in mapKeys {
        if !target.Has(key) || !IsObject(target[key])
            target[key] := Map()
    }
    if !target.Has("residentContextRouteFamily")
        target["residentContextRouteFamily"] := "unknown"
}

AdvisorQuoteEnsureJsMetricRecord(op, args) {
    global advisorQuoteJsMetricOps
    state := AdvisorQuoteJsMetricSafeToken(AdvisorQuoteGetLastStep(), "UNKNOWN")
    opName := AdvisorQuoteJsMetricSafeToken(op, "unknown")
    category := AdvisorQuoteJsMetricCategory(opName)
    waitConditionName := AdvisorQuoteJsMetricWaitConditionName(opName, args)
    key := state "|" category "|" opName "|" waitConditionName

    if !advisorQuoteJsMetricOps.Has(key) {
        advisorQuoteJsMetricOps[key] := Map(
            "state", state,
            "op", opName,
            "category", category,
            "waitConditionName", waitConditionName,
            "attemptCount", 0,
            "submittedCount", 0,
            "fullOperatorInjectionAttemptCount", 0,
            "fullOperatorInjectionSubmittedCount", 0,
            "renderedLengthTotal", 0,
            "submittedLengthTotal", 0,
            "renderedLengthMax", 0,
            "bridgeOpenedCount", 0,
            "bridgeReusedCount", 0,
            "bridgeFailedCount", 0,
            "emptyResultCount", 0,
            "retryCount", 0,
            "runnerTinyBridgeAttemptCount", 0,
            "runnerTinyBridgeSuccessCount", 0,
            "runnerTinyBridgeFallbackCount", 0,
            "runnerTinyPayloadLengthTotal", 0,
            "runnerTinyPayloadLengthMax", 0,
            "residentBootstrapAttemptCount", 0,
            "residentBootstrapSuccessCount", 0,
            "residentBootstrapFallbackCount", 0,
            "residentTinyCommandAttemptCount", 0,
            "residentTinyCommandSuccessCount", 0,
            "residentTinyCommandFallbackCount", 0,
            "residentTinyPayloadLengthTotal", 0,
            "residentTinyPayloadLengthMax", 0,
            "residentMutationAttemptCount", 0,
            "residentMutationSuccessCount", 0,
            "residentMutationFallbackCount", 0,
            "residentHealthCheckAttemptCount", 0,
            "residentHealthCheckSuccessCount", 0,
            "residentHealthCheckFallbackCount", 0
        )
    }
    AdvisorQuoteEnsureJsMetricCounterFields(advisorQuoteJsMetricOps[key])
    return advisorQuoteJsMetricOps[key]
}

AdvisorQuoteRecordJsInjectionMetric(op, args, attempt, attempts, renderedLength, bridgeOpened, bridgeReused, bridgeFailed, submitted, emptyResult, writeNow := true) {
    global advisorQuoteJsMetrics

    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        length := Max(0, Integer(renderedLength))
        retryAttempt := Integer(attempt) > 1
        record := AdvisorQuoteEnsureJsMetricRecord(op, args)

        AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "attemptCount")
        AdvisorQuoteMetricIncrement(record, "attemptCount")
        AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "fullOperatorInjectionAttemptCount")
        AdvisorQuoteMetricIncrement(record, "fullOperatorInjectionAttemptCount")
        AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "renderedLengthTotal", length)
        AdvisorQuoteMetricIncrement(record, "renderedLengthTotal", length)
        AdvisorQuoteMetricMax(advisorQuoteJsMetrics, "renderedLengthMax", length)
        AdvisorQuoteMetricMax(record, "renderedLengthMax", length)

        if submitted {
            AdvisorQuoteRecordResidentRouteMetric("full_injection", AdvisorQuoteResidentRouteFamily(AdvisorQuoteGetLastStep()), "", false)
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "submittedCount")
            AdvisorQuoteMetricIncrement(record, "submittedCount")
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "fullOperatorInjectionSubmittedCount")
            AdvisorQuoteMetricIncrement(record, "fullOperatorInjectionSubmittedCount")
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "submittedLengthTotal", length)
            AdvisorQuoteMetricIncrement(record, "submittedLengthTotal", length)
        }
        if bridgeOpened {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "bridgeOpenedCount")
            AdvisorQuoteMetricIncrement(record, "bridgeOpenedCount")
        }
        if bridgeReused {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "bridgeReusedCount")
            AdvisorQuoteMetricIncrement(record, "bridgeReusedCount")
        }
        if bridgeFailed {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "bridgeFailedCount")
            AdvisorQuoteMetricIncrement(record, "bridgeFailedCount")
        }
        if emptyResult {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "emptyResultCount")
            AdvisorQuoteMetricIncrement(record, "emptyResultCount")
        }
        if retryAttempt {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "retryCount")
            AdvisorQuoteMetricIncrement(record, "retryCount")
        }

        if writeNow
            AdvisorQuoteWriteJsMetricsFiles()
    } catch as err {
    }
}

AdvisorQuoteRecordRunnerTinyBridgeMetric(op, args, payloadLength, outcome, fallbackReason := "", writeNow := true) {
    global advisorQuoteJsMetrics

    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        length := Max(0, Integer(payloadLength))
        outcomeName := AdvisorQuoteJsMetricSafeToken(outcome, "attempt")
        record := AdvisorQuoteEnsureJsMetricRecord(op, args)

        if (outcomeName = "attempt") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "runnerTinyBridgeAttemptCount")
            AdvisorQuoteMetricIncrement(record, "runnerTinyBridgeAttemptCount")
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "runnerTinyPayloadLengthTotal", length)
            AdvisorQuoteMetricIncrement(record, "runnerTinyPayloadLengthTotal", length)
            AdvisorQuoteMetricMax(advisorQuoteJsMetrics, "runnerTinyPayloadLengthMax", length)
            AdvisorQuoteMetricMax(record, "runnerTinyPayloadLengthMax", length)
        } else if (outcomeName = "success") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "runnerTinyBridgeSuccessCount")
            AdvisorQuoteMetricIncrement(record, "runnerTinyBridgeSuccessCount")
        } else if (outcomeName = "fallback") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "runnerTinyBridgeFallbackCount")
            AdvisorQuoteMetricIncrement(record, "runnerTinyBridgeFallbackCount")
        }

        if writeNow
            AdvisorQuoteWriteJsMetricsFiles()
    } catch as err {
    }
}

AdvisorQuoteRecordResidentBootstrapMetric(outcome, fallbackReason := "", writeNow := true) {
    global advisorQuoteJsMetrics

    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        outcomeName := AdvisorQuoteJsMetricSafeToken(outcome, "attempt")
        record := AdvisorQuoteEnsureJsMetricRecord("resident_operator_bootstrap", Map())

        if (outcomeName = "attempt") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentBootstrapAttemptCount")
            AdvisorQuoteMetricIncrement(record, "residentBootstrapAttemptCount")
        } else if (outcomeName = "success") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentBootstrapSuccessCount")
            AdvisorQuoteMetricIncrement(record, "residentBootstrapSuccessCount")
        } else if (outcomeName = "fallback") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentBootstrapFallbackCount")
            AdvisorQuoteMetricIncrement(record, "residentBootstrapFallbackCount")
        }

        if writeNow
            AdvisorQuoteWriteJsMetricsFiles()
    } catch as err {
    }
}

AdvisorQuoteRecordResidentTinyCommandMetric(op, args, payloadLength, outcome, fallbackReason := "", writeNow := true) {
    global advisorQuoteJsMetrics

    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        length := Max(0, Integer(payloadLength))
        outcomeName := AdvisorQuoteJsMetricSafeToken(outcome, "attempt")
        record := AdvisorQuoteEnsureJsMetricRecord(op, args)

        if (outcomeName = "attempt") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentTinyCommandAttemptCount")
            AdvisorQuoteMetricIncrement(record, "residentTinyCommandAttemptCount")
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentTinyPayloadLengthTotal", length)
            AdvisorQuoteMetricIncrement(record, "residentTinyPayloadLengthTotal", length)
            AdvisorQuoteMetricMax(advisorQuoteJsMetrics, "residentTinyPayloadLengthMax", length)
            AdvisorQuoteMetricMax(record, "residentTinyPayloadLengthMax", length)
        } else if (outcomeName = "success") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentTinyCommandSuccessCount")
            AdvisorQuoteMetricIncrement(record, "residentTinyCommandSuccessCount")
        } else if (outcomeName = "fallback") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentTinyCommandFallbackCount")
            AdvisorQuoteMetricIncrement(record, "residentTinyCommandFallbackCount")
        }

        if writeNow
            AdvisorQuoteWriteJsMetricsFiles()
    } catch as err {
    }
}

AdvisorQuoteRecordResidentMutationMetric(op, args, outcome, fallbackReason := "", writeNow := true) {
    global advisorQuoteJsMetrics

    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        outcomeName := AdvisorQuoteJsMetricSafeToken(outcome, "fallback")
        record := AdvisorQuoteEnsureJsMetricRecord(op, args)

        if (outcomeName = "attempt") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentMutationAttemptCount")
            AdvisorQuoteMetricIncrement(record, "residentMutationAttemptCount")
        } else if (outcomeName = "success") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentMutationSuccessCount")
            AdvisorQuoteMetricIncrement(record, "residentMutationSuccessCount")
        } else if (outcomeName = "fallback") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentMutationFallbackCount")
            AdvisorQuoteMetricIncrement(record, "residentMutationFallbackCount")
        }

        if writeNow
            AdvisorQuoteWriteJsMetricsFiles()
    } catch as err {
    }
}


AdvisorQuoteMetricIncrementNested(target, key, childKey, amount := 1) {
    if !IsObject(target)
        return
    safeChild := AdvisorQuoteJsMetricSafeToken(childKey, "unknown")
    if !target.Has(key) || !IsObject(target[key])
        target[key] := Map()
    current := target[key].Has(safeChild) ? Integer(target[key][safeChild]) : 0
    target[key][safeChild] := current + Integer(amount)
}

AdvisorQuoteRecordResidentRouteMetric(kind, routeFamily := "", fallbackReason := "", writeNow := true) {
    global advisorQuoteJsMetrics
    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        eventKind := AdvisorQuoteJsMetricSafeToken(kind, "unknown")
        route := AdvisorQuoteJsMetricSafeToken(routeFamily, "unknown")
        advisorQuoteJsMetrics["residentContextRouteFamily"] := route
        if (eventKind = "health_attempt") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentHealthCheckAttemptCount")
        } else if (eventKind = "health_success") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentHealthCheckSuccessCount")
        } else if (eventKind = "health_fallback") {
            AdvisorQuoteMetricIncrement(advisorQuoteJsMetrics, "residentHealthCheckFallbackCount")
        } else if (eventKind = "route_bootstrap" || eventKind = "route_bootstrap_success" || eventKind = "route_bootstrap_fallback") {
            AdvisorQuoteMetricIncrementNested(advisorQuoteJsMetrics, "residentBootstrapByRoute", route)
        } else if (eventKind = "tiny_attempt" || eventKind = "tiny_success" || eventKind = "tiny_fallback") {
            AdvisorQuoteMetricIncrementNested(advisorQuoteJsMetrics, "residentTinyCommandByRoute", route)
        } else if (eventKind = "full_injection") {
            AdvisorQuoteMetricIncrementNested(advisorQuoteJsMetrics, "fullInjectionByRoute", route)
        }
        if writeNow
            AdvisorQuoteWriteJsMetricsFiles()
    } catch as err {
    }
}

AdvisorQuoteMetricMapJson(mapValue) {
    if !IsObject(mapValue)
        return "{}"
    json := "{"
    index := 0
    for key, value in mapValue {
        index += 1
        if (index > 1)
            json .= ", "
        json .= '"' AdvisorQuoteJsonEscape(AdvisorQuoteJsMetricSafeToken(key, "unknown")) '": ' Integer(value)
    }
    json .= "}"
    return json
}

AdvisorQuoteMetricIncrement(target, key, amount := 1) {
    current := (IsObject(target) && target.Has(key)) ? Integer(target[key]) : 0
    target[key] := current + Integer(amount)
}

AdvisorQuoteMetricMax(target, key, value) {
    current := (IsObject(target) && target.Has(key)) ? Integer(target[key]) : 0
    if (Integer(value) > current)
        target[key] := Integer(value)
}

AdvisorQuoteJsMetricCategory(op) {
    opName := String(op ?? "")
    if (opName = "resident_operator_bootstrap" || opName = "resident_operator_command")
        return "resident_bootstrap"
    if (opName = "wait_condition")
        return "wait_poll"
    if (opName = "scan_current_page")
        return "scan"
    if AdvisorQuoteIsJsActionOp(opName)
        return "action"
    if AdvisorQuoteRunnerAllowedStatusOp(opName)
        return "status_read"
    if RegExMatch(opName, "i)(^detect_state$|_status$|_snapshot$|^is_|_exists$|_listed$|^list_|^find_|^any_)")
        return "status_read"
    return "unknown"
}

AdvisorQuoteJsMetricWaitConditionName(op, args) {
    if (String(op ?? "") != "wait_condition")
        return ""
    if IsObject(args) && args.Has("name")
        return AdvisorQuoteJsMetricSafeToken(args["name"], "")
    return ""
}

AdvisorQuoteJsMetricSafeToken(value, fallback := "") {
    text := Trim(String(value ?? ""))
    if (text = "")
        text := fallback
    text := RegExReplace(text, "[^A-Za-z0-9_.:-]+", "-")
    text := RegExReplace(text, "^-+|-+$", "")
    if (text = "")
        text := fallback
    if (StrLen(text) > 80)
        text := SubStr(text, 1, 80)
    return text
}

AdvisorQuoteWriteJsMetricsFiles() {
    global logsRoot, advisorQuoteJsMetrics
    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        json := AdvisorQuoteBuildJsMetricsJson()
        latestPath := logsRoot "\advisor_js_injection_metrics_latest.json"
        AdvisorQuoteWriteUtf8Atomic(latestPath, json)

        runId := AdvisorQuoteJsMetricSafeToken(advisorQuoteJsMetrics["runId"], "run")
        runDir := logsRoot "\advisor_js_injection_metrics"
        perRunPath := runDir "\advisor_js_injection_metrics_" runId ".json"
        AdvisorQuoteWriteUtf8Atomic(perRunPath, json)
    } catch as err {
    }
}

AdvisorQuoteBuildJsMetricsJson() {
    global advisorQuoteJsMetrics, advisorQuoteJsMetricOps
    AdvisorQuoteEnsureJsMetricsCollector()
    updatedAt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    json := "{`n"
        . '  "schema": "' AdvisorQuoteJsonEscape(advisorQuoteJsMetrics["schema"]) '",`n'
        . '  "runId": "' AdvisorQuoteJsonEscape(advisorQuoteJsMetrics["runId"]) '",`n'
        . '  "startedAt": "' AdvisorQuoteJsonEscape(advisorQuoteJsMetrics["startedAt"]) '",`n'
        . '  "updatedAt": "' AdvisorQuoteJsonEscape(updatedAt) '",`n'
        . '  "totals": ' AdvisorQuoteBuildJsMetricTotalsJson() ",`n"
        . '  "ops": ['

    index := 0
    for _, record in advisorQuoteJsMetricOps {
        index += 1
        json .= (index = 1) ? "`n" : ",`n"
        json .= AdvisorQuoteBuildJsMetricRecordJson(record, "    ")
    }
    if (index > 0)
        json .= "`n"
    json .= "  ],`n"
        . '  "hotOps": ['
    hotOps := AdvisorQuoteBuildJsMetricHotOps(5)
    for index, record in hotOps {
        json .= (index = 1) ? "`n" : ",`n"
        json .= AdvisorQuoteBuildJsMetricRecordJson(record, "    ")
    }
    if (hotOps.Length > 0)
        json .= "`n"
    json .= "  ]`n}"
    return json
}

AdvisorQuoteBuildJsMetricTotalsJson() {
    global advisorQuoteJsMetrics, advisorQuoteJsMetricOps
    submittedBytes := Integer(advisorQuoteJsMetrics["submittedLengthTotal"])
    mib := submittedBytes / 1048576.0
    return "{"
        . '"attemptCount": ' Integer(advisorQuoteJsMetrics["attemptCount"]) ", "
        . '"submittedCount": ' Integer(advisorQuoteJsMetrics["submittedCount"]) ", "
        . '"fullOperatorInjectionAttemptCount": ' Integer(advisorQuoteJsMetrics["fullOperatorInjectionAttemptCount"]) ", "
        . '"fullOperatorInjectionSubmittedCount": ' Integer(advisorQuoteJsMetrics["fullOperatorInjectionSubmittedCount"]) ", "
        . '"fullOperatorInjectionSubmittedLengthTotal": ' submittedBytes ", "
        . '"renderedLengthTotal": ' Integer(advisorQuoteJsMetrics["renderedLengthTotal"]) ", "
        . '"submittedLengthTotal": ' submittedBytes ", "
        . '"submittedMiB": "' Format("{:.2f}", mib) '", '
        . '"renderedLengthMax": ' Integer(advisorQuoteJsMetrics["renderedLengthMax"]) ", "
        . '"bridgeOpenedCount": ' Integer(advisorQuoteJsMetrics["bridgeOpenedCount"]) ", "
        . '"bridgeReusedCount": ' Integer(advisorQuoteJsMetrics["bridgeReusedCount"]) ", "
        . '"bridgeFailedCount": ' Integer(advisorQuoteJsMetrics["bridgeFailedCount"]) ", "
        . '"emptyResultCount": ' Integer(advisorQuoteJsMetrics["emptyResultCount"]) ", "
        . '"retryCount": ' Integer(advisorQuoteJsMetrics["retryCount"]) ", "
        . '"runnerTinyBridgeAttemptCount": ' Integer(advisorQuoteJsMetrics["runnerTinyBridgeAttemptCount"]) ", "
        . '"runnerTinyBridgeSuccessCount": ' Integer(advisorQuoteJsMetrics["runnerTinyBridgeSuccessCount"]) ", "
        . '"runnerTinyBridgeFallbackCount": ' Integer(advisorQuoteJsMetrics["runnerTinyBridgeFallbackCount"]) ", "
        . '"runnerTinyPayloadLengthTotal": ' Integer(advisorQuoteJsMetrics["runnerTinyPayloadLengthTotal"]) ", "
        . '"runnerTinyPayloadLengthMax": ' Integer(advisorQuoteJsMetrics["runnerTinyPayloadLengthMax"]) ", "
        . '"residentBootstrapAttemptCount": ' Integer(advisorQuoteJsMetrics["residentBootstrapAttemptCount"]) ", "
        . '"residentBootstrapSuccessCount": ' Integer(advisorQuoteJsMetrics["residentBootstrapSuccessCount"]) ", "
        . '"residentBootstrapFallbackCount": ' Integer(advisorQuoteJsMetrics["residentBootstrapFallbackCount"]) ", "
        . '"residentTinyCommandAttemptCount": ' Integer(advisorQuoteJsMetrics["residentTinyCommandAttemptCount"]) ", "
        . '"residentTinyCommandSuccessCount": ' Integer(advisorQuoteJsMetrics["residentTinyCommandSuccessCount"]) ", "
        . '"residentTinyCommandFallbackCount": ' Integer(advisorQuoteJsMetrics["residentTinyCommandFallbackCount"]) ", "
        . '"residentTinyPayloadLengthTotal": ' Integer(advisorQuoteJsMetrics["residentTinyPayloadLengthTotal"]) ", "
        . '"residentTinyPayloadLengthMax": ' Integer(advisorQuoteJsMetrics["residentTinyPayloadLengthMax"]) ", "
        . '"residentMutationAttemptCount": ' Integer(advisorQuoteJsMetrics["residentMutationAttemptCount"]) ", "
        . '"residentMutationSuccessCount": ' Integer(advisorQuoteJsMetrics["residentMutationSuccessCount"]) ", "
        . '"residentMutationFallbackCount": ' Integer(advisorQuoteJsMetrics["residentMutationFallbackCount"]) ", "
        . '"residentHealthCheckAttemptCount": ' Integer(advisorQuoteJsMetrics["residentHealthCheckAttemptCount"]) ", "
        . '"residentHealthCheckSuccessCount": ' Integer(advisorQuoteJsMetrics["residentHealthCheckSuccessCount"]) ", "
        . '"residentHealthCheckFallbackCount": ' Integer(advisorQuoteJsMetrics["residentHealthCheckFallbackCount"]) ", "
        . '"residentBootstrapByRoute": ' AdvisorQuoteMetricMapJson(advisorQuoteJsMetrics["residentBootstrapByRoute"]) ", "
        . '"residentTinyCommandByRoute": ' AdvisorQuoteMetricMapJson(advisorQuoteJsMetrics["residentTinyCommandByRoute"]) ", "
        . '"fullInjectionByRoute": ' AdvisorQuoteMetricMapJson(advisorQuoteJsMetrics["fullInjectionByRoute"]) ", "
        . '"residentContextRouteFamily": "' AdvisorQuoteJsonEscape(AdvisorQuoteJsMetricSafeToken(advisorQuoteJsMetrics["residentContextRouteFamily"], "unknown")) '", '
        . '"opGroupCount": ' Integer(advisorQuoteJsMetricOps.Count) ", "
        . '"residentRunnerEnabled": ' (AdvisorQuoteResidentRunnerEnabled() ? "true" : "false") ", "
        . '"residentOperatorTransportEnabled": ' (AdvisorQuoteResidentTransportEnabled() ? "true" : "false") ", "
        . '"residentOperatorReadOnlyEnabled": ' (AdvisorQuoteResidentReadOnlyTransportEnabled() ? "true" : "false") ", "
        . '"residentOperatorMutationEnabled": ' (AdvisorQuoteResidentMutationTransportEnabled() ? "true" : "false")
        . "}"
}

AdvisorQuoteBuildJsMetricRecordJson(record, indent := "") {
    return indent "{"
        . '"state": "' AdvisorQuoteJsonEscape(record["state"]) '", '
        . '"op": "' AdvisorQuoteJsonEscape(record["op"]) '", '
        . '"category": "' AdvisorQuoteJsonEscape(record["category"]) '", '
        . '"waitConditionName": "' AdvisorQuoteJsonEscape(record["waitConditionName"]) '", '
        . '"attemptCount": ' Integer(record["attemptCount"]) ", "
        . '"submittedCount": ' Integer(record["submittedCount"]) ", "
        . '"fullOperatorInjectionAttemptCount": ' Integer(record["fullOperatorInjectionAttemptCount"]) ", "
        . '"fullOperatorInjectionSubmittedCount": ' Integer(record["fullOperatorInjectionSubmittedCount"]) ", "
        . '"fullOperatorInjectionSubmittedLengthTotal": ' Integer(record["submittedLengthTotal"]) ", "
        . '"renderedLengthTotal": ' Integer(record["renderedLengthTotal"]) ", "
        . '"submittedLengthTotal": ' Integer(record["submittedLengthTotal"]) ", "
        . '"renderedLengthMax": ' Integer(record["renderedLengthMax"]) ", "
        . '"bridgeOpenedCount": ' Integer(record["bridgeOpenedCount"]) ", "
        . '"bridgeReusedCount": ' Integer(record["bridgeReusedCount"]) ", "
        . '"bridgeFailedCount": ' Integer(record["bridgeFailedCount"]) ", "
        . '"emptyResultCount": ' Integer(record["emptyResultCount"]) ", "
        . '"retryCount": ' Integer(record["retryCount"]) ", "
        . '"runnerTinyBridgeAttemptCount": ' Integer(record["runnerTinyBridgeAttemptCount"]) ", "
        . '"runnerTinyBridgeSuccessCount": ' Integer(record["runnerTinyBridgeSuccessCount"]) ", "
        . '"runnerTinyBridgeFallbackCount": ' Integer(record["runnerTinyBridgeFallbackCount"]) ", "
        . '"runnerTinyPayloadLengthTotal": ' Integer(record["runnerTinyPayloadLengthTotal"]) ", "
        . '"runnerTinyPayloadLengthMax": ' Integer(record["runnerTinyPayloadLengthMax"]) ", "
        . '"residentBootstrapAttemptCount": ' Integer(record["residentBootstrapAttemptCount"]) ", "
        . '"residentBootstrapSuccessCount": ' Integer(record["residentBootstrapSuccessCount"]) ", "
        . '"residentBootstrapFallbackCount": ' Integer(record["residentBootstrapFallbackCount"]) ", "
        . '"residentTinyCommandAttemptCount": ' Integer(record["residentTinyCommandAttemptCount"]) ", "
        . '"residentTinyCommandSuccessCount": ' Integer(record["residentTinyCommandSuccessCount"]) ", "
        . '"residentTinyCommandFallbackCount": ' Integer(record["residentTinyCommandFallbackCount"]) ", "
        . '"residentTinyPayloadLengthTotal": ' Integer(record["residentTinyPayloadLengthTotal"]) ", "
        . '"residentTinyPayloadLengthMax": ' Integer(record["residentTinyPayloadLengthMax"]) ", "
        . '"residentMutationAttemptCount": ' Integer(record["residentMutationAttemptCount"]) ", "
        . '"residentMutationSuccessCount": ' Integer(record["residentMutationSuccessCount"]) ", "
        . '"residentMutationFallbackCount": ' Integer(record["residentMutationFallbackCount"]) ", "
        . '"residentHealthCheckAttemptCount": ' Integer(record["residentHealthCheckAttemptCount"]) ", "
        . '"residentHealthCheckSuccessCount": ' Integer(record["residentHealthCheckSuccessCount"]) ", "
        . '"residentHealthCheckFallbackCount": ' Integer(record["residentHealthCheckFallbackCount"])
        . "}"
}

AdvisorQuoteBuildJsMetricHotOps(limit := 5) {
    global advisorQuoteJsMetricOps
    selected := Map()
    hotOps := []
    maxItems := Max(1, Integer(limit))

    Loop maxItems {
        bestKey := ""
        bestScore := -1
        for key, record in advisorQuoteJsMetricOps {
            if selected.Has(key)
                continue
            score := Integer(record["submittedLengthTotal"])
            if (score > bestScore) {
                bestScore := score
                bestKey := key
            }
        }
        if (bestKey = "")
            break
        selected[bestKey] := true
        hotOps.Push(advisorQuoteJsMetricOps[bestKey])
    }
    return hotOps
}

AdvisorQuoteLogJsMetricsSummary(reason := "run-end") {
    global advisorQuoteJsMetrics
    try {
        AdvisorQuoteEnsureJsMetricsCollector()
        AdvisorQuoteWriteJsMetricsFiles()
        submittedBytes := Integer(advisorQuoteJsMetrics["submittedLengthTotal"])
        AdvisorQuoteAppendLog(
            "ADVISOR_JS_METRICS_SUMMARY",
            AdvisorQuoteGetLastStep(),
            "runId=" AdvisorQuoteJsMetricSafeToken(advisorQuoteJsMetrics["runId"], "run")
                . ", reason=" AdvisorQuoteJsMetricSafeToken(reason, "run-end")
                . ", attempts=" Integer(advisorQuoteJsMetrics["attemptCount"])
                . ", submitted=" Integer(advisorQuoteJsMetrics["submittedCount"])
                . ", submittedBytes=" submittedBytes
                . ", submittedMiB=" Format("{:.2f}", submittedBytes / 1048576.0)
                . ", bridgeOpened=" Integer(advisorQuoteJsMetrics["bridgeOpenedCount"])
                . ", bridgeReused=" Integer(advisorQuoteJsMetrics["bridgeReusedCount"])
                . ", bridgeFailed=" Integer(advisorQuoteJsMetrics["bridgeFailedCount"])
                . ", emptyResults=" Integer(advisorQuoteJsMetrics["emptyResultCount"])
                . ", retries=" Integer(advisorQuoteJsMetrics["retryCount"])
                . ", runnerTinyAttempts=" Integer(advisorQuoteJsMetrics["runnerTinyBridgeAttemptCount"])
                . ", runnerTinySuccesses=" Integer(advisorQuoteJsMetrics["runnerTinyBridgeSuccessCount"])
                . ", runnerTinyFallbacks=" Integer(advisorQuoteJsMetrics["runnerTinyBridgeFallbackCount"])
                . ", runnerTinyPayloadBytes=" Integer(advisorQuoteJsMetrics["runnerTinyPayloadLengthTotal"])
                . ", residentBootstrapAttempts=" Integer(advisorQuoteJsMetrics["residentBootstrapAttemptCount"])
                . ", residentBootstrapSuccesses=" Integer(advisorQuoteJsMetrics["residentBootstrapSuccessCount"])
                . ", residentBootstrapFallbacks=" Integer(advisorQuoteJsMetrics["residentBootstrapFallbackCount"])
                . ", residentTinyAttempts=" Integer(advisorQuoteJsMetrics["residentTinyCommandAttemptCount"])
                . ", residentTinySuccesses=" Integer(advisorQuoteJsMetrics["residentTinyCommandSuccessCount"])
                . ", residentTinyFallbacks=" Integer(advisorQuoteJsMetrics["residentTinyCommandFallbackCount"])
                . ", residentTinyPayloadBytes=" Integer(advisorQuoteJsMetrics["residentTinyPayloadLengthTotal"])
                . ", residentMutationAttempts=" Integer(advisorQuoteJsMetrics["residentMutationAttemptCount"])
                . ", residentMutationSuccesses=" Integer(advisorQuoteJsMetrics["residentMutationSuccessCount"])
                . ", residentMutationFallbacks=" Integer(advisorQuoteJsMetrics["residentMutationFallbackCount"])
                . ", residentHealthAttempts=" Integer(advisorQuoteJsMetrics["residentHealthCheckAttemptCount"])
                . ", residentHealthSuccesses=" Integer(advisorQuoteJsMetrics["residentHealthCheckSuccessCount"])
                . ", residentHealthFallbacks=" Integer(advisorQuoteJsMetrics["residentHealthCheckFallbackCount"])
                . ", residentContextRouteFamily=" AdvisorQuoteJsMetricSafeToken(advisorQuoteJsMetrics["residentContextRouteFamily"], "unknown")
                . ", residentRunnerEnabled=" (AdvisorQuoteResidentRunnerEnabled() ? "1" : "0")
                . ", residentOperatorTransportEnabled=" (AdvisorQuoteResidentTransportEnabled() ? "1" : "0")
                . ", residentMutationEnabled=" (AdvisorQuoteResidentMutationTransportEnabled() ? "1" : "0")
        )
        AdvisorQuoteLogJsMetricsHotOps(3)
        AdvisorQuoteLogJsMetricsEmptyResults(5)
    } catch as err {
    }
}

AdvisorQuoteLogJsMetricsHotOps(limit := 3) {
    hotOps := AdvisorQuoteBuildJsMetricHotOps(limit)
    for index, record in hotOps {
        if (Integer(record["submittedLengthTotal"]) <= 0)
            continue
        AdvisorQuoteAppendLog(
            "ADVISOR_JS_METRICS_HOT_OP",
            record["state"],
            "rank=" index
                . ", op=" record["op"]
                . ", category=" record["category"]
                . ", waitConditionName=" record["waitConditionName"]
                . ", submittedBytes=" Integer(record["submittedLengthTotal"])
                . ", attempts=" Integer(record["attemptCount"])
                . ", emptyResults=" Integer(record["emptyResultCount"])
                . ", runnerTinyAttempts=" Integer(record["runnerTinyBridgeAttemptCount"])
                . ", runnerTinySuccesses=" Integer(record["runnerTinyBridgeSuccessCount"])
                . ", runnerTinyFallbacks=" Integer(record["runnerTinyBridgeFallbackCount"])
                . ", residentTinyAttempts=" Integer(record["residentTinyCommandAttemptCount"])
                . ", residentTinySuccesses=" Integer(record["residentTinyCommandSuccessCount"])
                . ", residentTinyFallbacks=" Integer(record["residentTinyCommandFallbackCount"])
        )
    }
}

AdvisorQuoteLogJsMetricsEmptyResults(limit := 5) {
    global advisorQuoteJsMetricOps
    emitted := 0
    for _, record in advisorQuoteJsMetricOps {
        emptyCount := Integer(record["emptyResultCount"])
        if (emptyCount <= 0)
            continue
        emitted += 1
        AdvisorQuoteAppendLog(
            "ADVISOR_JS_METRICS_EMPTY_RESULT",
            record["state"],
            "op=" record["op"]
                . ", category=" record["category"]
                . ", waitConditionName=" record["waitConditionName"]
                . ", emptyResults=" emptyCount
                . ", attempts=" Integer(record["attemptCount"])
        )
        if (emitted >= Integer(limit))
            break
    }
}

AdvisorQuoteIsJsActionOp(op) {
    actionOps := [
        "click_by_id",
        "click_by_text",
        "click_product_overview_tile",
        "click_customer_summary_start_here",
        "click_create_quotes_order_reports",
        "click_start_quoting_add_product",
        "handle_duplicate_prospect",
        "handle_address_verification",
        "focus_prospect_first_input",
        "fill_gather_defaults",
        "confirm_potential_vehicle",
        "prepare_vehicle_row",
        "select_vehicle_dropdown_option",
        "handle_vehicle_edit_modal",
        "ensure_auto_start_quoting_state",
        "set_select_product_defaults",
        "ensure_select_product_defaults",
        "click_select_product_continue",
        "asc_resolve_participant_marital_and_spouse",
        "asc_reconcile_driver_rows",
        "asc_reconcile_vehicle_rows",
        "fill_participant_modal",
        "select_remove_reason",
        "fill_vehicle_modal",
        "handle_incidents"
    ]
    return AdvisorQuoteIsStateInList(String(op), actionOps)
}

