TemplateRead(section, key, defaultValue := "") {
    value := TemplateReadRaw(section, key, &found)
    if found
        return DecodeTemplateValue(value)
    return DecodeTemplateValue(defaultValue)
}

EncodeTemplateValue(value) {
    text := value ?? ""
    text := StrReplace(text, "`r`n", "\n")
    text := StrReplace(text, "`r", "\n")
    text := StrReplace(text, "`n", "\n")
    return text
}

DecodeTemplateValue(value) {
    text := value ?? ""
    text := StrReplace(text, "\n", "`n")
    return text
}

TemplateReadRaw(section, key, &found := false) {
    global templatesFile

    found := false
    if !FileExist(templatesFile)
        return ""

    text := FileRead(templatesFile, "UTF-8")
    if (SubStr(text, 1, 1) = Chr(0xFEFF))
        text := SubStr(text, 2)

    currentSection := ""
    for _, rawLine in StrSplit(text, "`n", "`r") {
        line := Trim(rawLine, " `t")
        if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue

        if RegExMatch(line, "^\[(.*)\]$", &sectionMatch) {
            currentSection := sectionMatch[1]
            continue
        }

        if (currentSection != section)
            continue

        pos := InStr(rawLine, "=")
        if (pos <= 0)
            continue

        candidateKey := Trim(SubStr(rawLine, 1, pos - 1), " `t")
        if (candidateKey = key) {
            found := true
            return SubStr(rawLine, pos + 1)
        }
    }

    return ""
}

TemplateWrite(section, key, value) {
    global templatesFile

    encodedValue := EncodeTemplateValue(value)
    lines := []
    if FileExist(templatesFile)
        lines := StrSplit(FileRead(templatesFile, "UTF-8"), "`n", "`r")

    if (lines.Length > 0 && SubStr(lines[1], 1, 1) = Chr(0xFEFF))
        lines[1] := SubStr(lines[1], 2)

    currentSection := ""
    sectionFound := false
    insertAt := lines.Length + 1

    for i, rawLine in lines {
        line := Trim(rawLine, " `t")

        if RegExMatch(line, "^\[(.*)\]$", &sectionMatch) {
            if (sectionFound && currentSection != section) {
                insertAt := i
                break
            }

            currentSection := sectionMatch[1]
            if (currentSection = section) {
                sectionFound := true
                insertAt := i + 1
            }
            continue
        }

        if !sectionFound || currentSection != section
            continue

        pos := InStr(rawLine, "=")
        if (pos > 0) {
            candidateKey := Trim(SubStr(rawLine, 1, pos - 1), " `t")
            if (candidateKey = key) {
                lines[i] := key "=" encodedValue
                TemplateWriteAll(lines)
                return
            }
        }

        insertAt := i + 1
    }

    if sectionFound {
        lines.InsertAt(insertAt, key "=" encodedValue)
    } else {
        if (lines.Length > 0 && Trim(lines[lines.Length], " `t") != "")
            lines.Push("")
        lines.Push("[" section "]")
        lines.Push(key "=" encodedValue)
    }

    TemplateWriteAll(lines)
}

TemplateWriteAll(lines) {
    global templatesFile

    text := ""
    for _, line in lines
        text .= line "`n"

    try FileDelete(templatesFile)
    FileAppend(text, templatesFile, "UTF-8")
}

ExpandTemplate(text, tokens) {
    output := text
    for key, value in tokens
        output := StrReplace(output, "{" key "}", value)
    return output
}

GetDefaultQuoteBodyTemplate() {
    return JoinArray([
        "{GREETING} {FIRST_NAME},",
        "",
        "{QUOTE_BLOCK}",
        "",
        "{PRICE_LINE}",
        "",
        "{SAVINGS_LINE}",
        "",
        "{CALL_INVITE_LINE}",
        "",
        "{CLOSE_QUESTION_LINE}",
        "",
        "{PHONE_LINE}",
        "",
        "{AGENT_NAME}",
        "{SIGNATURE_TITLE}",
        "{DIRECT_LINE}",
        "{OFFICE_LINE}",
        "{AGENT_EMAIL}",
        "{UNSUBSCRIBE_LINE}"
    ], "`n")
}

