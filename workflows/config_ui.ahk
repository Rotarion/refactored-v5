OpenConfigEditor(initialTab := 1) {
    cfg := ReadConfigSnapshot()

    editor := Gui("+Resize +MinSize980x760", "Automation Config")
    editor.SetFont("s10", "Segoe UI")
    editor.ctrls := Map()

    tabs := editor.Add("Tab3", "x10 y10 w960 h690", ["General", "Pricing", "Timings A", "Timings B", "Quote", "Followups", "Holidays"])
    editor.tabs := tabs

    tabs.UseTab(1)
    ConfigAddLabeledEdit(editor, "agentName", "Agent Name", cfg["agentName"], 30, 55, 280)
    ConfigAddLabeledEdit(editor, "agentEmail", "Agent Email", cfg["agentEmail"], 340, 55, 280)
    ConfigAddLabeledEdit(editor, "tagSymbol", "Tag Symbol", cfg["tagSymbol"], 650, 55, 100)
    ConfigAddLabeledEdit(editor, "scheduleDays", "Schedule Days (4 comma-separated)", cfg["scheduleDays"], 30, 125, 280)
    ConfigAddLabeledEdit(editor, "rotationOffset", "Rotation Offset (0-59)", cfg["rotationOffset"], 340, 125, 140)
    ConfigAddLabeledEdit(editor, "dobDefaultDay", "DOB Default Day", cfg["dobDefaultDay"], 500, 125, 140)
    ConfigAddLabeledEdit(editor, "batchMinVehicles", "Batch Min Vehicles", cfg["batchMinVehicles"], 30, 195, 140)
    ConfigAddLabeledEdit(editor, "batchMaxVehicles", "Batch Max Vehicles", cfg["batchMaxVehicles"], 190, 195, 140)
    ConfigAddLabeledEdit(editor, "batchTabsChatToName", "Tabs Chat To Name", cfg["batchTabsChatToName"], 350, 195, 140)
    editor.AddText("x30 y275 w860", "This tab edits the active runtime values in config/settings.ini.")

    tabs.UseTab(2)
    ConfigAddLabeledEdit(editor, "priceOldCar", "Old Car", cfg["priceOldCar"], 30, 55, 200)
    ConfigAddLabeledEdit(editor, "priceOneCar", "One Car", cfg["priceOneCar"], 260, 55, 200)
    ConfigAddLabeledEdit(editor, "priceOneCar2020Plus", "One Car 2020+", cfg["priceOneCar2020Plus"], 490, 55, 200)
    ConfigAddLabeledEdit(editor, "singleCarModernYearCutoff", "Single Car Modern Year Cutoff", cfg["singleCarModernYearCutoff"], 720, 55, 200)
    ConfigAddLabeledEdit(editor, "priceTwoCars", "Two Cars", cfg["priceTwoCars"], 30, 135, 200)
    ConfigAddLabeledEdit(editor, "priceTwoCarsCutoff", "Two Cars Cutoff Price", cfg["priceTwoCarsCutoff"], 260, 135, 200)
    ConfigAddLabeledEdit(editor, "twoCarsModernYearCutoff", "Two Cars Cutoff Year", cfg["twoCarsModernYearCutoff"], 490, 135, 200)
    ConfigAddLabeledEdit(editor, "priceTwoCars2025Plus", "Two Cars 2025+ Price", cfg["priceTwoCars2025Plus"], 720, 135, 200)
    ConfigAddLabeledEdit(editor, "twoCars2025PlusYearCutoff", "Two Cars 2025+ Year", cfg["twoCars2025PlusYearCutoff"], 30, 215, 200)
    ConfigAddLabeledEdit(editor, "priceThreeCars", "Three Cars", cfg["priceThreeCars"], 260, 215, 200)
    ConfigAddLabeledEdit(editor, "priceFourCars", "Four Cars", cfg["priceFourCars"], 490, 215, 200)
    ConfigAddLabeledEdit(editor, "priceFiveCars", "Five Cars", cfg["priceFiveCars"], 720, 215, 200)

    tabs.UseTab(3)
    ConfigAddLabeledEdit(editor, "slowActivateDelay", "Slow Activate Delay", cfg["slowActivateDelay"], 30, 55, 140)
    ConfigAddLabeledEdit(editor, "slowAfterMsg", "Slow After Message", cfg["slowAfterMsg"], 190, 55, 140)
    ConfigAddLabeledEdit(editor, "slowAfterSched", "Slow After Schedule", cfg["slowAfterSched"], 350, 55, 140)
    ConfigAddLabeledEdit(editor, "slowAfterDatePaste", "Slow After Date Paste", cfg["slowAfterDatePaste"], 510, 55, 140)
    ConfigAddLabeledEdit(editor, "slowAfterEnter", "Slow After Enter", cfg["slowAfterEnter"], 670, 55, 140)

    ConfigAddLabeledEdit(editor, "batchAfterAltN", "Batch After Alt+N", cfg["batchAfterAltN"], 30, 145, 140)
    ConfigAddLabeledEdit(editor, "batchAfterPhone", "Batch After Phone", cfg["batchAfterPhone"], 190, 145, 140)
    ConfigAddLabeledEdit(editor, "batchAfterTab", "Batch After Tab", cfg["batchAfterTab"], 350, 145, 140)
    ConfigAddLabeledEdit(editor, "batchAfterSchedule", "Batch After Schedule", cfg["batchAfterSchedule"], 510, 145, 140)
    ConfigAddLabeledEdit(editor, "batchAfterEnter", "Batch After Enter", cfg["batchAfterEnter"], 670, 145, 140)

    ConfigAddLabeledEdit(editor, "batchAfterNamePick", "Batch After Name Pick", cfg["batchAfterNamePick"], 30, 235, 140)
    ConfigAddLabeledEdit(editor, "batchAfterTagPick", "Batch After Tag Pick", cfg["batchAfterTagPick"], 190, 235, 140)
    ConfigAddLabeledEdit(editor, "batchBeforeTagPaste", "Batch Before Tag Paste", cfg["batchBeforeTagPaste"], 350, 235, 140)
    ConfigAddLabeledEdit(editor, "batchAfterTagPaste", "Batch After Tag Paste", cfg["batchAfterTagPaste"], 510, 235, 140)
    ConfigAddLabeledEdit(editor, "batchPostParticipantReadyStable", "Post Participant Ready Stable", cfg["batchPostParticipantReadyStable"], 670, 235, 180)

    ConfigAddLabeledEdit(editor, "batchPostParticipantReadyFast", "Post Participant Ready Fast", cfg["batchPostParticipantReadyFast"], 30, 325, 180)
    ConfigAddLabeledEdit(editor, "batchAfterParticipantToComposer", "After Participant To Composer", cfg["batchAfterParticipantToComposer"], 230, 325, 180)
    ConfigAddLabeledEdit(editor, "batchAfterTagComplete", "After Tag Complete", cfg["batchAfterTagComplete"], 430, 325, 180)

    tabs.UseTab(4)
    ConfigAddLabeledEdit(editor, "prospectTooltipDelay", "Prospect Tooltip Lead-In", cfg["prospectTooltipDelay"], 30, 55, 180)
    ConfigAddLabeledEdit(editor, "formFieldDelay", "Form Field Delay", cfg["formFieldDelay"], 230, 55, 140)
    ConfigAddLabeledEdit(editor, "formTabDelay", "Form Tab Delay", cfg["formTabDelay"], 390, 55, 140)
    ConfigAddLabeledEdit(editor, "formPasteDelay", "Form Paste Delay", cfg["formPasteDelay"], 550, 55, 140)
    ConfigAddLabeledEdit(editor, "formPasteTabDelay", "Form Paste Tab Delay", cfg["formPasteTabDelay"], 710, 55, 140)
    ConfigAddLabeledEdit(editor, "formCityTabDelay", "Form City Tab Delay", cfg["formCityTabDelay"], 30, 125, 180)

    ConfigAddLabeledEdit(editor, "crmActionFocusDelay", "CRM Action Focus Delay", cfg["crmActionFocusDelay"], 30, 215, 180)
    ConfigAddLabeledEdit(editor, "crmKeyStepDelay", "CRM Key Step Delay", cfg["crmKeyStepDelay"], 230, 215, 140)
    ConfigAddLabeledEdit(editor, "crmShortDelay", "CRM Short Delay", cfg["crmShortDelay"], 390, 215, 140)
    ConfigAddLabeledEdit(editor, "crmMediumDelay", "CRM Medium Delay", cfg["crmMediumDelay"], 550, 215, 140)
    ConfigAddLabeledEdit(editor, "crmQuoteShiftTabDelay", "CRM Quote Shift+Tab Delay", cfg["crmQuoteShiftTabDelay"], 710, 215, 180)
    ConfigAddLabeledEdit(editor, "crmSaveHistoryDelay", "CRM Save History Delay", cfg["crmSaveHistoryDelay"], 30, 285, 180)
    ConfigAddLabeledEdit(editor, "crmAddAppointmentDelay", "CRM Add Appointment Delay", cfg["crmAddAppointmentDelay"], 230, 285, 180)
    ConfigAddLabeledEdit(editor, "crmFocusDateDelay", "CRM Focus Date Delay", cfg["crmFocusDateDelay"], 430, 285, 180)
    ConfigAddLabeledEdit(editor, "crmFinalSaveDelay", "CRM Final Save Delay", cfg["crmFinalSaveDelay"], 630, 285, 180)

    tabs.UseTab(5)
    editor.AddText("x30 y45 w860", "Quote body placeholders: {GREETING}, {FIRST_NAME}, {QUOTE_BLOCK}, {PRICE_LINE}, {SAVINGS_LINE}, {CALL_INVITE_LINE}, {CLOSE_QUESTION_LINE}, {PHONE_LINE}, {AGENT_NAME}, {SIGNATURE_TITLE}, {DIRECT_LINE}, {OFFICE_LINE}, {AGENT_EMAIL}, {UNSUBSCRIBE_LINE}")
    ConfigAddLabeledEdit(editor, "quoteBodyTemplate", "Quote Body Template", cfg["quoteBodyTemplate"], 30, 75, 880, "r8")

    ConfigAddLabeledEdit(editor, "vehicleLineSingle", "Vehicle Line Single", cfg["vehicleLineSingle"], 30, 260, 400)
    ConfigAddLabeledEdit(editor, "vehicleLineMultiple", "Vehicle Line Multiple", cfg["vehicleLineMultiple"], 470, 260, 400)
    ConfigAddLabeledEdit(editor, "coverageSuffix", "Coverage Suffix", cfg["coverageSuffix"], 30, 330, 180)
    ConfigAddLabeledEdit(editor, "priceLine", "Price Line", cfg["priceLine"], 230, 330, 640)
    ConfigAddLabeledEdit(editor, "savingsLine", "Savings Line", cfg["savingsLine"], 30, 400, 400)
    ConfigAddLabeledEdit(editor, "callInviteLine", "Call Invite Line", cfg["callInviteLine"], 470, 400, 400)
    ConfigAddLabeledEdit(editor, "closeQuestionLine", "Close Question Line", cfg["closeQuestionLine"], 30, 470, 400)
    ConfigAddLabeledEdit(editor, "phoneLine", "Phone Line", cfg["phoneLine"], 470, 470, 400)
    ConfigAddLabeledEdit(editor, "signatureTitle", "Signature Title", cfg["signatureTitle"], 30, 540, 260)
    ConfigAddLabeledEdit(editor, "directLine", "Direct Line", cfg["directLine"], 310, 540, 260)
    ConfigAddLabeledEdit(editor, "officeLine", "Office Line", cfg["officeLine"], 590, 540, 280)
    ConfigAddLabeledEdit(editor, "unsubscribeLine", "Unsubscribe Line", cfg["unsubscribeLine"], 30, 610, 400)
    ConfigAddLabeledEdit(editor, "coverageLineFive", "Coverage Line For Five Cars", cfg["coverageLineFive"], 470, 610, 400, "r2")

    tabs.UseTab(6)
    ConfigAddLabeledEdit(editor, "followupA1", "A1", cfg["followupA1"], 30, 55, 420)
    ConfigAddLabeledEdit(editor, "followupA2", "A2", cfg["followupA2"], 470, 55, 420)
    ConfigAddLabeledEdit(editor, "followupA3", "A3", cfg["followupA3"], 30, 125, 420)
    ConfigAddLabeledEdit(editor, "followupA4", "A4", cfg["followupA4"], 470, 125, 420)
    ConfigAddLabeledEdit(editor, "followupB1", "B1", cfg["followupB1"], 30, 195, 420)
    ConfigAddLabeledEdit(editor, "followupB2", "B2", cfg["followupB2"], 470, 195, 420)
    ConfigAddLabeledEdit(editor, "followupC1", "C1", cfg["followupC1"], 30, 265, 420)
    ConfigAddLabeledEdit(editor, "followupC2", "C2", cfg["followupC2"], 470, 265, 420)
    ConfigAddLabeledEdit(editor, "followupD1", "D1", cfg["followupD1"], 30, 335, 420)
    ConfigAddLabeledEdit(editor, "followupD2", "D2", cfg["followupD2"], 470, 335, 420)
    ConfigAddLabeledEdit(editor, "crmAttemptedContact", "CRM Attempted Contact Note", cfg["crmAttemptedContact"], 30, 425, 220)
    ConfigAddLabeledEdit(editor, "crmQuoteCall", "CRM Quote Call Note", cfg["crmQuoteCall"], 270, 425, 220)

    tabs.UseTab(7)
    editor.AddText("x30 y45 w860", "Enter holidays one per line or comma-separated. They are saved to config/holidays_2026.ini.")
    ConfigAddLabeledEdit(editor, "holidaysDates", "Holiday Dates", cfg["holidaysDates"], 30, 75, 400, "r18")

    tabs.UseTab()

    btnSave := editor.Add("Button", "x650 y710 w100 Default", "Save")
    btnCancel := editor.Add("Button", "x770 y710 w100", "Cancel")

    editor.btnSave := btnSave
    editor.btnCancel := btnCancel

    btnSave.OnEvent("Click", (*) => SaveConfigEditor(editor))
    btnCancel.OnEvent("Click", (*) => editor.Destroy())
    editor.OnEvent("Size", ConfigEditor_OnSize)

    tabs.Choose(initialTab)
    editor.Show("w980 h760")
}

