ResolveQuotePrice(carCount, vehicles := "", useBatchPricingRules := false) {
    global priceOldCar, priceOneCar, priceOneCar2020Plus
    global priceTwoCars, priceTwoCarsCutoff, priceTwoCars2025Plus
    global priceThreeCars, priceFourCars, priceFiveCars
    global singleCarModernYearCutoff, twoCarsModernYearCutoff, twoCars2025PlusYearCutoff

    if (useBatchPricingRules) {
        vehicleYear := ExtractVehicleYearFromList(vehicles)

        if (carCount = 1) {
            if (vehicleYear >= singleCarModernYearCutoff)
                return FormatMonthlyPrice(priceOneCar2020Plus)
            return FormatMonthlyPrice(priceOneCar)
        }

        if (carCount = 2) {
            if (vehicleYear >= twoCars2025PlusYearCutoff)
                return FormatMonthlyPrice(priceTwoCars2025Plus)
            if (vehicleYear >= twoCarsModernYearCutoff)
                return FormatMonthlyPrice(priceTwoCarsCutoff)
        }
    }

    prices := Map(0, priceOldCar, 1, priceOneCar, 2, priceTwoCars, 3, priceThreeCars, 4, priceFourCars, 5, priceFiveCars)
    return prices.Has(carCount) ? FormatMonthlyPrice(prices[carCount]) : "$127"
}

ExtractVehicleYearFromList(vehicles) {
    newestYear := 0
    if !(IsObject(vehicles) && vehicles.Length >= 1)
        return newestYear

    for _, vehicle in vehicles {
        vehicleYear := ExtractVehicleYear(vehicle)
        if (vehicleYear > newestYear)
            newestYear := vehicleYear
    }
    return newestYear
}

ExtractVehicleYear(vehicleText) {
    if RegExMatch(vehicleText, "i)\b((19|20)\d{2})\b", &m)
        return Integer(m[1])
    return 0
}

FormatMonthlyPrice(amount) {
    return "$" . Integer(amount)
}
