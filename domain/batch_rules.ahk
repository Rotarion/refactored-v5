ParseBatchLeadRows(raw) {
    rows := []
    clean := StrReplace(raw, "`r", "")
    split := RegExReplace(clean, "i)(?=(?:DUPLICATED\s+(?:OPPORTUNITY\s+)?)?PERSONAL\s+LEAD)", "`n")

    for _, chunk in StrSplit(split, "`n") {
        chunk := Trim(chunk)
        if (chunk = "")
            continue
        if RegExMatch(chunk, "i)PERSONAL\s+LEAD")
            rows.Push(chunk)
    }
    return rows
}

ExtractLikelyLeadNameField(raw) {
    raw := StripGridActionText(raw)
    raw := Trim(StrReplace(StrReplace(raw, "`r", ""), "`n", " "))
    if (raw = "")
        return ""

    if RegExMatch(raw, "i)^\s*((?:DUPLICATED\s+)?(?:OPPORTUNITY\s+)?PERSONAL\s+LEAD\s*-\s*.*?)(?:\t|\s{2,}(?=\S)|$)", &m)
        return Trim(m[1])

    if RegExMatch(raw, "i)((?:DUPLICATED\s+)?(?:OPPORTUNITY\s+)?PERSONAL\s+LEAD\s*-\s*.*?)(?:\t|\s{2,}(?=\S)|$)", &m)
        return Trim(m[1])

    return raw
}

ExtractBatchName(raw) {
    prefixPattern := "i)^\s*(?:DUPLICATED\s+)?(?:OPPORTUNITY\s+)?PERSONAL\s+LEAD\s*-\s*"

    if IsLabeledLeadFormat(raw) {
        data := ParseLabeledLeadRaw(raw)

        if data.Has("Name") {
            name := CleanBatchNameCandidate(RegExReplace(data["Name"], prefixPattern, ""))
            if (name != "")
                return name
        }

        if data.Has("Contact") {
            name := CleanBatchNameCandidate(RegExReplace(data["Contact"], prefixPattern, ""))
            if (name != "")
                return name
        }

        first := data.Has("First Name") ? Trim(data["First Name"]) : ""
        last := data.Has("Last Name") ? Trim(data["Last Name"]) : ""
        name := CleanBatchNameCandidate(first . " " . last)
        if (name != "")
            return name
    }

    raw := ExtractLikelyLeadNameField(raw)
    raw := StripGridActionText(raw)
    raw := Trim(raw)

    if RegExMatch(raw, prefixPattern . "([^\t\r\n]+)", &m)
        return CleanBatchNameCandidate(m[1])

    return CleanBatchNameCandidate(raw)
}

CleanBatchNameCandidate(name) {
    name := Trim(StrReplace(StrReplace(name, "`r", ""), "`n", " "))
    if (name = "")
        return ""

    name := RegExReplace(name, "[\t\r\n].*$", "")
    name := RegExReplace(name, "i)\s{2,}(?=(?:new\s+(?:webform\s+folder|skyline\s+leads)\s*-\s*personal|(?:[A-Za-z]+\s+){0,3}(?:folder|leads?|source|status)\b(?:\s*-\s*[A-Za-z]+)?|\d+\s*-\s*(?:new|open|working|quoted|pending|closed|sold|contacted)|move\s+to\s+recycle\s+bin|recycle\s+bin|\d{1,2}/\d{1,2}/\d{2,4}\b)).*$", "")
    name := RegExReplace(name, "i)\s+(?:new\s+webform\s+folder\s*-\s*personal|new\s+skyline\s+leads\s*-\s*personal|move\s+to\s+recycle\s+bin|recycle\s+bin)\b.*$", "")
    name := RegExReplace(name, "i)\s+\d+\s*-\s*(?:new|open|working|quoted|pending|closed|sold|contacted)\b.*$", "")
    name := RegExReplace(name, "i)\s+(?:[A-Za-z]+\s+){0,3}(?:folder|leads?|source|status)\b(?:\s*-\s*[A-Za-z]+)?(?:\s+.*)?$", "")
    name := RegExReplace(name, "i)\s+\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?\b.*$", "")
    name := RegExReplace(name, "i)^\s*(?:DUPLICATED\s+)?(?:OPPORTUNITY\s+)?PERSONAL\s+LEAD\s*-\s*", "")
    name := RegExReplace(name, "\s{2,}", " ")
    return Trim(name, " -:`t`r`n")
}