ConfigEditor_OnSize(editor, minMax, width, height) {
    if (minMax = -1)
        return

    try editor.tabs.Move(, , width - 20, height - 70)
    try editor.btnCancel.Move(width - 120, height - 40)
    try editor.btnSave.Move(width - 240, height - 40)
}

ConfigAddLabeledEdit(editor, key, label, value, x, y, width := 220, extraOptions := "") {
    editor.AddText("x" x " y" y " w" width, label)
    options := "x" x " y" (y + 18) " w" width
    if (extraOptions != "")
        options .= " " . extraOptions
    ctrl := editor.Add("Edit", options, value)
    editor.ctrls[key] := ctrl
    return ctrl
}

ReadConfigSnapshot() {
    global settingsFile, timingsFile, templatesFile, holidaysFile

    cfg := Map()
    dq := Chr(34)

    cfg["agentName"] := IniRead(settingsFile, "Agent", "Name", "Pablo Cabrera")
    cfg["agentEmail"] := IniRead(settingsFile, "Agent", "Email", "pablocabrera@allstate.com")
    cfg["tagSymbol"] := IniRead(settingsFile, "Agent", "TagSymbol", "+")
    cfg["scheduleDays"] := IniRead(settingsFile, "Schedule", "Days", "1,2,4,5")
    cfg["rotationOffset"] := IniRead(settingsFile, "Times", "Offset", "0")
    cfg["batchMinVehicles"] := IniRead(settingsFile, "Batch", "MinVehicles", "0")
    cfg["batchMaxVehicles"] := IniRead(settingsFile, "Batch", "MaxVehicles", "99")
    cfg["dobDefaultDay"] := IniRead(settingsFile, "DOB", "DefaultDay", "16")
    cfg["batchTabsChatToName"] := IniRead(settingsFile, "UI", "BatchTabsChatToName", "7")

    cfg["priceOldCar"] := IniRead(settingsFile, "Pricing", "OldCar", "98")
    cfg["priceOneCar"] := IniRead(settingsFile, "Pricing", "OneCar", "117")
    cfg["priceOneCar2020Plus"] := IniRead(settingsFile, "Pricing", "OneCar2020Plus", "167")
    cfg["priceTwoCars"] := IniRead(settingsFile, "Pricing", "TwoCars", "176")
    cfg["priceTwoCarsCutoff"] := IniRead(settingsFile, "Pricing", "TwoCarsCutoff", "206")
    cfg["priceTwoCars2025Plus"] := IniRead(settingsFile, "Pricing", "TwoCars2025Plus", "225")
    cfg["priceThreeCars"] := IniRead(settingsFile, "Pricing", "ThreeCars", "284")
    cfg["priceFourCars"] := IniRead(settingsFile, "Pricing", "FourCars", "397")
    cfg["priceFiveCars"] := IniRead(settingsFile, "Pricing", "FiveCars", "397")
    cfg["singleCarModernYearCutoff"] := IniRead(settingsFile, "Pricing", "SingleCarModernYearCutoff", "2020")
    cfg["twoCarsModernYearCutoff"] := IniRead(settingsFile, "Pricing", "TwoCarsModernYearCutoff", cfg["singleCarModernYearCutoff"])
    cfg["twoCars2025PlusYearCutoff"] := IniRead(settingsFile, "Pricing", "TwoCars2025PlusYearCutoff", "2025")

    cfg["slowActivateDelay"] := IniRead(timingsFile, "SlowMode", "ActivateDelay", "250")
    cfg["slowAfterMsg"] := IniRead(timingsFile, "SlowMode", "AfterMessage", "550")
    cfg["slowAfterSched"] := IniRead(timingsFile, "SlowMode", "AfterSchedule", "650")
    cfg["slowAfterDatePaste"] := IniRead(timingsFile, "SlowMode", "AfterDatePaste", "650")
    cfg["slowAfterEnter"] := IniRead(timingsFile, "SlowMode", "AfterEnter", "300")

    cfg["batchAfterAltN"] := IniRead(timingsFile, "Batch", "AfterAltN", "5000")
    cfg["batchAfterPhone"] := IniRead(timingsFile, "Batch", "AfterPhone", "650")
    cfg["batchAfterTab"] := IniRead(timingsFile, "Batch", "AfterTab", "150")
    cfg["batchAfterSchedule"] := IniRead(timingsFile, "Batch", "AfterSchedule", "600")
    cfg["batchAfterEnter"] := IniRead(timingsFile, "Batch", "AfterEnter", "150")
    cfg["batchAfterNamePick"] := IniRead(timingsFile, "Batch", "AfterNamePick", "250")
    cfg["batchAfterTagPick"] := IniRead(timingsFile, "Batch", "AfterTagPick", "250")
    cfg["batchBeforeTagPaste"] := IniRead(timingsFile, "Batch", "BeforeTagPaste", "500")
    cfg["batchAfterTagPaste"] := IniRead(timingsFile, "Batch", "AfterTagPaste", "700")
    cfg["batchPostParticipantReadyStable"] := IniRead(timingsFile, "Batch", "PostParticipantReadyStable", "150")
    cfg["batchPostParticipantReadyFast"] := IniRead(timingsFile, "Batch", "PostParticipantReadyFast", "0")
    cfg["batchAfterParticipantToComposer"] := IniRead(timingsFile, "Batch", "AfterParticipantToComposer", "1000")
    cfg["batchAfterTagComplete"] := IniRead(timingsFile, "Batch", "AfterTagComplete", "300")

    cfg["prospectTooltipDelay"] := IniRead(timingsFile, "ProspectFill", "TooltipLeadIn", "500")
    cfg["formFieldDelay"] := IniRead(timingsFile, "ProspectFill", "FieldDelay", "30")
    cfg["formTabDelay"] := IniRead(timingsFile, "ProspectFill", "TabDelay", "30")
    cfg["formPasteDelay"] := IniRead(timingsFile, "ProspectFill", "PasteDelay", "120")
    cfg["formPasteTabDelay"] := IniRead(timingsFile, "ProspectFill", "PasteTabDelay", "80")
    cfg["formCityTabDelay"] := IniRead(timingsFile, "ProspectFill", "CityTabDelay", "50")

    cfg["crmActionFocusDelay"] := IniRead(timingsFile, "CrmActivity", "ActionFocusDelay", "500")
    cfg["crmKeyStepDelay"] := IniRead(timingsFile, "CrmActivity", "KeyStepDelay", "150")
    cfg["crmShortDelay"] := IniRead(timingsFile, "CrmActivity", "ShortDelay", "200")
    cfg["crmMediumDelay"] := IniRead(timingsFile, "CrmActivity", "MediumDelay", "250")
    cfg["crmQuoteShiftTabDelay"] := IniRead(timingsFile, "CrmActivity", "QuoteShiftTabDelay", "3050")
    cfg["crmSaveHistoryDelay"] := IniRead(timingsFile, "CrmActivity", "SaveHistoryDelay", "800")
    cfg["crmAddAppointmentDelay"] := IniRead(timingsFile, "CrmActivity", "AddAppointmentDelay", "800")
    cfg["crmFocusDateDelay"] := IniRead(timingsFile, "CrmActivity", "FocusDateDelay", "300")
    cfg["crmFinalSaveDelay"] := IniRead(timingsFile, "CrmActivity", "FinalSaveDelay", "400")

    cfg["quoteBodyTemplate"] := TemplateRead("QuoteMessage", "BodyTemplate", GetDefaultQuoteBodyTemplate())
    cfg["vehicleLineSingle"] := TemplateRead("QuoteMessage", "VehicleLineSingle", "Hicimos la cotización para el seguro de su carro.")
    cfg["vehicleLineMultiple"] := TemplateRead("QuoteMessage", "VehicleLineMultiple", "Hicimos la cotización para el seguro de sus carros.")
    cfg["coverageLineFive"] := TemplateRead("QuoteMessage", "CoverageLineFive", "Bodily Injury $100k per person $300k per occurrence\nProperty Damage $100k per occurrence")
    cfg["coverageSuffix"] := TemplateRead("QuoteMessage", "CoverageSuffix", " al mes.")
    cfg["priceLine"] := TemplateRead("QuoteMessage", "PriceLine", "Actualmente tenemos opciones con ALLSTATE desde {PRICE}{COVERAGE_SUFFIX}")
    cfg["savingsLine"] := TemplateRead("QuoteMessage", "SavingsLine", "Muchos clientes en su misma situación han logrado ahorrar cambiándose con nosotros.")
    cfg["callInviteLine"] := TemplateRead("QuoteMessage", "CallInviteLine", "Si quiere, en una llamada rápida de 2-3 minutos, podemos revisar si realmente le conviene o no.")
    cfg["closeQuestionLine"] := TemplateRead("QuoteMessage", "CloseQuestionLine", "¿Le parece bien si lo revisamos juntos?")
    cfg["phoneLine"] := TemplateRead("QuoteMessage", "PhoneLine", "(561) 220-7073")
    cfg["signatureTitle"] := TemplateRead("QuoteMessage", "SignatureTitle", "Agente de Seguros - Allstate")
    cfg["directLine"] := TemplateRead("QuoteMessage", "DirectLine", "Direct Line: (561) 220-7073")
    cfg["officeLine"] := TemplateRead("QuoteMessage", "OfficeLine", "Office Line: (754) 236-8009")
    cfg["unsubscribeLine"] := TemplateRead("QuoteMessage", "UnsubscribeLine", "Reply STOP to unsubscribe")

    cfg["followupA1"] := TemplateRead("Followups", "A1", "Buenos días, {FIRST_NAME}.")
    cfg["followupA2"] := TemplateRead("Followups", "A2", "Soy {AGENT_NAME} de Allstate. Ya le preparé la cotización de su auto.")
    cfg["followupA3"] := TemplateRead("Followups", "A3", "En muchos casos logramos bajar el pago mensual sin quitar coberturas. Si gusta, se la resumo en 2 minutos por aquí.")
    cfg["followupA4"] := TemplateRead("Followups", "A4", "Si me responde " . dq . "Sí" . dq . ", se la envío ahora mismo.")
    cfg["followupB1"] := TemplateRead("Followups", "B1", "Hola, {FIRST_NAME}.")
    cfg["followupB2"] := TemplateRead("Followups", "B2", "Hoy intenté comunicarme con usted porque todavía puedo revisar si califica para descuentos disponibles. Si me responde " . dq . "Revisar" . dq . ", yo me encargo de validar todo por usted.")
    cfg["followupC1"] := TemplateRead("Followups", "C1", "Buenas tardes, {FIRST_NAME}.")
    cfg["followupC2"] := TemplateRead("Followups", "C2", "Esta semana hemos ayudado a varios conductores a comparar su póliza actual con Allstate y, en muchos casos, encontraron una mejor opción. Si me responde " . dq . "Comparar" . dq . ", reviso su caso y le digo honestamente si le conviene o no. Reply STOP to unsubscribe.")
    cfg["followupD1"] := TemplateRead("Followups", "D1", "{FIRST_NAME}, sigo teniendo su cotización disponible, pero normalmente cierro los pendientes cuando no recibo respuesta.")
    cfg["followupD2"] := TemplateRead("Followups", "D2", "Si todavía quiere revisarla, respóndame " . dq . "Continuar" . dq . " y le envío el resumen por aquí.")

    cfg["crmAttemptedContact"] := TemplateRead("CrmNotes", "AttemptedContact", "txt")
    cfg["crmQuoteCall"] := TemplateRead("CrmNotes", "QuoteCall", "qt")
    cfg["holidaysDates"] := ConfigNormalizeHolidayCsvForUi(IniRead(holidaysFile, "Holidays", "Dates", ""))

    return cfg
}

