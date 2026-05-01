#Requires AutoHotkey v2.0

global dobDefaultDay := 16
global batchMinVehicles := 0
global batchMaxVehicles := 99
global tagSymbol := "+"

#Include ..\domain\lead_normalizer.ahk
#Include ..\domain\lead_parser.ahk
#Include ..\domain\batch_rules.ahk

labeledRaw := "Name:`n"
    . "Test Lead One`n"
    . "Date of Birth:`n"
    . "Jan 1985`n"
    . "Gender:`n"
    . "Female`n"
    . "Address Line 1:`n"
    . "123 Example St Apt 4B`n"
    . "City:`n"
    . "Example City`n"
    . "State:`n"
    . "FL`n"
    . "Zip Code:`n"
    . "32001`n"
    . "Phone:`n"
    . "(555) 010-0001`n"
    . "Email:`n"
    . "test.lead.one@example.com"

fields := ParseLabeledLeadToProspect(labeledRaw)
AssertEqual(fields["FIRST_NAME"], "Test", "First name should come from labeled lead")
AssertEqual(fields["LAST_NAME"], "Lead One", "Last name should come from labeled lead")
AssertEqual(fields["DOB"], "01/16/1985", "Month-only DOB should use default day")
AssertEqual(fields["PHONE"], "5550100001", "Phone should normalize to digits")
AssertEqual(fields["APT_SUITE"], "4B", "Apartment should split out of address")

batchRaw := "PERSONAL LEAD - TEST LEAD TWO 12/01/2026 10:00:00 AM 456 Sample Ave Sample City FL 32002 (555) 010-0002 test.lead.two@example.com Feb 1990 Male 2020 Toyota Camry"
lead := BuildBatchLeadRecord(batchRaw)
AssertEqual(lead["FULL_NAME"], "Test Lead Two", "Batch lead name should be normalized")
AssertEqual(lead["PHONE"], "5550100002", "Batch phone should be parsed")
AssertEqual(lead["VEHICLE_COUNT"], 1, "Vehicle count should detect one car")
AssertEqual(lead["VEHICLES"][1], "2020 Toyota Camry", "Year-first vehicle should stay normalized")

yearAtEndRow := "PERSONAL LEAD-Test Vehicle Lead`tNEW webform folder - Personal`t1 - New`t4/22/2026 2:23:45 PM`t456 Sample Ave`tSample City`tFlorida`t32002`t(555) 010-0003`ttest.vehicle.lead@example.com`tFeb 1990`tMale`tToyota Tundra 2007`t`t`t`t`tMove to Recycle Bin"
yearAtEndLead := BuildBatchLeadRecord(yearAtEndRow)
AssertEqual(yearAtEndLead["FULL_NAME"], "Test Vehicle Lead", "Tab row name should be normalized")
AssertEqual(yearAtEndLead["VEHICLE_COUNT"], 1, "Year-end vehicle should still count as one car")
AssertEqual(yearAtEndLead["VEHICLES"][1], "2007 Toyota Tundra", "Year-end vehicle should normalize to year-first")

multiVehicleTabRow := "PERSONAL LEAD - Test Multi Vehicle Lead`tNEW webform folder - Personal`t1 - New`t4/22/2026 5:18:35 PM`t789 Demo Blvd #101`tDemo City`tFlorida`t32003`t(555) 010-0004`ttest.multi.vehicle@example.com`tMar 1979`tFemale`t2022 Chevrolet Blazer`tMercedes-Benz / GL 450`t`t`t`tMove to Recycle Bin"
multiVehicleLead := BuildBatchLeadRecord(multiVehicleTabRow)
AssertEqual(multiVehicleLead["VEHICLE_COUNT"], 2, "Post-gender vehicle columns should all count")

multiBatch := "PERSONAL LEAD - TEST LEAD ALPHA`n"
    . "PERSONAL LEAD - TEST LEAD BETA"

rows := ParseBatchLeadRows(multiBatch)
AssertEqual(rows.Length, 2, "Batch rows should split on PERSONAL LEAD markers")

MsgBox("parser_fixtures passed")

AssertEqual(actual, expected, message) {
    if (actual != expected)
        throw Error(message . "`nExpected: " expected "`nActual: " actual)
}