ExtractBatchPhone(raw) {
    raw := Trim(String(raw ?? ""))
    if (raw = "")
        return ""

    ; Prefer explicit phone column when the source is a tab-delimited grid row.
    if InStr(raw, "`t") {
        cols := StrSplit(raw, "`t")
        if (cols.Length >= 9) {
            direct := NormalizePhone(cols[9])
            if (direct != "")
                return direct
        }

        for _, col in cols {
            candidate := NormalizePhone(col)
            if (candidate != "")
                return candidate
        }
    }

    if RegExMatch(raw, "\((\d{3})\)\s*(\d{3})-(\d{4})", &m)
        return m[1] . m[2] . m[3]

    if RegExMatch(raw, "(\+?1[\s\-\.\)]*)?\(?\d{3}\)?[\s\-\.\)]*\d{3}[\s\-\.]*\d{4}", &m2) {
        normalized := NormalizePhone(m2[0])
        if (normalized != "")
            return normalized
    }

    normalizedAll := NormalizePhone(raw)
    if (normalizedAll != "")
        return normalizedAll

    return ""
}

ExtractVehicleList(rawLead) {
    vehicles := []

    rawLead := StripGridActionText(rawLead)

    if InStr(rawLead, "`t") {
        vehicles := ExtractVehicleColumnsFromGridRow(rawLead)
        if (vehicles.Length > 0)
            return vehicles
    }

    vehicleText := ""
    if RegExMatch(rawLead, "i)(?:Male|Female)\s*(.*)", &m)
        vehicleText := Trim(m[1])

    if (vehicleText = "")
        return vehicles

    vehicleText := StripGridActionText(vehicleText)
    split := RegExReplace(vehicleText, "i)\s+(?=(?:19|20)\d{2}\s*[A-Za-z])", "`n")

    for _, part in StrSplit(split, "`n") {
        normalized := NormalizeVehicleCandidate(part)
        if (normalized != "")
            vehicles.Push(normalized)
    }

    return vehicles
}

ExtractVehicleColumnsFromGridRow(rawLead) {
    vehicles := []
    cols := StrSplit(rawLead, "`t")
    genderIndex := 0

    for i, col in cols {
        value := Trim(col)
        if RegExMatch(value, "i)^(Male|Female|M|F)$") {
            genderIndex := i
            break
        }
    }

    if (genderIndex = 0)
        return vehicles

    blankRun := 0
    Loop cols.Length - genderIndex {
        idx := genderIndex + A_Index
        if (idx > cols.Length)
            break

        rawCol := Trim(cols[idx])
        if RegExMatch(rawCol, "i)move\s+to\s+recycle\s+bin")
            break

        if (rawCol = "") {
            blankRun += 1
            if (blankRun >= 3 && vehicles.Length > 0)
                break
            continue
        }

        blankRun := 0
        normalized := NormalizeVehicleCandidate(rawCol)
        if (normalized != "")
            vehicles.Push(normalized)
    }

    return vehicles
}

NormalizeVehicleCandidate(text) {
    cleaned := CleanVehicleCandidate(text)
    if (cleaned = "")
        return ""

    hasYear := FindVehicleYearInText(cleaned) > 0
    hasKnownMake := HasKnownVehicleMake(cleaned)
    hasDobWords := RegExMatch(cleaned, "i)\b(age|born|nacido|years?\s+old|january|february|march|april|may|june|july|august|september|october|november|december|enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)\b")

    if (hasDobWords && !hasKnownMake)
        return ""
    if (!hasYear && !hasKnownMake)
        return ""

    cleaned := RegExReplace(cleaned, "i)\b(?:año|ano|year)\b", " ")

    if (hasYear && !RegExMatch(cleaned, "i)^\s*(19|20)\d{2}\b", &mLead)) {
        if RegExMatch(cleaned, "i)\b((19|20)\d{2})\b", &mYear) {
            cleaned := RegExReplace(cleaned, "i)\b" mYear[1] "\b", "",, 1)
            cleaned := RegExReplace(cleaned, "\s{2,}", " ")
            cleaned := Trim(cleaned, " ,-/")
            cleaned := mYear[1] . " " . cleaned
        }
    }

    cleaned := RegExReplace(cleaned, "\s{2,}", " ")
    cleaned := Trim(cleaned, " ,-/")
    if (cleaned = "")
        return ""

    return ProperCasePhrase(cleaned)
}