ConfigNormalizeHolidayCsvForUi(csv) {
    out := []
    for item in StrSplit(csv, ",") {
        clean := Trim(item)
        if (clean != "")
            out.Push(clean)
    }
    return JoinArray(out, "`n")
}

ConfigNormalizeHolidayInput(text) {
    work := text ?? ""
    work := StrReplace(work, "`r", "")
    work := RegExReplace(work, "[;\n]+", ",")
    out := []
    for item in StrSplit(work, ",") {
        clean := Trim(item)
        if (clean != "")
            out.Push(clean)
    }
    return JoinArray(out, ",")
}

ConfigReadValue(editor, key) {
    return editor.ctrls[key].Value
}

ConfigReadTrimmed(editor, key) {
    return Trim(ConfigReadValue(editor, key))
}

ConfigParseInt(value, label) {
    clean := Trim(value)
    if !(clean ~= "^-?\d+$")
        throw Error(label . " must be an integer.")
    return Integer(clean)
}

ConfigWriteTemplate(section, key, value) {
    TemplateWrite(section, key, value)
}

SaveConfigEditor(editor) {
    global settingsFile, timingsFile, holidaysFile

    try {
        agentName := ConfigReadTrimmed(editor, "agentName")
        agentEmail := ConfigReadTrimmed(editor, "agentEmail")
        tagSymbol := ConfigReadTrimmed(editor, "tagSymbol")
        scheduleDays := RegExReplace(ConfigReadTrimmed(editor, "scheduleDays"), "\s+", "")
        if (agentName = "" || StrLen(agentName) > 60)
            throw Error("Agent Name is required and must be 60 characters or fewer.")
        if (agentEmail = "" || StrLen(agentEmail) > 100 || !RegExMatch(agentEmail, "^[^@\s]+@[^@\s]+\.[^@\s]+$"))
            throw Error("Agent Email must be a valid email address.")
        if (tagSymbol = "" || StrLen(tagSymbol) > 3)
            throw Error("Tag Symbol is required and must be 3 characters or fewer.")
        if (ParseDays(scheduleDays).Length != 4)
            throw Error("Schedule Days must resolve to exactly 4 positive integers.")

        rotationOffset := ConfigParseInt(ConfigReadValue(editor, "rotationOffset"), "Rotation Offset")
        if (rotationOffset < 0 || rotationOffset > 59)
            throw Error("Rotation Offset must be between 0 and 59.")

        batchMinVehicles := ConfigParseInt(ConfigReadValue(editor, "batchMinVehicles"), "Batch Min Vehicles")
        batchMaxVehicles := ConfigParseInt(ConfigReadValue(editor, "batchMaxVehicles"), "Batch Max Vehicles")
        if (batchMinVehicles > batchMaxVehicles)
            throw Error("Batch Min Vehicles cannot be greater than Batch Max Vehicles.")

        twoCarsModernYearCutoff := ConfigParseInt(ConfigReadValue(editor, "twoCarsModernYearCutoff"), "Two Cars Cutoff Year")
        twoCars2025PlusYearCutoff := ConfigParseInt(ConfigReadValue(editor, "twoCars2025PlusYearCutoff"), "Two Cars 2025+ Year")
        if (twoCars2025PlusYearCutoff < twoCarsModernYearCutoff)
            throw Error("Two Cars 2025+ Year cannot be lower than the Two Cars Cutoff Year.")

        IniWrite(agentName, settingsFile, "Agent", "Name")
        IniWrite(agentEmail, settingsFile, "Agent", "Email")
        IniWrite(tagSymbol, settingsFile, "Agent", "TagSymbol")
        IniWrite(scheduleDays, settingsFile, "Schedule", "Days")
        IniWrite(rotationOffset, settingsFile, "Times", "Offset")
        IniWrite(batchMinVehicles, settingsFile, "Batch", "MinVehicles")
        IniWrite(batchMaxVehicles, settingsFile, "Batch", "MaxVehicles")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "dobDefaultDay"), "DOB Default Day"), settingsFile, "DOB", "DefaultDay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchTabsChatToName"), "Tabs Chat To Name"), settingsFile, "UI", "BatchTabsChatToName")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchTabsChatToName"), "Tabs Chat To Name"), settingsFile, "UI", "TabsChatToName")

        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceOldCar"), "Old Car Price"), settingsFile, "Pricing", "OldCar")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceOneCar"), "One Car Price"), settingsFile, "Pricing", "OneCar")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceOneCar2020Plus"), "One Car 2020+ Price"), settingsFile, "Pricing", "OneCar2020Plus")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceTwoCars"), "Two Cars Price"), settingsFile, "Pricing", "TwoCars")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceTwoCarsCutoff"), "Two Cars Cutoff Price"), settingsFile, "Pricing", "TwoCarsCutoff")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceTwoCars2025Plus"), "Two Cars 2025+ Price"), settingsFile, "Pricing", "TwoCars2025Plus")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceThreeCars"), "Three Cars Price"), settingsFile, "Pricing", "ThreeCars")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceFourCars"), "Four Cars Price"), settingsFile, "Pricing", "FourCars")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "priceFiveCars"), "Five Cars Price"), settingsFile, "Pricing", "FiveCars")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "singleCarModernYearCutoff"), "Single Car Modern Year Cutoff"), settingsFile, "Pricing", "SingleCarModernYearCutoff")
        IniWrite(twoCarsModernYearCutoff, settingsFile, "Pricing", "TwoCarsModernYearCutoff")
        IniWrite(twoCars2025PlusYearCutoff, settingsFile, "Pricing", "TwoCars2025PlusYearCutoff")

        IniWrite(ConfigParseInt(ConfigReadValue(editor, "slowActivateDelay"), "Slow Activate Delay"), timingsFile, "SlowMode", "ActivateDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "slowAfterMsg"), "Slow After Message"), timingsFile, "SlowMode", "AfterMessage")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "slowAfterSched"), "Slow After Schedule"), timingsFile, "SlowMode", "AfterSchedule")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "slowAfterDatePaste"), "Slow After Date Paste"), timingsFile, "SlowMode", "AfterDatePaste")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "slowAfterEnter"), "Slow After Enter"), timingsFile, "SlowMode", "AfterEnter")

        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterAltN"), "Batch After Alt+N"), timingsFile, "Batch", "AfterAltN")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterPhone"), "Batch After Phone"), timingsFile, "Batch", "AfterPhone")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterTab"), "Batch After Tab"), timingsFile, "Batch", "AfterTab")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterSchedule"), "Batch After Schedule"), timingsFile, "Batch", "AfterSchedule")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterEnter"), "Batch After Enter"), timingsFile, "Batch", "AfterEnter")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterNamePick"), "Batch After Name Pick"), timingsFile, "Batch", "AfterNamePick")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterTagPick"), "Batch After Tag Pick"), timingsFile, "Batch", "AfterTagPick")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchBeforeTagPaste"), "Batch Before Tag Paste"), timingsFile, "Batch", "BeforeTagPaste")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterTagPaste"), "Batch After Tag Paste"), timingsFile, "Batch", "AfterTagPaste")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchPostParticipantReadyStable"), "Post Participant Ready Stable"), timingsFile, "Batch", "PostParticipantReadyStable")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchPostParticipantReadyFast"), "Post Participant Ready Fast"), timingsFile, "Batch", "PostParticipantReadyFast")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterParticipantToComposer"), "After Participant To Composer"), timingsFile, "Batch", "AfterParticipantToComposer")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "batchAfterTagComplete"), "After Tag Complete"), timingsFile, "Batch", "AfterTagComplete")

        IniWrite(ConfigParseInt(ConfigReadValue(editor, "prospectTooltipDelay"), "Prospect Tooltip Lead-In"), timingsFile, "ProspectFill", "TooltipLeadIn")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "formFieldDelay"), "Form Field Delay"), timingsFile, "ProspectFill", "FieldDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "formTabDelay"), "Form Tab Delay"), timingsFile, "ProspectFill", "TabDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "formPasteDelay"), "Form Paste Delay"), timingsFile, "ProspectFill", "PasteDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "formPasteTabDelay"), "Form Paste Tab Delay"), timingsFile, "ProspectFill", "PasteTabDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "formCityTabDelay"), "Form City Tab Delay"), timingsFile, "ProspectFill", "CityTabDelay")

        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmActionFocusDelay"), "CRM Action Focus Delay"), timingsFile, "CrmActivity", "ActionFocusDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmKeyStepDelay"), "CRM Key Step Delay"), timingsFile, "CrmActivity", "KeyStepDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmShortDelay"), "CRM Short Delay"), timingsFile, "CrmActivity", "ShortDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmMediumDelay"), "CRM Medium Delay"), timingsFile, "CrmActivity", "MediumDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmQuoteShiftTabDelay"), "CRM Quote Shift+Tab Delay"), timingsFile, "CrmActivity", "QuoteShiftTabDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmSaveHistoryDelay"), "CRM Save History Delay"), timingsFile, "CrmActivity", "SaveHistoryDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmAddAppointmentDelay"), "CRM Add Appointment Delay"), timingsFile, "CrmActivity", "AddAppointmentDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmFocusDateDelay"), "CRM Focus Date Delay"), timingsFile, "CrmActivity", "FocusDateDelay")
        IniWrite(ConfigParseInt(ConfigReadValue(editor, "crmFinalSaveDelay"), "CRM Final Save Delay"), timingsFile, "CrmActivity", "FinalSaveDelay")

        ConfigWriteTemplate("QuoteMessage", "BodyTemplate", ConfigReadValue(editor, "quoteBodyTemplate"))
        ConfigWriteTemplate("QuoteMessage", "VehicleLineSingle", ConfigReadValue(editor, "vehicleLineSingle"))
        ConfigWriteTemplate("QuoteMessage", "VehicleLineMultiple", ConfigReadValue(editor, "vehicleLineMultiple"))
        ConfigWriteTemplate("QuoteMessage", "CoverageLineFive", ConfigReadValue(editor, "coverageLineFive"))
        ConfigWriteTemplate("QuoteMessage", "CoverageSuffix", ConfigReadValue(editor, "coverageSuffix"))
        ConfigWriteTemplate("QuoteMessage", "PriceLine", ConfigReadValue(editor, "priceLine"))
        ConfigWriteTemplate("QuoteMessage", "SavingsLine", ConfigReadValue(editor, "savingsLine"))
        ConfigWriteTemplate("QuoteMessage", "CallInviteLine", ConfigReadValue(editor, "callInviteLine"))
        ConfigWriteTemplate("QuoteMessage", "CloseQuestionLine", ConfigReadValue(editor, "closeQuestionLine"))
        ConfigWriteTemplate("QuoteMessage", "PhoneLine", ConfigReadValue(editor, "phoneLine"))
        ConfigWriteTemplate("QuoteMessage", "SignatureTitle", ConfigReadValue(editor, "signatureTitle"))
        ConfigWriteTemplate("QuoteMessage", "DirectLine", ConfigReadValue(editor, "directLine"))
        ConfigWriteTemplate("QuoteMessage", "OfficeLine", ConfigReadValue(editor, "officeLine"))
        ConfigWriteTemplate("QuoteMessage", "UnsubscribeLine", ConfigReadValue(editor, "unsubscribeLine"))

        ConfigWriteTemplate("Followups", "A1", ConfigReadValue(editor, "followupA1"))
        ConfigWriteTemplate("Followups", "A2", ConfigReadValue(editor, "followupA2"))
        ConfigWriteTemplate("Followups", "A3", ConfigReadValue(editor, "followupA3"))
        ConfigWriteTemplate("Followups", "A4", ConfigReadValue(editor, "followupA4"))
        ConfigWriteTemplate("Followups", "B1", ConfigReadValue(editor, "followupB1"))
        ConfigWriteTemplate("Followups", "B2", ConfigReadValue(editor, "followupB2"))
        ConfigWriteTemplate("Followups", "C1", ConfigReadValue(editor, "followupC1"))
        ConfigWriteTemplate("Followups", "C2", ConfigReadValue(editor, "followupC2"))
        ConfigWriteTemplate("Followups", "D1", ConfigReadValue(editor, "followupD1"))
        ConfigWriteTemplate("Followups", "D2", ConfigReadValue(editor, "followupD2"))
        ConfigWriteTemplate("CrmNotes", "AttemptedContact", ConfigReadValue(editor, "crmAttemptedContact"))
        ConfigWriteTemplate("CrmNotes", "QuoteCall", ConfigReadValue(editor, "crmQuoteCall"))

        holidaysCsv := ConfigNormalizeHolidayInput(ConfigReadValue(editor, "holidaysDates"))
        if (holidaysCsv = "")
            throw Error("At least one holiday date is required.")
        IniWrite(holidaysCsv, holidaysFile, "Holidays", "Dates")

        InitializeApplication()
        PersistRunState("config-ui-save")
        TrayTip("AHK", "Configuration saved.", 1)
        editor.Destroy()
    } catch Error as err {
        MsgBox(err.Message, "Config Save Failed")
    }
}

