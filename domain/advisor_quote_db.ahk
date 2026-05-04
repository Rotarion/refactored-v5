GetAdvisorQuoteWorkflowDb() {
    selectors := Map(
        "advisorQuotingButtonId", "group2_Quoting_button",
        "searchCreateNewProspectId", "outOfLocationCreateNewProspectButton",
        "beginQuotingContinueId", "PrimaryApplicant-Continue-button",
        "prospectFirstNameId", "ConsumerData.People[0].Name.GivenName",
        "prospectLastNameId", "ConsumerData.People[0].Name.Surname",
        "prospectDobId", "ConsumerData.People[0].Personal.BirthDt",
        "prospectGenderId", "ConsumerData.People[0].Personal.GenderCd.SrcCd",
        "prospectAddressId", "ConsumerData.Assets.Properties[0].Addr.Addr1",
        "prospectCityId", "ConsumerData.Assets.Properties[0].Addr.City",
        "prospectStateId", "ConsumerData.Assets.Properties[0].Addr.StateProvCd.SrcCd",
        "prospectZipId", "ConsumerData.Assets.Properties[0].Addr.PostalCode",
        "prospectPhoneId", "ConsumerData.People[0].Communications.PhoneNumber",
        "sidebarAddProductId", "addProduct",
        "quoteBlockAddProductId", "quotesButton",
        "createQuotesButtonId", "consentModalTrigger",
        "selectProductRatingStateId", "SelectProduct.RatingState",
        "selectProductProductId", "SelectProduct.Product",
        "selectProductContinueId", "selectProductContinue",
        "consumerReportsConsentYesId", "orderReportsConsent-yes-btn",
        "driverVehicleContinueId", "profile-summary-submitBtn",
        "participantSaveId", "PARTICIPANT_SAVE-btn",
        "removeParticipantSaveId", "REMOVE_PARTICIPANT_SAVE-btn",
        "addAssetSaveId", "ADD_ASSET_SAVE-btn",
        "confirmVehicleId", "confirmNewVehicle",
        "incidentContinueId", "CONTINUE_OFFER-btn",
        "incidentBackId", "BACK_TO_PROFILE_SUMMARY-btn"
    )

    defaults := Map(
        "ratingState", "FL",
        "currentInsured", "YES",
        "ownOrRent", "OWN",
        "consumerReportsConsent", "yes",
        "ageFirstLicensed", "16",
        "gatherResidenceOwnedRentedRentValue", "RE",
        "gatherResidenceTypeApartmentValue", "AP",
        "gatherResidenceTypeSingleFamilyValue", "SF",
        "military", "false",
        "violations", "false",
        "defensiveDriving", "false",
        "propertyOwnershipOwnHome", "0001_0120",
        "propertyOwnershipRent", "0002_0120",
        "garagingSameAsHome", "yes",
        "recentPurchase", "false",
        "driverRemoveReasonCode", "0006",
        "incidentReasonText", "Accident caused by being hit by animal or road debris",
        "vehicleFinanceYearThreshold", 2015
    )

    timeouts := Map(
        "shortMs", 1200,
        "actionMs", 4000,
        "pageMs", 25000,
        "transitionMs", 35000,
        "pollMs", 350,
        "maxRetries", 3
    )

    urls := Map(
        "rapportContains", "/rapport",
        "customerSummaryContains", "/apps/customer-summary/",
        "productOverviewContains", "/apps/intel/102/overview",
        "selectProductContains", "/selectProduct",
            "ascProductContains", "/ASCPRODUCT/"
    )

    texts := Map(
        "duplicateHeading", "This Prospect May Already Exist",
        "customerSummaryStartHereText", "START HERE (Pre-fill included)",
        "customerSummaryQuoteHistoryText", "Quote History",
        "customerSummaryAssetsDetailsText", "Assets Details",
        "productOverviewHeading", "Select Product",
        "productOverviewAutoTile", "Auto",
        "productOverviewContinueText", "Save & Continue to Gather Data",
        "selectProductCurrentInsuredQuestion", "Is the customer currently insured?",
        "selectProductAnswerYesText", "Yes",
        "driversVehiclesHeading", "Drivers and vehicles",
        "incidentsHeading", "Incidents",
        "consumerReportsHeading", "order consumer reports",
        "marriedLabel", "Married",
        "spouseSelectId", "maritalStatusWithSpouse_spouseName"
    )

    return Map(
        "selectors", selectors,
        "defaults", defaults,
        "timeouts", timeouts,
        "urls", urls,
        "texts", texts
    )
}

