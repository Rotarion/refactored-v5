; Advisor quote RAPPORT helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

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

