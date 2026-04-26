#Requires AutoHotkey v2.0

global templatesFile := A_ScriptDir "\..\config\templates.ini"
global agentName := "Pablo Cabrera"
global agentEmail := "pablocabrera@allstate.com"
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
#Include ..\domain\message_templates.ahk

message := BuildMessage("juan perez", 2, ["2017 Toyota Camry", "2025 Honda Civic"], true)
AssertTrue(InStr(message, "$225"), "Batch quote message should reflect the 2025+ two-car tier")
ExitApp(0)

AssertTrue(condition, message) {
    if !condition
        throw Error(message)
}
