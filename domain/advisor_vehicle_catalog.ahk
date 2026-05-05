#Requires AutoHotkey v2.0

AdvisorVehicleNormalizeText(value) {
    text := StrUpper(Trim(String(value ?? "")))
    text := StrReplace(text, "&", " AND ")
    text := RegExReplace(text, "[^A-Z0-9]+", " ")
    return Trim(RegExReplace(text, "\s+", " "))
}

AdvisorVehicleNormalizeMake(makeText) {
    make := AdvisorVehicleNormalizeText(makeText)
    return AdvisorVehicleNormalizeMakeFamily(make)
}

AdvisorVehicleNormalizeMakeFamily(makeText) {
    make := AdvisorVehicleNormalizeText(makeText)
    switch make {
        case "TOY", "TOY TRUCKS", "TOYOTA TRUCKS":
            return "TOYOTA"
        case "CHEVY", "CHEVY TRUCKS", "CHEVY VANS":
            return "CHEVROLET"
        case "MERCEDES", "MERCEDES BENZ", "MERCEDES BNZ", "MB":
            return "MERCEDES BENZ"
        case "FORD TRUCKS", "FORD VANS":
            return "FORD"
        case "DODGE TRUCKS", "DODGE VANS":
            return "DODGE"
        case "RAM TRUCKS", "RAM VANS":
            return "RAM"
    }
    return make
}

AdvisorVehicleNormalizeModel(modelText) {
    model := AdvisorVehicleNormalizeText(modelText)
    model := RegExReplace(model, "\bF\s+(150|250|350|450)\b", "F$1")
    model := RegExReplace(model, "\bCR\s+V\b", "CRV")
    model := RegExReplace(model, "\bHR\s+V\b", "HRV")
    model := RegExReplace(model, "\bCX\s+30\b", "CX30")
    model := RegExReplace(model, "\bQX\s+56\b", "QX56")
    model := RegExReplace(model, "\bGLE\s+350\b", "GLE350")
    model := RegExReplace(model, "\b4\s+RUNNER\b", "4RUNNER")
    model := RegExReplace(model, "\bGRAND\s+CARAVN\b", "GRAND CARAVAN")
    model := RegExReplace(model, "\bSILV\s*(1500|2500|3500)\b", "SILVERADO $1")
    return Trim(RegExReplace(model, "\s+", " "))
}

AdvisorVehicleModelKey(modelText) {
    model := AdvisorVehicleNormalizeModel(modelText)
    return RegExReplace(model, "[^A-Z0-9]", "")
}

AdvisorVehicleCatalogAllowedMakeLabels(make, model := "", year := "") {
    dbLabels := AdvisorVehicleDbAllowedMakeLabels(year, make, model)
    if (dbLabels.Length > 0)
        return dbLabels
    return AdvisorVehicleCatalogAllowedMakeLabelsFallback(make, model, year)
}