AdvisorBuildVehicleDisplayKey(year, make, model) {
    y := Trim(String(year))
    mk := AdvisorNormalizeLooseToken(make)
    md := AdvisorNormalizeVehicleModelToken(model)
    if (y = "" || mk = "" || md = "")
        return ""
    return y "|" mk "|" md
}

AdvisorNormalizeVehicleModelToken(text) {
    token := AdvisorNormalizeLooseToken(text)
    if RegExMatch(token, "^F\s+(\d{3,4})$", &m)
        return "F" m[1]
    if RegExMatch(token, "^F(\d{3,4})$", &m)
        return "F" m[1]
    return token
}

AdvisorCanonicalizeVehicleModelAndTrim(model, trimHint := "") {
    normalizedModel := AdvisorNormalizeVehicleModelToken(model)
    normalizedTrim := AdvisorNormalizeLooseToken(trimHint)
    if (normalizedModel = "F" && RegExMatch(normalizedTrim, "^(\d{3,4})(?:\s+(.*))?$", &m)) {
        remainingTrim := (m.Count >= 2) ? m[2] : ""
        normalizedModel := "F" m[1]
        normalizedTrim := Trim(String(remainingTrim))
    } else if (normalizedModel = "CR" && RegExMatch(normalizedTrim, "^V(?:\s+(.*))?$", &m)) {
        remainingTrim := (m.Count >= 1) ? m[1] : ""
        normalizedModel := "CRV"
        normalizedTrim := Trim(String(remainingTrim))
    } else if (normalizedModel = "HR" && RegExMatch(normalizedTrim, "^V(?:\s+(.*))?$", &m)) {
        remainingTrim := (m.Count >= 1) ? m[1] : ""
        normalizedModel := "HRV"
        normalizedTrim := Trim(String(remainingTrim))
    } else if (normalizedModel = "CX" && RegExMatch(normalizedTrim, "^(\d{2})(?:\s+(.*))?$", &m)) {
        remainingTrim := (m.Count >= 2) ? m[2] : ""
        normalizedModel := "CX" m[1]
        normalizedTrim := Trim(String(remainingTrim))
    } else if (normalizedModel = "QX" && RegExMatch(normalizedTrim, "^(\d{2})(?:\s+(.*))?$", &m)) {
        remainingTrim := (m.Count >= 2) ? m[2] : ""
        normalizedModel := "QX" m[1]
        normalizedTrim := Trim(String(remainingTrim))
    } else if (normalizedModel = "GLE" && RegExMatch(normalizedTrim, "^(\d{3})(?:\s+(.*))?$", &m)) {
        remainingTrim := (m.Count >= 2) ? m[2] : ""
        normalizedModel := "GLE" m[1]
        normalizedTrim := Trim(String(remainingTrim))
    } else if (normalizedModel = "4" && RegExMatch(normalizedTrim, "^RUNNER(?:\s+(.*))?$", &m)) {
        remainingTrim := (m.Count >= 1) ? m[1] : ""
        normalizedModel := "4RUNNER"
        normalizedTrim := Trim(String(remainingTrim))
    }
    return Map(
        "model", normalizedModel,
        "trimHint", normalizedTrim
    )
}

AdvisorTrimVehicleDescriptorTail(text) {
    value := Trim(String(text ?? ""))
    if (value = "")
        return ""
    cutAt := 0
    labelPatterns := [
        "\bDriver\s*\d+\s+Name\s*[-:]?\s*Age\b",
        "\bDriver\s*\d+\s+Name\b",
        "\bCalidad\b",
        "\bIdioma\b",
        "\bAddress\s+Verified\b",
        "\bCuando\s+Renueva\b",
        "\bOpen\s+The\s+Calendar\b",
        "\bQue\s+Cobertura\b",
        "\bCurrent\s+Insurance\s+Company\b",
        "\bSkyline\s+Agent\b",
        "\bSource\s*:"
    ]
    for _, pattern in labelPatterns {
        pos := RegExMatch(value, "i)" pattern)
        if (pos > 1 && (cutAt = 0 || pos < cutAt))
            cutAt := pos
    }
    return (cutAt > 1) ? Trim(SubStr(value, 1, cutAt - 1)) : value
}

