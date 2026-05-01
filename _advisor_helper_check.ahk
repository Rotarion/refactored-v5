#Requires AutoHotkey v2.0
#SingleInstance Off

global dobDefaultDay := 16
global tagSymbol := "+"

#Include domain\lead_normalizer.ahk
#Include domain\advisor_quote_db.ahk
#Include domain\lead_parser.ahk
#Include domain\batch_rules.ahk

AssertEqual(actual, expected, message) {
    if (actual != expected) {
        FileAppend(message . "`nExpected: " . expected . "`nActual: " . actual . "`n", "*")
        ExitApp(1)
    }
}

sample := "PERSONAL LEAD - Test Lead One 04/22/2026 10:00:00 AM 123 Example St Example City FL 32001 (555) 010-0001 test.lead.one@example.com Jan 1985 Female 2021 Nissan Sentra SV"
profile := BuildAdvisorQuoteLeadProfile(sample)
AssertEqual(profile["person"]["firstName"], "Test", "Profile should parse first name")
AssertEqual(profile["person"]["lastName"], "Lead One", "Profile should parse last name")
AssertEqual(profile["address"]["zip"], "32001", "Profile should parse ZIP")
AssertEqual(profile["vehicles"].Length, 1, "Profile should parse one normalized vehicle")
AssertEqual(profile["vehicles"][1]["year"], "2021", "Vehicle year should normalize")
AssertEqual(profile["vehicles"][1]["make"], "NISSAN", "Vehicle make should normalize")
AssertEqual(profile["vehicles"][1]["model"], "SENTRA", "Vehicle model should normalize")

joseSample :=
(
"Name:
PERSONAL LEAD - Test Lead Two
Address Line 1:
456 Sample Ave
City:
Sample City
State:
Florida
Zip Code:
32002
Phone:
(555) 010-0002
Email Address:
test.lead.two@example.com
First Name::
Test Lead
Last Name::
Two
Date of Birth::
Feb 1990
Gender:
Male
1 Year / Make / Model:
2017 Chevrolet Silverado 1500"
)

joseProfile := BuildAdvisorQuoteLeadProfile(joseSample)
AssertEqual(joseProfile["person"]["firstName"], "Test Lead", "Labeled lead should preserve multi-token first name")
AssertEqual(joseProfile["person"]["lastName"], "Two", "Labeled lead should preserve last name")
AssertEqual(joseProfile["address"]["city"], "Sample City", "Labeled lead should parse city")
AssertEqual(joseProfile["vehicles"].Length, 1, "Labeled lead should parse numbered vehicle fields")
AssertEqual(joseProfile["vehicles"][1]["year"], "2017", "Labeled vehicle year should normalize")
AssertEqual(joseProfile["vehicles"][1]["make"], "CHEVROLET", "Labeled vehicle make should normalize")
AssertEqual(joseProfile["vehicles"][1]["model"], "SILVERADO", "Labeled vehicle model should normalize")
AssertEqual(joseProfile["residence"]["classification"], "single_family/owner-home", "No-unit address should classify as single-family")

apartmentSample :=
(
"Name:
PERSONAL LEAD - Test Apartment Lead
Address Line 1:
789 Demo Blvd #104
City:
Demo City
State:
Florida
Zip Code:
32003
Phone:
(555) 010-0003
Email Address:
test.apartment.lead@example.com
Date of Birth::
Mar 1979
Gender:
Female"
)

apartmentProfile := BuildAdvisorQuoteLeadProfile(apartmentSample)
AssertEqual(apartmentProfile["address"]["aptSuite"], "104", "Apartment/unit should split into APT_SUITE")
AssertEqual(apartmentProfile["residence"]["classification"], "apartment/renter", "Apartment address should classify as renter")
AssertEqual(apartmentProfile["residence"]["participantPropertyOwnershipKey"], "RENT", "Apartment residence should produce rent ownership")

FileAppend("advisor helper checks passed`n", "*")
ExitApp(0)