AdvisorVehicleCatalogAllowedMakeLabelsFallback(make, model := "", year := "") {
    normalizedMake := AdvisorVehicleNormalizeMake(make)
    normalizedModel := AdvisorVehicleNormalizeModel(model)
    labels := []

    switch normalizedMake {
        case "TOYOTA":
            labels.Push("TOYOTA")
            if AdvisorVehicleModelIn(normalizedModel, ["HIGHLANDER", "4RUNNER", "4 RUNNER", "RAV4", "C HR", "C-HR", "SEQUOIA", "TACOMA", "TUNDRA", "LANDCRUISER", "LAND CRUISER"])
                labels.Push("TOY. TRUCKS")
        case "FORD":
            labels.Push("FORD")
            if RegExMatch(AdvisorVehicleModelKey(normalizedModel), "^F(150|250|350|450)")
                labels.Push("FORD TRUCKS")
            else if RegExMatch(normalizedModel, "^TRANSIT\b")
                labels.Push("FORD VANS")
        case "CHEVROLET":
            labels.Push("CHEVROLET")
            if RegExMatch(normalizedModel, "^(SILVERADO|SILV)\b")
                labels.Push("CHEVY TRUCKS")
            else if RegExMatch(normalizedModel, "^(EXPRESS|CITY EXPRESS)\b")
                labels.Push("CHEVY VANS")
        case "DODGE":
            if RegExMatch(normalizedModel, "^RAM\s*(1500|2500|3500)\b") {
                labels.Push("RAM TRUCKS")
            } else if AdvisorVehicleModelIn(normalizedModel, ["CHARGER", "CHALLENGER", "VIPER"]) {
                labels.Push("DODGE")
            } else if AdvisorVehicleModelIn(normalizedModel, ["DURANGO", "JOURNEY"]) {
                labels.Push("DODGE TRUCKS")
            } else if AdvisorVehicleModelIn(normalizedModel, ["GRAND CARAVAN", "CARAVAN"]) {
                labels.Push("DODGE VANS")
            } else {
                labels.Push("DODGE")
            }
        case "RAM":
            if RegExMatch(normalizedModel, "^(1500|2500|3500)\b")
                labels.Push("RAM TRUCKS")
            else if InStr(normalizedModel, "PROMAST")
                labels.Push("RAM VANS")
            else
                labels.Push("RAM")
        case "MERCEDES BENZ":
            labels.Push("MERCEDES-BNZ")
        default:
            if (normalizedMake != "")
                labels.Push(normalizedMake)
    }

    return AdvisorVehicleUniqueLabels(labels)
}

AdvisorVehicleCatalogMakeMatches(expectedMake, observedMake, expectedModel := "", year := "") {
    observed := AdvisorVehicleNormalizeText(observedMake)
    if (observed = "")
        return false
    for _, label in AdvisorVehicleCatalogAllowedMakeLabels(expectedMake, expectedModel, year) {
        if (AdvisorVehicleNormalizeText(label) = observed)
            return true
    }
    return false
}

AdvisorVehicleCatalogModelMatches(expectedModel, observedModel) {
    expectedKey := AdvisorVehicleModelKey(expectedModel)
    observedKey := AdvisorVehicleModelKey(observedModel)
    return expectedKey != "" && expectedKey = observedKey
}

AdvisorVehicleAllowedMakeLabelsText(make, model := "", year := "") {
    return JoinArray(AdvisorVehicleCatalogAllowedMakeLabels(make, model, year), "|")
}

AdvisorVehicleModelIn(model, values) {
    modelKey := AdvisorVehicleModelKey(model)
    for _, value in values {
        if (modelKey = AdvisorVehicleModelKey(value))
            return true
    }
    return false
}

AdvisorVehicleUniqueLabels(labels) {
    result := []
    seen := Map()
    for _, label in labels {
        text := Trim(String(label ?? ""))
        key := AdvisorVehicleNormalizeText(text)
        if (text = "" || seen.Has(key))
            continue
        seen[key] := true
        result.Push(text)
    }
    return result
}

AdvisorVehicleDbPath() {
    candidates := [
        A_WorkingDir "\data\vehicle_db_runtime_index.tsv",
        A_ScriptDir "\data\vehicle_db_runtime_index.tsv",
        A_ScriptDir "\..\data\vehicle_db_runtime_index.tsv"
    ]
    for _, path in candidates {
        if FileExist(path)
            return path
    }
    return candidates[1]
}

AdvisorVehicleDbLoad() {
    static cache := ""
    if IsObject(cache)
        return cache

    path := AdvisorVehicleDbPath()
    cache := Map(
        "loaded", false,
        "path", path,
        "error", "",
        "meta", Map(),
        "records", [],
        "recordsByYearMake", Map(),
        "makeLabelsByYearFamily", Map()
    )

    if !FileExist(path) {
        cache["error"] := "missing-runtime-index"
        return cache
    }

    try {
        text := FileRead(path, "UTF-8")
    } catch as err {
        cache["error"] := "read-failed:" err.Message
        return cache
    }

    for _, rawLine in StrSplit(text, "`n", "`r") {
        line := Trim(rawLine, "`r`n")
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        parts := StrSplit(line, "`t", , 10)
        if (parts.Length < 1)
            continue
        if (parts[1] = "META" && parts.Length >= 3) {
            cache["meta"][parts[2]] := parts[3]
            continue
        }
        if (parts[1] != "RECORD" || parts.Length < 10)
            continue

        record := Map(
            "year", parts[2],
            "makeLabel", parts[3],
            "makeFamily", parts[4],
            "dbModel", parts[5],
            "canonicalModel", parts[6],
            "modelKey", parts[7],
            "baseKey", parts[8],
            "aliases", parts[9],
            "aliasKeys", parts[10]
        )
        cache["records"].Push(record)
        AdvisorVehicleDbPushRecord(cache, parts[2], parts[3], record)
        AdvisorVehicleDbPushRecord(cache, parts[2], parts[4], record)
        AdvisorVehicleDbPushMakeLabel(cache, parts[2], parts[4], parts[3])
    }

    if (cache["records"].Length = 0) {
        cache["error"] := "no-runtime-records"
        return cache
    }
    cache["loaded"] := true
    return cache
}