AdvisorNormalizeVehicleDescriptor(rawVehicle) {
    text := Trim(String(rawVehicle ?? ""))
    text := RegExReplace(text, "\s+", " ")
    if (text = "")
        return Map("raw", rawVehicle, "year", "", "make", "", "model", "", "trimHint", "", "vin", "", "vinSuffix", "", "displayKey", "")

    vin := ""
    if RegExMatch(StrUpper(text), "\b([A-HJ-NPR-Z0-9]{17})\b", &mv)
        vin := mv[1]
    vinSuffix := (StrLen(vin) >= 6) ? SubStr(vin, StrLen(vin) - 5) : ""
    parseText := (vin != "") ? Trim(RegExReplace(text, "i)\b" . vin . "\b", "")) : text
    parseText := AdvisorTrimVehicleDescriptorTail(parseText)

    year := ""
    if RegExMatch(parseText, "i)\b((19|20)\d{2})\b", &my)
        year := my[1]

    withoutYear := (year != "") ? Trim(RegExReplace(parseText, "i)\b" year "\b", "")) : parseText
    withoutYear := RegExReplace(withoutYear, "[-_/]", " ")
    withoutYear := RegExReplace(withoutYear, "\s+", " ")
    withoutYear := Trim(withoutYear)

    make := ""
    model := ""
    trimHint := ""

    if (withoutYear != "") {
        upper := StrUpper(withoutYear)
        makes := AdvisorGetKnownVehicleMakes()
        for _, knownMake in makes {
            if (RegExMatch(upper, "^" . knownMake . "(?:\s|$)")) {
                make := knownMake
                remainder := Trim(SubStr(withoutYear, StrLen(knownMake) + 1))
                tokens := StrSplit(remainder, " ")
                if (tokens.Length >= 1)
                    model := StrUpper(tokens[1])
                if (tokens.Length > 1) {
                    extra := []
                    Loop tokens.Length - 1
                        extra.Push(tokens[A_Index + 1])
                    trimHint := StrUpper(Trim(JoinArray(extra, " ")))
                }
                canonical := AdvisorCanonicalizeVehicleModelAndTrim(model, trimHint)
                model := canonical["model"]
                trimHint := canonical["trimHint"]
                break
            }
        }
    }

    if (make = "") {
        tokens := StrSplit(withoutYear, " ")
        if (tokens.Length >= 1)
            make := StrUpper(tokens[1])
        if (tokens.Length >= 2)
            model := StrUpper(tokens[2])
        if (tokens.Length > 2) {
            extra2 := []
            Loop tokens.Length - 2
                extra2.Push(tokens[A_Index + 2])
            trimHint := StrUpper(Trim(JoinArray(extra2, " ")))
        }
        canonical := AdvisorCanonicalizeVehicleModelAndTrim(model, trimHint)
        model := canonical["model"]
        trimHint := canonical["trimHint"]
    }

    make := AdvisorNormalizeLooseToken(make)
    model := AdvisorNormalizeVehicleModelToken(model)
    trimHint := AdvisorNormalizeLooseToken(trimHint)
    canonical := AdvisorCanonicalizeVehicleModelAndTrim(model, trimHint)
    model := canonical["model"]
    trimHint := canonical["trimHint"]
    displayKey := AdvisorBuildVehicleDisplayKey(year, make, model)

    return Map(
        "raw", text,
        "year", year,
        "make", make,
        "model", model,
        "trimHint", trimHint,
        "vin", vin,
        "vinSuffix", vinSuffix,
        "displayKey", displayKey
    )
}