BuildQuoteMessageTokens(leadName, carCount, vehicles := "", useBatchPricingRules := false) {
    global agentName, agentEmail

    greeting := (A_Hour < 12)
        ? TemplateRead("QuoteMessage", "GreetingMorning", "Buenos días")
        : TemplateRead("QuoteMessage", "GreetingAfternoon", "Buenas tardes")

    leadName := ProperCase(leadName)
    firstName := ExtractFirstName(leadName)

    vehLine := (carCount >= 2)
        ? TemplateRead("QuoteMessage", "VehicleLineMultiple", "Hicimos la cotización para el seguro de sus carros.")
        : TemplateRead("QuoteMessage", "VehicleLineSingle", "Hicimos la cotización para el seguro de su carro.")

    quoteLines := [vehLine]
    if (IsObject(vehicles) && vehicles.Length > 0) {
        for _, v in vehicles
            quoteLines.Push(v)
    }

    quoteBlock := JoinArray(quoteLines, "`n")
    coverageLine := (carCount = 5)
        ? TemplateRead("QuoteMessage", "CoverageLineFive", "Bodily Injury $100k per person $300k per occurrence\nProperty Damage $100k per occurrence")
        : ""
    if (coverageLine != "")
        quoteBlock .= "`n`n" . coverageLine

    price := ResolveQuotePrice(carCount, vehicles, useBatchPricingRules)
    coverageSuffix := TemplateRead("QuoteMessage", "CoverageSuffix", " al mes.")
    priceLine := ExpandTemplate(
        TemplateRead("QuoteMessage", "PriceLine", "Actualmente tenemos opciones con ALLSTATE desde {PRICE}{COVERAGE_SUFFIX}"),
        Map("PRICE", price, "COVERAGE_SUFFIX", coverageSuffix)
    )

    return Map(
        "GREETING", greeting,
        "FIRST_NAME", firstName,
        "QUOTE_BLOCK", quoteBlock,
        "PRICE", price,
        "COVERAGE_SUFFIX", coverageSuffix,
        "PRICE_LINE", priceLine,
        "SAVINGS_LINE", TemplateRead("QuoteMessage", "SavingsLine", "Muchos clientes en su misma situación han logrado ahorrar cambiándose con nosotros."),
        "CALL_INVITE_LINE", TemplateRead("QuoteMessage", "CallInviteLine", "Si quiere, en una llamada rápida de 2-3 minutos, podemos revisar si realmente le conviene o no."),
        "CLOSE_QUESTION_LINE", TemplateRead("QuoteMessage", "CloseQuestionLine", "¿Le parece bien si lo revisamos juntos?"),
        "PHONE_LINE", TemplateRead("QuoteMessage", "PhoneLine", "(555) 010-0100"),
        "AGENT_NAME", agentName,
        "SIGNATURE_TITLE", TemplateRead("QuoteMessage", "SignatureTitle", "Agente de Seguros - Allstate"),
        "DIRECT_LINE", TemplateRead("QuoteMessage", "DirectLine", "Direct Line: (555) 010-0100"),
        "OFFICE_LINE", TemplateRead("QuoteMessage", "OfficeLine", "Office Line: (555) 010-0101"),
        "AGENT_EMAIL", agentEmail,
        "UNSUBSCRIBE_LINE", TemplateRead("QuoteMessage", "UnsubscribeLine", "Reply STOP to unsubscribe")
    )
}

BuildMessage(leadName, carCount, vehicles := "", useBatchPricingRules := false) {
    bodyTemplate := TemplateRead("QuoteMessage", "BodyTemplate", "")
    if (Trim(bodyTemplate) = "")
        bodyTemplate := GetDefaultQuoteBodyTemplate()

    tokens := BuildQuoteMessageTokens(leadName, carCount, vehicles, useBatchPricingRules)
    return ExpandTemplate(bodyTemplate, tokens)
}