AdvisorVehicleDbGet() {
    return AdvisorVehicleDbLoad()
}

AdvisorVehicleDbPushRecord(cache, year, make, record) {
    key := Trim(String(year)) "|" AdvisorVehicleNormalizeText(make)
    if !cache["recordsByYearMake"].Has(key)
        cache["recordsByYearMake"][key] := []
    cache["recordsByYearMake"][key].Push(record)
}

AdvisorVehicleDbPushMakeLabel(cache, year, makeFamily, makeLabel) {
    key := Trim(String(year)) "|" AdvisorVehicleNormalizeText(makeFamily)
    if !cache["makeLabelsByYearFamily"].Has(key)
        cache["makeLabelsByYearFamily"][key] := []
    labels := cache["makeLabelsByYearFamily"][key]
    labelKey := AdvisorVehicleNormalizeText(makeLabel)
    for _, existing in labels {
        if (AdvisorVehicleNormalizeText(existing) = labelKey)
            return
    }
    labels.Push(makeLabel)
}

AdvisorVehicleDbNormalizeModelKey(model) {
    return AdvisorVehicleModelKey(model)
}

AdvisorVehicleDbCandidateMakeLabels(year, make, model := "") {
    cache := AdvisorVehicleDbLoad()
    fallback := AdvisorVehicleCatalogAllowedMakeLabelsFallback(make, model, year)
    labels := []
    normalizedYear := Trim(String(year ?? ""))
    family := AdvisorVehicleNormalizeMakeFamily(make)
    if (cache["loaded"] && normalizedYear != "" && family != "") {
        key := normalizedYear "|" family
        if cache["makeLabelsByYearFamily"].Has(key) {
            for _, label in cache["makeLabelsByYearFamily"][key]
                labels.Push(label)
        }
    }
    for _, label in fallback
        labels.Push(label)
    return AdvisorVehicleUniqueLabels(labels)
}

AdvisorVehicleDbAllowedMakeLabels(year, make, model := "") {
    resolved := AdvisorVehicleDbResolveLeadVehicle(year, make, model)
    if IsObject(resolved) && resolved.Has("advisorMakeLabels") && resolved["advisorMakeLabels"].Length > 0
        return resolved["advisorMakeLabels"]
    return []
}

AdvisorVehicleDbModelAliases(year, make, model) {
    resolved := AdvisorVehicleDbResolveLeadVehicle(year, make, model)
    if IsObject(resolved) && resolved.Has("modelAliases") && resolved["modelAliases"].Length > 0
        return resolved["modelAliases"]
    normalized := AdvisorVehicleNormalizeModel(model)
    return normalized = "" ? [] : [normalized]
}