AdvisorGetKnownVehicleMakes() {
    static makes := ""
    if (Type(makes) = "Array")
        return makes

    makes := [
        "MERCEDES BENZ",
        "LAND ROVER",
        "ALFA ROMEO",
        "ROLLS ROYCE",
        "ASTON MARTIN",
        "CHEVY TRUCKS",
        "CHEVY VANS",
        "FORD TRUCKS",
        "FORD VANS",
        "DODGE TRUCKS",
        "DODGE VANS",
        "TOYOTA",
        "TOY TRUCKS",
        "NISSAN",
        "HONDA",
        "HYUNDAI",
        "KIA",
        "MAZDA",
        "SUBARU",
        "VOLKSWAGEN",
        "VOLVO",
        "LEXUS",
        "ACURA",
        "INFINITI",
        "MITSUBISHI",
        "CHEVROLET",
        "FORD",
        "GMC",
        "RAM TRUCKS",
        "RAM VANS",
        "JEEP",
        "TESLA",
        "BMW",
        "AUDI",
        "BUICK",
        "CADILLAC",
        "CHRYSLER",
        "DODGE",
        "FIAT",
        "GENESIS",
        "JAGUAR",
        "LINCOLN",
        "MINI",
        "PORSCHE"
    ]

    for i, make in makes
        makes[i] := StrUpper(make)
    return makes
}

AdvisorNormalizeLooseToken(text) {
    token := Trim(String(text ?? ""))
    token := StrUpper(token)
    token := RegExReplace(token, "[^A-Z0-9 ]", " ")
    token := RegExReplace(token, "\s+", " ")
    return Trim(token)
}

AdvisorNormalizeAddressForMatch(text) {
    value := Trim(String(text ?? ""))
    value := StrUpper(value)
    value := RegExReplace(value, "[^A-Z0-9 ]", " ")
    value := RegExReplace(value, "\s+", " ")
    return Trim(value)
}

AdvisorExtractStreetNumber(text) {
    normalized := AdvisorNormalizeAddressForMatch(text)
    if RegExMatch(normalized, "^\s*(\d+)\b", &m)
        return m[1]
    return ""
}

AdvisorScoreDuplicateCandidate(candidateText, profile) {
    text := AdvisorNormalizeAddressForMatch(candidateText)
    if (text = "")
        return -1

    person := profile.Has("person") ? profile["person"] : Map()
    address := profile.Has("address") ? profile["address"] : Map()

    lastName := AdvisorNormalizeLooseToken(person.Has("lastName") ? person["lastName"] : "")
    firstName := AdvisorNormalizeLooseToken(person.Has("firstName") ? person["firstName"] : "")
    dob := Trim(String(person.Has("dob") ? person["dob"] : ""))

    streetRaw := address.Has("street") ? address["street"] : ""
    zip := Trim(String(address.Has("zip") ? address["zip"] : ""))
    streetNumber := AdvisorExtractStreetNumber(streetRaw)
    streetNorm := AdvisorNormalizeAddressForMatch(streetRaw)
    streetTokens := StrSplit(streetNorm, " ")
    primaryStreetToken := (streetTokens.Length >= 2) ? streetTokens[2] : ""

    if (lastName = "" || !RegExMatch(text, "(^|\s)" . lastName . "(\s|$)"))
        return -1

    if (zip = "" || !InStr(text, zip))
        return -1

    if (streetNumber = "" || !RegExMatch(text, "(^|\s)" . streetNumber . "(\s|$)"))
        return -1

    if (primaryStreetToken != "" && !InStr(text, primaryStreetToken))
        return -1

    score := 100

    if (firstName != "") {
        if RegExMatch(text, "(^|\s)" . firstName . "(\s|$)")
            score += 35
        else if InStr(text, firstName)
            score += 20
    }

    if (dob != "") {
        dobNorm := AdvisorNormalizeAddressForMatch(dob)
        if (dobNorm != "" && InStr(text, dobNorm))
            score += 5
    }

    return score
}

AdvisorPickUniqueSpouseOption(optionValues) {
    valid := []
    for _, option in optionValues {
        opt := Trim(String(option))
        if (opt = "" || opt = "NewDriver")
            continue
        valid.Push(opt)
    }
    return (valid.Length = 1) ? valid[1] : ""
}

AdvisorBuildResidenceProfile(address) {
    aptSuite := ""
    if IsObject(address) && address.Has("aptSuite")
        aptSuite := Trim(String(address["aptSuite"]))

    hasUnit := (aptSuite != "")
    classification := hasUnit ? "apartment/renter" : "single_family/owner-home"

    return Map(
        "hasUnit", hasUnit,
        "classification", classification,
        "participantPropertyOwnershipKey", hasUnit ? "RENT" : "OWN_HOME"
    )
}
