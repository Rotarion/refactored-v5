#Requires AutoHotkey v2.0

global dobDefaultDay := 16
global batchMinVehicles := 0
global batchMaxVehicles := 99
global tagSymbol := "+"

#Include ..\domain\lead_normalizer.ahk
#Include ..\domain\lead_parser.ahk
#Include ..\domain\batch_rules.ahk

labeledRaw := "Name:`n"
    . "Maria Gomez`n"
    . "Date of Birth:`n"
    . "Jan 1985`n"
    . "Gender:`n"
    . "Female`n"
    . "Address Line 1:`n"
    . "123 Main St Apt 4B`n"
    . "City:`n"
    . "Miami`n"
    . "State:`n"
    . "FL`n"
    . "Zip Code:`n"
    . "33101`n"
    . "Phone:`n"
    . "(305) 555-1212`n"
    . "Email:`n"
    . "maria@example.com"

fields := ParseLabeledLeadToProspect(labeledRaw)
AssertEqual(fields["FIRST_NAME"], "Maria", "First name should come from labeled lead")
AssertEqual(fields["LAST_NAME"], "Gomez", "Last name should come from labeled lead")
AssertEqual(fields["DOB"], "01/16/1985", "Month-only DOB should use default day")
AssertEqual(fields["PHONE"], "3055551212", "Phone should normalize to digits")
AssertEqual(fields["APT_SUITE"], "4B", "Apartment should split out of address")

batchRaw := "PERSONAL LEAD - JOHN SMITH 12/01/2026 10:00:00 AM 123 Main St Miami FL 33101 (561) 555-1212 john@example.com Jan 1980 Male 2020 Toyota Camry"
lead := BuildBatchLeadRecord(batchRaw)
AssertEqual(lead["FULL_NAME"], "John Smith", "Batch lead name should be normalized")
AssertEqual(lead["PHONE"], "5615551212", "Batch phone should be parsed")
AssertEqual(lead["VEHICLE_COUNT"], 1, "Vehicle count should detect one car")
AssertEqual(lead["VEHICLES"][1], "2020 Toyota Camry", "Year-first vehicle should stay normalized")

yearAtEndRow := "PERSONAL LEAD-Emilio Hernandez`tNEW webform folder - Personal`t1 - New`t4/22/2026 2:23:45 PM`t15152 Sunset Dr`tMiami`tFlorida`t33193`t(561) 685-5935`tnoemail@gmail.com`tJanuary 1970`tMale`tToyota Tundra 2007`t`t`t`t`tMove to Recycle Bin"
yearAtEndLead := BuildBatchLeadRecord(yearAtEndRow)
AssertEqual(yearAtEndLead["FULL_NAME"], "Emilio Hernandez", "Tab row name should be normalized")
AssertEqual(yearAtEndLead["VEHICLE_COUNT"], 1, "Year-end vehicle should still count as one car")
AssertEqual(yearAtEndLead["VEHICLES"][1], "2007 Toyota Tundra", "Year-end vehicle should normalize to year-first")

multiVehicleTabRow := "PERSONAL LEAD - Maria Valdes`tNEW webform folder - Personal`t1 - New`t4/22/2026 5:18:35 PM`t550 NW 114th Ave #101`tMiami`tFlorida`t33172`t(786) 260-2935`tnoemail@gmail.com`tMarch 1966`tFemale`t2022 Chevrolet Blazer`tMercedes-Benz / GL 450`t`t`t`tMove to Recycle Bin"
multiVehicleLead := BuildBatchLeadRecord(multiVehicleTabRow)
AssertEqual(multiVehicleLead["VEHICLE_COUNT"], 2, "Post-gender vehicle columns should all count")

multiBatch := "PERSONAL LEAD - JOHN SMITH`n"
    . "PERSONAL LEAD - JANE DOE"

rows := ParseBatchLeadRows(multiBatch)
AssertEqual(rows.Length, 2, "Batch rows should split on PERSONAL LEAD markers")

MsgBox("parser_fixtures passed")

AssertEqual(actual, expected, message) {
    if (actual != expected)
        throw Error(message . "`nExpected: " expected "`nActual: " actual)
}