BuildFollowupQueue(leadName, offset) {
    global agentName, configDays, holidays

    leadName := ExtractFirstName(ProperCase(leadName))
    dq := Chr(34)

    dA := configDays[1]
    dB := configDays[2]
    dC := configDays[3]
    dD := configDays[4]

    dADate := BusinessDateForDay(dA, holidays)
    dBDate := BusinessDateForDay(dB, holidays)
    dCDate := BusinessDateForDay(dC, holidays)
    dDDate := BusinessDateForDay(dD, holidays)

    t1_1 := TimeWithOffset(9, 30, 30, offset)
    t1_2 := TimeWithOffset(9, 31, 10, offset)
    t1_3 := TimeWithOffset(9, 31, 30, offset)
    t1_4 := TimeWithOffset(10, 45, 0, offset)
    t2_1 := TimeWithOffset(16, 0, 10, offset)
    t2_2 := TimeWithOffset(16, 1, 10, offset)
    t4_1 := TimeWithOffset(16, 30, 0, offset)
    t4_2 := TimeWithOffset(16, 31, 0, offset)
    t5_1 := TimeWithOffset(12, 0, 0, offset)
    t5_2 := TimeWithOffset(12, 1, 0, offset)

    tokens := Map("FIRST_NAME", leadName, "AGENT_NAME", agentName)
    msgs := []

    msgs.Push(Map("day", dA, "seq", 1, "text", ExpandTemplate(TemplateRead("Followups", "A1", "Buenos días, {FIRST_NAME}."), tokens), "date", dADate, "time", t1_1))
    msgs.Push(Map("day", dA, "seq", 2, "text", ExpandTemplate(TemplateRead("Followups", "A2", "Soy {AGENT_NAME} de Allstate. Ya le preparé la cotización de su auto."), tokens), "date", dADate, "time", t1_2))
    msgs.Push(Map("day", dA, "seq", 3, "text", ExpandTemplate(TemplateRead("Followups", "A3", "En muchos casos logramos bajar el pago mensual sin quitar coberturas. Si gusta, se la resumo en 2 minutos por aquí."), tokens), "date", dADate, "time", t1_3))
    msgs.Push(Map("day", dA, "seq", 4, "text", ExpandTemplate(TemplateRead("Followups", "A4", "Si me responde " . dq . "Sí" . dq . ", se la envío ahora mismo."), tokens), "date", dADate, "time", t1_4))

    msgs.Push(Map("day", dB, "seq", 1, "text", ExpandTemplate(TemplateRead("Followups", "B1", "Hola, {FIRST_NAME}."), tokens), "date", dBDate, "time", t2_1))
    msgs.Push(Map("day", dB, "seq", 2, "text", ExpandTemplate(TemplateRead("Followups", "B2", "Hoy intenté comunicarme con usted porque todavía puedo revisar si califica para descuentos disponibles. Si me responde " . dq . "Revisar" . dq . ", yo me encargo de validar todo por usted."), tokens), "date", dBDate, "time", t2_2))

    msgs.Push(Map("day", dC, "seq", 1, "text", ExpandTemplate(TemplateRead("Followups", "C1", "Buenas tardes, {FIRST_NAME}."), tokens), "date", dCDate, "time", t4_1))
    msgs.Push(Map("day", dC, "seq", 2, "text", ExpandTemplate(TemplateRead("Followups", "C2", "Esta semana hemos ayudado a varios conductores a comparar su póliza actual con Allstate y, en muchos casos, encontraron una mejor opción. Si me responde " . dq . "Comparar" . dq . ", reviso su caso y le digo honestamente si le conviene o no. Reply STOP to unsubscribe."), tokens), "date", dCDate, "time", t4_2))

    msgs.Push(Map("day", dD, "seq", 1, "text", ExpandTemplate(TemplateRead("Followups", "D1", "{FIRST_NAME}, sigo teniendo su cotización disponible, pero normalmente cierro los pendientes cuando no recibo respuesta."), tokens), "date", dDDate, "time", t5_1))
    msgs.Push(Map("day", dD, "seq", 2, "text", ExpandTemplate(TemplateRead("Followups", "D2", "Si todavía quiere revisarla, respóndame " . dq . "Continuar" . dq . " y le envío el resumen por aquí."), tokens), "date", dDDate, "time", t5_2))

    return msgs
}