AdvisorVehicleDbResolveLeadVehicle(year, make, model, vin := "") {
    cache := AdvisorVehicleDbLoad()
    normalizedYear := Trim(String(year ?? ""))
    inputMake := Trim(String(make ?? ""))
    inputModel := Trim(String(model ?? ""))
    inputKey := AdvisorVehicleDbNormalizeModelKey(inputModel)
    makeFamily := AdvisorVehicleNormalizeMakeFamily(inputMake)
    labels := AdvisorVehicleDbCandidateMakeLabels(normalizedYear, inputMake, inputModel)
    base := AdvisorVehicleDbEmptyResolution(normalizedYear, inputMake, inputModel, vin, labels)

    if !cache["loaded"] {
        base["result"] := "UNKNOWN"
        base["reason"] := "db-load-failed:" cache["error"]
        return base
    }
    if (normalizedYear = "") {
        base["result"] := "PARTIAL"
        base["reason"] := "year-missing"
        return base
    }
    if (makeFamily = "") {
        base["result"] := "UNKNOWN"
        base["reason"] := "make-missing"
        return base
    }
    if (inputKey = "") {
        base["result"] := "PARTIAL"
        base["canonicalMake"] := makeFamily
        base["reason"] := "model-missing"
        return base
    }

    candidateRecords := []
    seenRecord := Map()
    for _, label in labels {
        key := normalizedYear "|" AdvisorVehicleNormalizeText(label)
        if !cache["recordsByYearMake"].Has(key)
            continue
        for _, record in cache["recordsByYearMake"][key] {
            recordKey := record["year"] "|" record["makeLabel"] "|" record["dbModel"]
            if seenRecord.Has(recordKey)
                continue
            if AdvisorVehicleDbRecordMatchesInput(record, inputKey, inputModel) {
                seenRecord[recordKey] := true
                candidateRecords.Push(record)
            }
        }
    }

    if (candidateRecords.Length = 0) {
        ambiguousRecords := AdvisorVehicleDbFindBroadAmbiguousCandidates(cache, normalizedYear, labels, inputKey)
        if (ambiguousRecords.Length > 1) {
            base["result"] := "AMBIGUOUS"
            base["canonicalMake"] := makeFamily
            base["possibleMatches"] := AdvisorVehicleDbPossibleMatchSummaries(ambiguousRecords)
            base["reason"] := "broad-db-model-prefix"
            base["confidence"] := "0.00"
            return base
        }
        base["result"] := "UNKNOWN"
        base["canonicalMake"] := makeFamily
        base["reason"] := "no-db-model-match"
        return base
    }

    grouped := Map()
    for _, record in candidateRecords {
        groupKey := record["year"] "|" record["makeFamily"] "|" AdvisorVehicleDbLeadModelGroupKey(record, inputKey)
        if !grouped.Has(groupKey)
            grouped[groupKey] := []
        grouped[groupKey].Push(record)
    }

    possible := []
    for groupKey, records in grouped {
        first := records[1]
        possible.Push(first["year"] " " first["makeLabel"] " " first["dbModel"])
    }
    base["possibleMatches"] := possible

    if (grouped.Count > 1) {
        base["result"] := "AMBIGUOUS"
        base["canonicalMake"] := makeFamily
        base["reason"] := "multiple-db-model-groups"
        base["confidence"] := "0.00"
        return base
    }

    selectedRecords := ""
    for _, records in grouped {
        selectedRecords := records
        break
    }
    first := selectedRecords[1]
    aliases := AdvisorVehicleDbFilteredAliases(selectedRecords, inputKey, inputModel)
    keys := AdvisorVehicleDbAliasKeys(aliases)
    base["result"] := "RESOLVED"
    base["canonicalMake"] := first["makeFamily"]
    base["canonicalModel"] := first["canonicalModel"]
    base["advisorMakeLabels"] := labels
    base["modelAliases"] := aliases
    base["normalizedModelKeys"] := keys
    base["confidence"] := "0.95"
    base["reason"] := "db-unique-model-group"
    return base
}

AdvisorVehicleDbFindBroadAmbiguousCandidates(cache, year, labels, inputKey) {
    if (StrLen(inputKey) < 4)
        return []
    groups := Map()
    for _, label in labels {
        key := year "|" AdvisorVehicleNormalizeText(label)
        if !cache["recordsByYearMake"].Has(key)
            continue
        for _, record in cache["recordsByYearMake"][key] {
            if !(InStr(record["modelKey"], inputKey) = 1 || InStr(record["baseKey"], inputKey) = 1 || AdvisorVehicleDbAnyAliasKeyStartsWith(record["aliasKeys"], inputKey))
                continue
            groupKey := record["year"] "|" record["makeFamily"] "|" record["baseKey"]
            if !groups.Has(groupKey)
                groups[groupKey] := record
        }
    }
    records := []
    for _, record in groups
        records.Push(record)
    return records
}

