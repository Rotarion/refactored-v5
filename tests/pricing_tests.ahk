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

AssertEqual(ResolveQuotePrice(0), "$98", "Old car price should stay intact")
AssertEqual(ResolveQuotePrice(1, ["2020 Toyota Camry"], true), "$167", "Modern single-car batch price should use 2020+ tier")
AssertEqual(ResolveQuotePrice(1, ["2010 Toyota Camry"], true), "$117", "Older single-car batch price should use baseline tier")
AssertEqual(ResolveQuotePrice(2, ["2010 Toyota Camry", "2012 Honda Civic"], true), "$176", "Older two-car batch price should keep the baseline tier")
AssertEqual(ResolveQuotePrice(2, ["2017 Toyota Camry", "2012 Honda Civic"], true), "$206", "Two-car batch price should use the cutoff tier when a vehicle reaches the cutoff year")
AssertEqual(ResolveQuotePrice(2, ["2017 Toyota Camry", "2025 Honda Civic"], true), "$225", "Two-car batch price should use the 2025+ tier when any vehicle reaches that year")
AssertEqual(ResolveQuotePrice(3), "$284", "Three-car price should stay intact")

MsgBox("pricing_tests passed")

AssertEqual(actual, expected, message) {
    if (actual != expected)
        throw Error(message . "`nExpected: " expected "`nActual: " actual)
}
