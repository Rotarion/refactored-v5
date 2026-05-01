#Requires AutoHotkey v2.0

AdvisorVehicleNormalizeText(value) {
    text := StrUpper(Trim(String(value ?? "")))
    text := StrReplace(text, "&", " AND ")
    text := RegExReplace(text, "[^A-Z0-9]+", " ")
    return Trim(RegExReplace(text, "\s+", " "))
}

AdvisorVehicleNormalizeMake(makeText) {
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
    model := RegExReplace(model, "\bCX\s+30\b", "CX30")
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