AdvisorVehicleDbAnyAliasKeyStartsWith(listText, inputKey) {
    for _, item in StrSplit(String(listText ?? ""), "|") {
        item := Trim(item)
        if (item != "" && InStr(item, inputKey) = 1)
            return true
    }
    return false
}

AdvisorVehicleDbPossibleMatchSummaries(records) {
    possible := []
    for _, record in records {
        possible.Push(record["year"] " " record["makeLabel"] " " record["dbModel"])
        if (possible.Length >= 8)
            break
    }
    return possible
}

AdvisorVehicleDbEmptyResolution(year, make, model, vin, labels := "") {
    return Map(
        "result", "UNKNOWN",
        "year", Trim(String(year ?? "")),
        "inputMake", Trim(String(make ?? "")),
        "inputModel", Trim(String(model ?? "")),
        "vin", Trim(String(vin ?? "")),
        "canonicalMake", "",
        "canonicalModel", "",
        "advisorMakeLabels", IsObject(labels) ? labels : [],
        "modelAliases", [],
        "normalizedModelKeys", [],
        "possibleMatches", [],
        "confidence", "0.00",
        "reason", ""
    )
}

AdvisorVehicleDbRecordMatchesInput(record, inputKey, inputModel) {
    if (inputKey = "")
        return false
    if (record["modelKey"] = inputKey || record["baseKey"] = inputKey)
        return true
    if AdvisorVehicleDbListContains(record["aliasKeys"], inputKey)
        return true
    return false
}

AdvisorVehicleDbLeadModelGroupKey(record, inputKey) {
    if RegExMatch(inputKey, "^(F150|F250|F350|F450)$")
        return inputKey
    if RegExMatch(inputKey, "^(SILVERADO1500|SILVERADO2500|SILVERADO3500)$")
        return inputKey
    if RegExMatch(inputKey, "^(1500|2500|3500)$")
        return inputKey
    if InStr(inputKey, "PRIUSPRIME")
        return "PRIUSPRIME"
    if InStr(inputKey, "WRANGLERUNLIMIT")
        return "WRANGLERUNLIMITED"
    if InStr(inputKey, "WRANGLERUNLIMITE")
        return "WRANGLERUNLIMITED"
    return record["baseKey"]
}

AdvisorVehicleDbFilteredAliases(records, inputKey, inputModel) {
    aliases := []
    inputText := AdvisorVehicleNormalizeModel(inputModel)
    if (inputText != "")
        aliases.Push(inputText)
    for _, record in records {
        for _, alias in StrSplit(record["aliases"], "|") {
            alias := Trim(alias)
            aliasKey := AdvisorVehicleDbNormalizeModelKey(alias)
            if (alias = "" || aliasKey = "")
                continue
            if !AdvisorVehicleDbAliasSafeForInput(inputKey, aliasKey)
                continue
            aliases.Push(alias)
        }
    }
    return AdvisorVehicleUniqueLabels(aliases)
}

AdvisorVehicleDbAliasSafeForInput(inputKey, aliasKey) {
    if (inputKey = "")
        return false
    if (inputKey = "PRIUS" && InStr(aliasKey, "PRIUSPRIME"))
        return false
    if (InStr(inputKey, "PRIUSPRIME"))
        return InStr(aliasKey, "PRIUSPRIME") || aliasKey = inputKey
    if (inputKey = "TRANSIT" && InStr(aliasKey, "TRANSITCONNECT"))
        return false
    if RegExMatch(inputKey, "^F(150|250|350|450)$")
        return RegExMatch(aliasKey, "^" inputKey "($|2WD$|4WD$)") || aliasKey = inputKey
    if RegExMatch(inputKey, "^SILVERADO(1500|2500|3500)$")
        return InStr(aliasKey, inputKey)
    if InStr(inputKey, "WRANGLERUNLIMIT") || InStr(inputKey, "WRANGLERUNLIMITE")
        return InStr(aliasKey, "WRANGLERUNLIMIT") || InStr(aliasKey, "WRANGLERUNLIMITE") || InStr(aliasKey, "WRANGLERUNLTD") || aliasKey = "WRANGLER"
    return true
}

