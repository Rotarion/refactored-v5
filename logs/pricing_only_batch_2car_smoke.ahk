#Requires AutoHotkey v2.0

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

#Include ..\domain\pricing_rules.ahk

AssertEqual(ResolveQuotePrice(2, ["2010 Toyota Camry", "2012 Honda Civic"], true), "$176", "Older two-car batch pricing should stay baseline")
AssertEqual(ResolveQuotePrice(2, ["2017 Toyota Camry", "2012 Honda Civic"], true), "$206", "Two-car cutoff pricing should apply at the configured cutoff year")
AssertEqual(ResolveQuotePrice(2, ["2017 Toyota Camry", "2025 Honda Civic"], true), "$225", "Two-car 2025+ pricing should apply when any vehicle reaches the high tier")
AssertEqual(ResolveQuotePrice(2, ["2017 Toyota Camry", "2025 Honda Civic"], false), "$176", "Non-batch two-car pricing should remain unchanged")
ExitApp(0)

AssertEqual(actual, expected, message) {
    if (actual != expected)
        throw Error(message . "`nExpected: " expected "`nActual: " actual)
}
