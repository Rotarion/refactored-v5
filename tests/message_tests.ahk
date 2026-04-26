#Requires AutoHotkey v2.0

global templatesFile := A_ScriptDir "\..\config\templates.ini"
global agentName := "Pablo Cabrera"
global agentEmail := "pablocabrera@allstate.com"
global configDays := [2, 4, 7, 9]
global holidays := ["05/25/2026"]
global priceOldCar := 98
global priceOneCar := 117
global priceOneCar2020Plus := 167
global priceTwoCars := 176
global priceTwoCarsCutoff := 206
global priceTwoCars2025Plus := 225
global priceThreeCars := 284
global priceFourCars := 397
global priceFiveCars := 397
global singleCarModernYearCutoff := 2017
global twoCarsModernYearCutoff := 2017
global twoCars2025PlusYearCutoff := 2025

#Include ..\domain\lead_normalizer.ahk
#Include ..\domain\pricing_rules.ahk
#Include ..\domain\date_rules.ahk
#Include ..\domain\message_templates.ahk

message := BuildMessage("juan perez", 1, ["2020 Toyota Camry"], true)
tokens := BuildQuoteMessageTokens("juan perez", 1, ["2020 Toyota Camry"], true)
expected := ExpandTemplate(TemplateRead("QuoteMessage", "BodyTemplate", GetDefaultQuoteBodyTemplate()), tokens)
twoCarFutureMessage := BuildMessage("juan perez", 2, ["2017 Toyota Camry", "2025 Honda Civic"], true)

AssertEqual(message, expected, "Quote message should respect the configured body template and token correlation")
AssertTrue(InStr(message, "Juan"), "Message should proper-case the lead name")
AssertTrue(InStr(message, "$167"), "Message should include the 2020+ single-car price")
AssertTrue(InStr(message, "Hicimos la cotización para el seguro de su carro.`n2020 Toyota Camry"), "Quote block should keep the vehicle list correlated under the lead quote line")
AssertTrue(InStr(message, agentName), "Message should include the configured agent name")
AssertTrue(InStr(message, agentEmail), "Message should include the configured agent email")
AssertTrue(InStr(GetDefaultQuoteBodyTemplate(), "{QUOTE_BLOCK}"), "Default quote template should preserve the quote block placeholder")
AssertTrue(InStr(twoCarFutureMessage, "$225"), "Batch message pricing should stay correlated for 2025+ two-car leads")

queue := BuildFollowupQueue("juan perez", 0)
AssertEqual(queue.Length, 10, "Follow-up queue should still create ten scheduled messages")
AssertEqual(queue[1]["day"], 2, "First follow-up block should use configured day A")
AssertEqual(queue[10]["day"], 9, "Last follow-up block should use configured day D")

MsgBox("message_tests passed")

AssertEqual(actual, expected, message) {
    if (actual != expected)
        throw Error(message . "`nExpected: " expected "`nActual: " actual)
}

AssertTrue(condition, message) {
    if !condition
        throw Error(message)
}
