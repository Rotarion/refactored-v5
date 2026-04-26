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

sample := "PERSONAL LEAD - Maria Lopez 04/22/2026 10:00:00 AM 123 Main St Miami FL 33101 (305) 555-1212 maria@example.com Jan 1985 Female 2021 Nissan Sentra SV"
profile := BuildAdvisorQuoteLeadProfile(sample)
AssertEqual(profile["person"]["firstName"], "Maria", "Profile should parse first name")
AssertEqual(profile["person"]["lastName"], "Lopez", "Profile should parse last name")
AssertEqual(profile["address"]["zip"], "33101", "Profile should parse ZIP")
AssertEqual(profile["vehicles"].Length, 1, "Profile should parse one normalized vehicle")
AssertEqual(profile["vehicles"][1]["year"], "2021", "Vehicle year should normalize")
AssertEqual(profile["vehicles"][1]["make"], "NISSAN", "Vehicle make should normalize")
AssertEqual(profile["vehicles"][1]["model"], "SENTRA", "Vehicle model should normalize")

joseSample :=
(
"Name:
PERSONAL LEAD - Jose C Lozano Sanchez
Address Line 1:
4911 SW 31st Ter
City:
Fort Lauderdale
State:
Florida
Zip Code:
33312
Phone:
(954) 294-7763
Email Address:
texto@gmail.com
First Name::
Jose C
Last Name::
Lozano Sanchez
Date of Birth::
November 1966
Gender:
Male
1 Year / Make / Model:
2017 Chevrolet Silverado 1500"
)

joseProfile := BuildAdvisorQuoteLeadProfile(joseSample)
AssertEqual(joseProfile["person"]["firstName"], "Jose C", "Labeled lead should preserve multi-token first name")
AssertEqual(joseProfile["person"]["lastName"], "Lozano Sanchez", "Labeled lead should preserve multi-token last name")
AssertEqual(joseProfile["address"]["city"], "Fort Lauderdale", "Labeled lead should parse city")
AssertEqual(joseProfile["vehicles"].Length, 1, "Labeled lead should parse numbered vehicle fields")
AssertEqual(joseProfile["vehicles"][1]["year"], "2017", "Labeled vehicle year should normalize")
AssertEqual(joseProfile["vehicles"][1]["make"], "CHEVROLET", "Labeled vehicle make should normalize")
AssertEqual(joseProfile["vehicles"][1]["model"], "SILVERADO", "Labeled vehicle model should normalize")
AssertEqual(joseProfile["residence"]["classification"], "single_family/owner-home", "No-unit address should classify as single-family")

apartmentSample :=
(
"Name:
PERSONAL LEAD - Maria Perez
Address Line 1:
6024 SW 26th St #104
City:
Miramar
State:
Florida
Zip Code:
33023
Phone:
(561) 674-8015
Date of Birth::
April 1973
Gender:
Female"
)

apartmentProfile := BuildAdvisorQuoteLeadProfile(apartmentSample)
AssertEqual(apartmentProfile["address"]["aptSuite"], "104", "Apartment/unit should split into APT_SUITE")
AssertEqual(apartmentProfile["residence"]["classification"], "apartment/renter", "Apartment address should classify as renter")
AssertEqual(apartmentProfile["residence"]["participantPropertyOwnershipKey"], "RENT", "Apartment residence should produce rent ownership")

FileAppend("advisor helper checks passed`n", "*")
ExitApp(0)