CleanVehicleCandidate(text) {
    text := StripGridActionText(text)
    text := Trim(StrReplace(StrReplace(text, "`r", " "), "`n", " "))
    text := RegExReplace(text, "\s*/\s*", " ")
    text := RegExReplace(text, "[,;]+", " ")
    text := RegExReplace(text, "i)\((?:[^)]*(?:confirm|confim|modelo|model|basic|basico|full|cover|pip|commercial|comercial)[^)]*)\)", "")
    text := RegExReplace(text, "i)\b(?:confirm|confim)\s+(?:model|modelo)\b.*$", "")
    text := RegExReplace(text, "i)\bconfirmar?\s+modelo\b.*$", "")
    text := RegExReplace(text, "i)\s*-\s*(?:full(?:\s+cover(?:age)?)?|basic(?:o)?(?:\s+pip)?|commercial|comercial)\b.*$", "")
    text := RegExReplace(text, "i)\b(?:full\s+cover(?:age)?|basic(?:o)?(?:\s+pip)?|commercial|comercial)\b", "")
    text := RegExReplace(text, "\s{2,}", " ")
    return Trim(text, " ,-/")
}

HasKnownVehicleMake(text) {
    return RegExMatch(text, "i)\b(acura|audi|bmw|buick|cadillac|chevrolet|chevy|chrysler|dodge|ford|gmc|geo|honda|hyundai|infiniti|infinity|isuzu|jeep|kia|land\s+rover|lexus|lincoln|mazda|mercedes(?:-benz)?|nissan|peugeot|ram|subaru|suzuki|tesla|toyota|volkswagen|volvo|pontiac|saturn|mini|mitsubishi|porsche|jaguar|fiat|scion|genesis)\b")
}

FindVehicleYearInText(text) {
    if RegExMatch(text, "i)\b((19|20)\d{2})\b", &m)
        return Integer(m[1])
    return 0
}

BuildBatchLeadRecord(rawLead) {
    global tagSymbol

    rawLead := StripGridActionText(rawLead)
    nameSource := ""

    if InStr(rawLead, "`t") {
        cols := StrSplit(rawLead, "`t")
        if (cols.Length >= 1) {
            firstCol := Trim(cols[1])
            if (firstCol != "")
                nameSource := firstCol
        }
    }

    if (nameSource = "")
        nameSource := ExtractLikelyLeadNameField(rawLead)

    batchName := ExtractBatchName(nameSource)
    batchPhone := ""
    if InStr(rawLead, "`t") {
        cols := StrSplit(rawLead, "`t")
        if (cols.Length >= 9)
            batchPhone := NormalizePhone(cols[9])
    }
    if (batchPhone = "")
        batchPhone := ExtractBatchPhone(rawLead)
    vehicles := ExtractVehicleList(rawLead)

    fullName := ProperCase(batchName)
    firstName := ExtractFirstName(fullName)

    parts := StrSplit(Trim(fullName), " ")
    lastName := (parts.Length >= 2) ? parts[parts.Length] : ""

    tagValue := Trim(tagSymbol)
    if (tagValue = "")
        tagValue := "+"

    holderName := tagValue . " " . fullName

    return Map(
        "RAW", rawLead,
        "FIELDS", Map("FIRST_NAME", firstName, "LAST_NAME", lastName, "PHONE", batchPhone),
        "FULL_NAME", fullName,
        "PHONE", batchPhone,
        "VEHICLES", vehicles,
        "VEHICLE_COUNT", vehicles.Length,
        "HOLDER_NAME", holderName,
        "TAG_VALUE", tagValue
    )
}

BuildBatchLeadHolder(raw) {
    global batchMinVehicles, batchMaxVehicles

    holder := []
    rows := ParseBatchLeadRows(raw)

    for _, row in rows {
        lead := BuildBatchLeadRecord(row)
        vc := lead["VEHICLE_COUNT"]

        if (lead["FULL_NAME"] = "" || lead["PHONE"] = "")
            continue
        if (vc < batchMinVehicles || vc > batchMaxVehicles)
            continue

        holder.Push(lead)
    }
    return holder
}

SanitizeVehicleLine(text) {
    text := StripGridActionText(text)
    text := RegExReplace(text, "\s*/\s*", " ")
    text := RegExReplace(text, "\s+", " ")
    text := RegExReplace(text, "[\t ]+$", "")
    return Trim(text)
}

StripGridActionText(text) {
    text := Trim(text)
    text := RegExReplace(text, "i)\bMove\s+To\s+Recycle\s+Bin\b", "")
    text := RegExReplace(text, "i)\bRecycle\s+Bin\b", "")
    text := RegExReplace(text, "\s{2,}", " ")
    return Trim(text, " `t-")
}