AdvisorVehicleDbAliasKeys(aliases) {
    keys := []
    seen := Map()
    for _, alias in aliases {
        key := AdvisorVehicleDbNormalizeModelKey(alias)
        if (key = "" || seen.Has(key))
            continue
        seen[key] := true
        keys.Push(key)
    }
    return keys
}

AdvisorVehicleDbListContains(listText, wanted) {
    wanted := Trim(String(wanted ?? ""))
    if (wanted = "")
        return false
    for _, item in StrSplit(String(listText ?? ""), "|") {
        if (Trim(item) = wanted)
            return true
    }
    return false
}

AdvisorVehicleDbScoreAdvisorCard(resolvedVehicle, cardTextOrObject) {
    text := ""
    if (IsObject(cardTextOrObject) && cardTextOrObject.Has("text"))
        text := cardTextOrObject["text"]
    else
        text := String(cardTextOrObject ?? "")
    haystack := AdvisorVehicleNormalizeText(text)
    year := IsObject(resolvedVehicle) && resolvedVehicle.Has("year") ? Trim(String(resolvedVehicle["year"])) : ""
    labels := IsObject(resolvedVehicle) && resolvedVehicle.Has("advisorMakeLabels") ? resolvedVehicle["advisorMakeLabels"] : []
    keys := IsObject(resolvedVehicle) && resolvedVehicle.Has("normalizedModelKeys") ? resolvedVehicle["normalizedModelKeys"] : []
    vin := IsObject(resolvedVehicle) && resolvedVehicle.Has("vin") ? AdvisorVehicleNormalizeText(resolvedVehicle["vin"]) : ""
    yearMatch := year != "" && RegExMatch(haystack, "(^|\s)" year "(\s|$)")
    makeMatch := false
    for _, label in labels {
        labelText := AdvisorVehicleNormalizeText(label)
        if (labelText != "" && RegExMatch(haystack, "(^|\s)" labelText "(\s|$)")) {
            makeMatch := true
            break
        }
    }
    modelMatch := false
    haystackKey := AdvisorVehicleDbNormalizeModelKey(haystack)
    for _, key in keys {
        if (key != "" && InStr(haystackKey, key)) {
            modelMatch := true
            break
        }
    }
    vinMatch := vin != "" && InStr(AdvisorVehicleNormalizeText(text), vin)
    score := (yearMatch ? 40 : 0) + (makeMatch ? 30 : 0) + (modelMatch ? 30 : 0) + (vinMatch ? 50 : 0)
    return Map(
        "score", score,
        "yearMatch", yearMatch ? "1" : "0",
        "makeMatch", makeMatch ? "1" : "0",
        "modelMatch", modelMatch ? "1" : "0",
        "vinMatch", vinMatch ? "1" : "0"
    )
}

AdvisorVehicleDbBuildJsVehicleArgs(resolvedVehicle) {
    args := Map(
        "year", resolvedVehicle["year"],
        "make", resolvedVehicle["inputMake"],
        "model", resolvedVehicle["inputModel"],
        "allowedMakeLabels", JoinArray(resolvedVehicle["advisorMakeLabels"], "|"),
        "advisorMakeLabels", JoinArray(resolvedVehicle["advisorMakeLabels"], "|"),
        "modelAliases", JoinArray(resolvedVehicle["modelAliases"], "|"),
        "normalizedModelKeys", JoinArray(resolvedVehicle["normalizedModelKeys"], "|"),
        "strictModelMatch", "1",
        "dbResult", resolvedVehicle["result"],
        "dbReason", resolvedVehicle["reason"],
        "canonicalMake", resolvedVehicle["canonicalMake"],
        "canonicalModel", resolvedVehicle["canonicalModel"]
    )
    if (resolvedVehicle.Has("vin"))
        args["vin"] := resolvedVehicle["vin"]
    return args
}
