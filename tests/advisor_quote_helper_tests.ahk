#Requires AutoHotkey v2.0

global dobDefaultDay := 16
global tagSymbol := "+"

#Include ..\domain\lead_normalizer.ahk
#Include ..\domain\advisor_quote_db.ahk
#Include ..\domain\advisor_vehicle_catalog.ahk
#Include ..\domain\lead_parser.ahk
#Include ..\domain\batch_rules.ahk
#Include ..\workflows\advisor_quote_workflow.ahk

sample := "PERSONAL LEAD - Test Lead One 04/22/2026 10:00:00 AM 123 Example St Example City FL 32001 (555) 010-0001 test.lead.one@example.com Jan 1985 Female 2021 Nissan Sentra SV"
profile := BuildAdvisorQuoteLeadProfile(sample)

AssertEqual(profile["person"]["firstName"], "Test", "Profile should parse first name")
AssertEqual(profile["person"]["lastName"], "Lead One", "Profile should parse last name")
AssertEqual(profile["address"]["zip"], "32001", "Profile should parse ZIP")
AssertEqual(profile["vehicles"].Length, 1, "Profile should parse one normalized vehicle")
AssertEqual(profile["vehicles"][1]["year"], "2021", "Vehicle year should normalize")
AssertEqual(profile["vehicles"][1]["make"], "NISSAN", "Vehicle make should normalize")
AssertEqual(profile["vehicles"][1]["model"], "SENTRA", "Vehicle model should normalize")
AssertEqual(profile["vehicles"][1]["displayKey"], "2021|NISSAN|SENTRA", "Vehicle display key should ignore trim")

fordF250Spaced := AdvisorNormalizeVehicleDescriptor("2021 ford f 250")
AssertEqual(fordF250Spaced["year"], "2021", "Ford F 250 year should parse")
AssertEqual(fordF250Spaced["make"], "FORD", "Ford F 250 make should parse")
AssertEqual(fordF250Spaced["model"], "F250", "Ford F 250 should normalize to F250")
AssertEqual(fordF250Spaced["trimHint"], "", "Ford F 250 without extra trim should not keep numeric trim")
AssertEqual(fordF250Spaced["displayKey"], "2021|FORD|F250", "Ford F 250 display key should use canonical model")

fordF250Hyphen := AdvisorNormalizeVehicleDescriptor("2021 Ford F-250")
AssertEqual(fordF250Hyphen["model"], "F250", "Ford F-250 should normalize consistently")

fordF250Compact := AdvisorNormalizeVehicleDescriptor("2021 Ford F250")
AssertEqual(fordF250Compact["model"], "F250", "Ford F250 should normalize consistently")

fordF250Trimmed := AdvisorNormalizeVehicleDescriptor("2021 Ford F 250 Super Duty")
AssertEqual(fordF250Trimmed["model"], "F250", "Ford F 250 Super Duty should normalize model to F250")
AssertEqual(fordF250Trimmed["trimHint"], "SUPER DUTY", "Ford F 250 Super Duty should preserve remaining trim")

hondaPilotVehicle := AdvisorNormalizeVehicleDescriptor("2024 honda pilot")
AssertEqual(hondaPilotVehicle["make"], "HONDA", "Honda Pilot make should still normalize")
AssertEqual(hondaPilotVehicle["model"], "PILOT", "Honda Pilot model should still normalize")

hondaAccordVehicle := AdvisorNormalizeVehicleDescriptor("2009 honda accord")
AssertEqual(hondaAccordVehicle["make"], "HONDA", "Honda Accord make should still normalize")
AssertEqual(hondaAccordVehicle["model"], "ACCORD", "Honda Accord model should still normalize")

infinitiQx56Vehicle := AdvisorNormalizeVehicleDescriptor("2012 INFINITI QX56")
AssertEqual(infinitiQx56Vehicle["make"], "INFINITI", "Infiniti QX56 make should still normalize")
AssertEqual(infinitiQx56Vehicle["model"], "QX56", "Infiniti QX56 model should still normalize")

hondaCrvVehicle := AdvisorNormalizeVehicleDescriptor("2019 Honda CR-V")
AssertEqual(hondaCrvVehicle["make"], "HONDA", "Honda CR-V make should normalize")
AssertEqual(hondaCrvVehicle["model"], "CRV", "Honda CR-V should normalize to CRV for strict model matching")

hondaHrvVehicle := AdvisorNormalizeVehicleDescriptor("2019 Honda HR V")
AssertEqual(hondaHrvVehicle["make"], "HONDA", "Honda HR V make should normalize")
AssertEqual(hondaHrvVehicle["model"], "HRV", "Honda HR V should normalize to HRV for strict model matching")

hyundaiSonataVehicle := AdvisorNormalizeVehicleDescriptor("2013 Hyundai Sonata")
AssertEqual(hyundaiSonataVehicle["make"], "HYUNDAI", "Hyundai Sonata make should normalize")
AssertEqual(hyundaiSonataVehicle["model"], "SONATA", "Hyundai Sonata model should normalize")

nissanPartialVehicle := AdvisorNormalizeVehicleDescriptor("2010 Nissan")
AssertEqual(nissanPartialVehicle["year"], "2010", "Year/make-only Nissan should preserve year")
AssertEqual(nissanPartialVehicle["make"], "NISSAN", "Year/make-only Nissan should preserve make")
AssertEqual(nissanPartialVehicle["model"], "", "Year/make-only Nissan should remain partial with no model")
AssertEqual(nissanPartialVehicle["displayKey"], "2010|NISSAN", "Year/make-only Nissan should keep a partial display key")

nissanPartialWithFollowingLabels := AdvisorNormalizeVehicleDescriptor("2010 Nissan Driver 1 Name-Age:: Driver 2 Name-Age:: Calidad: A+ Idioma: Spanish")
AssertEqual(nissanPartialWithFollowingLabels["year"], "2010", "Year/make-only Nissan with following lead labels should preserve year")
AssertEqual(nissanPartialWithFollowingLabels["make"], "NISSAN", "Year/make-only Nissan with following lead labels should preserve make")
AssertEqual(nissanPartialWithFollowingLabels["model"], "", "Following lead labels should not become Nissan model text")
AssertEqual(nissanPartialWithFollowingLabels["displayKey"], "2010|NISSAN", "Following lead labels should preserve partial display key")

nissanPartialWithNote := AdvisorNormalizeVehicleDescriptor("2010 Nissan Note: informational coverage text")
AssertEqual(nissanPartialWithNote["year"], "2010", "Year/make-only Nissan before Note label should preserve year")
AssertEqual(nissanPartialWithNote["make"], "NISSAN", "Year/make-only Nissan before Note label should preserve make")
AssertEqual(nissanPartialWithNote["model"], "", "Note label should not become Nissan model text")
AssertEqual(nissanPartialWithNote["displayKey"], "2010|NISSAN", "Note label should preserve partial display key")

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

dupProfile := Map(
    "person", Map("firstName", "Test", "lastName", "Lead One", "dob", "01/16/1985"),
    "address", Map("street", "123 Example St", "zip", "32001")
)
goodCandidate := "Test Lead One 123 Example St Example City FL 32001"
badCandidate := "Test Other 456 Sample Ave Sample City FL 32002"

AssertTrue(AdvisorScoreDuplicateCandidate(goodCandidate, dupProfile) >= 100, "Good duplicate candidate should pass required checks")
AssertEqual(AdvisorScoreDuplicateCandidate(badCandidate, dupProfile), -1, "Bad duplicate candidate should fail required checks")

singleSpouse := ["", "d0b1-foo", "NewDriver"]
multiSpouse := ["", "d0b1-foo", "d0b2-bar"]
AssertEqual(AdvisorPickUniqueSpouseOption(singleSpouse), "d0b1-foo", "Unique spouse option should be returned")
AssertEqual(AdvisorPickUniqueSpouseOption(multiSpouse), "", "Multiple spouse options should not auto-pick")

policyProfile := Map("vehicles", [
    TestVehicle("2019", "HONDA", "PILOT"),
    TestVehicle("2007", "TOYOTA", "PRIUS"),
    TestVehicle("", "TOYOTA", "PRIUS PRIME")
])
policy := AdvisorQuoteClassifyGatherVehicles(policyProfile)
AssertEqual(policy["actionableVehicles"].Length, 2, "Mixed lead should have two actionable vehicles")
AssertEqual(policy["ignoredMissingYearVehicles"].Length, 1, "Missing-year/no-VIN vehicle should be ignored when actionable vehicles exist")
AssertEqual(policy["deferredVinVehicles"].Length, 0, "Mixed lead should have no VIN-deferred vehicles")
AssertEqual(policy["blockingMissingVehicleData"].Length, 0, "Mixed lead should not block on ignored missing-year vehicle")
AssertEqual(AdvisorQuoteBuildExpectedVehiclesTextFromList(policy["actionableVehicles"]), "2019|HONDA|PILOT|||2007|TOYOTA|PRIUS|", "Expected vehicle text should include only actionable vehicles")
expectedVehicleArgs := AdvisorQuoteBuildExpectedVehiclesArgList(policy["actionableVehicles"])
AssertEqual(expectedVehicleArgs.Length, 2, "Final guard expected vehicle args should include both actionable vehicles")
AssertEqual(expectedVehicleArgs[1]["year"], "2019", "Final guard should preserve first actionable year")
AssertEqual(expectedVehicleArgs[1]["make"], "HONDA", "Final guard should preserve first actionable make")
AssertEqual(expectedVehicleArgs[1]["model"], "PILOT", "Final guard should preserve first actionable model")
AssertEqual(expectedVehicleArgs[2]["year"], "2007", "Final guard should preserve second actionable year")
AssertEqual(expectedVehicleArgs[2]["make"], "TOYOTA", "Final guard should preserve second actionable make")
AssertEqual(expectedVehicleArgs[2]["model"], "PRIUS", "Final guard should preserve second actionable model")
AssertTrue(expectedVehicleArgs[1].Has("allowedMakeLabels"), "Final guard expected args should include compact catalog make labels")
AssertTrue(expectedVehicleArgs[1].Has("strictModelMatch"), "Final guard expected args should enable strict model matching")

highlanderLabels := AdvisorVehicleAllowedMakeLabelsText("Toyota", "Highlander", "2019")
AssertTrue(LabelListContains(highlanderLabels, "TOYOTA"), "Toyota Highlander labels should include TOYOTA")
AssertTrue(LabelListContains(highlanderLabels, "TOY. TRUCKS"), "Toyota Highlander labels should include TOY. TRUCKS")
corollaLabels := AdvisorVehicleAllowedMakeLabelsText("Toyota", "Corolla", "2019")
AssertTrue(LabelListContains(corollaLabels, "TOYOTA"), "Toyota Corolla labels should include TOYOTA")
AssertFalse(LabelListContains(corollaLabels, "TOY. TRUCKS"), "Toyota Corolla labels should not include Toyota truck bucket")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Mercedes-Benz", "GLE 350", "2019"), "MERCEDES-BNZ"), "Mercedes-Benz should map to MERCEDES-BNZ")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Ford", "F-150", "2019"), "FORD TRUCKS"), "Ford F-150 should map to FORD TRUCKS")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Ford", "Transit", "2019"), "FORD VANS"), "Ford Transit should map to FORD VANS")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Chevy", "Silverado 1500", "2019"), "CHEVY TRUCKS"), "Chevy Silverado should map to CHEVY TRUCKS")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Chevrolet", "Express", "2019"), "CHEVY VANS"), "Chevy Express should map to CHEVY VANS")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Ram", "1500", "2019"), "RAM TRUCKS"), "Ram 1500 should map to RAM TRUCKS")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Dodge", "Charger", "2019"), "DODGE"), "Dodge Charger should remain DODGE")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Dodge", "Durango", "2019"), "DODGE TRUCKS"), "Dodge Durango should map to DODGE TRUCKS")
AssertTrue(LabelListContains(AdvisorVehicleAllowedMakeLabelsText("Dodge", "Grand Caravan", "2019"), "DODGE VANS"), "Dodge Grand Caravan should map to DODGE VANS")
AssertFalse(AdvisorVehicleCatalogModelMatches("Prius", "Prius Prime"), "Prius must not match Prius Prime")
AssertTrue(AdvisorVehicleCatalogModelMatches("F-150", "F150"), "F-150 variants should normalize")
AssertFalse(AdvisorVehicleCatalogModelMatches("F-150", "F-250"), "F150 must not match F250")
AssertTrue(AdvisorVehicleCatalogModelMatches("CR-V", "CRV"), "CR-V variants should normalize")
AssertTrue(AdvisorVehicleCatalogModelMatches("HR V", "HR-V"), "HR-V variants should normalize")
AssertFalse(AdvisorVehicleCatalogModelMatches("CR-V", "HR-V"), "CR-V must not match HR-V")

vehicleDb := AdvisorVehicleDbLoad()
AssertTrue(vehicleDb["loaded"], "Vehicle DB runtime index should load")
AssertEqual(vehicleDb["meta"]["yearMin"], "2000", "Vehicle DB should report first covered year")
AssertEqual(vehicleDb["meta"]["yearMax"], "2026", "Vehicle DB should report last covered year")

dbCrv := AdvisorVehicleDbResolveLeadVehicle("2019", "Honda", "CR-V")
AssertEqual(dbCrv["result"], "RESOLVED", "Vehicle DB should resolve Honda CR-V")
AssertListContains(dbCrv["advisorMakeLabels"], "HONDA", "Honda CR-V DB labels should include HONDA")
AssertListContains(dbCrv["modelAliases"], "CR-V", "Honda CR-V DB aliases should include CR-V")
AssertListContains(dbCrv["modelAliases"], "CRV", "Honda CR-V DB aliases should include CRV")

dbF150 := AdvisorVehicleDbResolveLeadVehicle("2024", "Ford", "F-150")
AssertEqual(dbF150["result"], "RESOLVED", "Vehicle DB should resolve Ford F-150")
AssertListContains(dbF150["advisorMakeLabels"], "FORD TRUCKS", "Ford F-150 DB labels should include FORD TRUCKS")
AssertListContains(dbF150["normalizedModelKeys"], "F150", "Ford F-150 DB keys should include F150")

dbF250 := AdvisorVehicleDbResolveLeadVehicle("2024", "Ford", "F250")
AssertEqual(dbF250["result"], "RESOLVED", "Vehicle DB should resolve Ford F-250")
AssertListContains(dbF250["normalizedModelKeys"], "F250", "Ford F-250 DB keys should include F250")
AssertListNotContains(dbF250["normalizedModelKeys"], "F150", "Ford F-250 DB keys should not include F150")

dbPrius := AdvisorVehicleDbResolveLeadVehicle("2024", "Toyota", "Prius")
AssertEqual(dbPrius["result"], "RESOLVED", "Vehicle DB should resolve Toyota Prius")
AssertListNotContains(dbPrius["normalizedModelKeys"], "PRIUSPRIME", "Toyota Prius DB keys should not include Prius Prime")
dbPriusPrime := AdvisorVehicleDbResolveLeadVehicle("2024", "Toyota", "Prius Prime")
AssertEqual(dbPriusPrime["result"], "RESOLVED", "Vehicle DB should resolve Toyota Prius Prime through DB submodel evidence")
AssertListContains(dbPriusPrime["normalizedModelKeys"], "PRIUSPRIME", "Toyota Prius Prime DB keys should include PRIUSPRIME")

dbHighlander := AdvisorVehicleDbResolveLeadVehicle("2024", "Toyota", "Highlander")
AssertEqual(dbHighlander["result"], "RESOLVED", "Vehicle DB should resolve Toyota Highlander")
AssertListContains(dbHighlander["advisorMakeLabels"], "TOY. TRUCKS", "Toyota Highlander DB labels should include TOY. TRUCKS")

dbWrangler := AdvisorVehicleDbResolveLeadVehicle("2024", "Jeep", "WRANGLER UNLIMITE")
AssertEqual(dbWrangler["result"], "RESOLVED", "Vehicle DB should resolve truncated Wrangler Unlimited")
AssertListContains(dbWrangler["normalizedModelKeys"], "WRANGLERUNLIMITE", "Wrangler Unlimited DB keys should include truncated Advisor text")

dbCube := AdvisorVehicleDbResolveLeadVehicle("2010", "Nissan", "Cube")
AssertEqual(dbCube["result"], "RESOLVED", "Vehicle DB should resolve Nissan Cube")
dbMustang := AdvisorVehicleDbResolveLeadVehicle("2024", "Ford", "Mustang")
AssertEqual(dbMustang["result"], "RESOLVED", "Vehicle DB should resolve Ford Mustang")
dbRam1500 := AdvisorVehicleDbResolveLeadVehicle("2024", "Ram", "1500")
AssertEqual(dbRam1500["result"], "RESOLVED", "Vehicle DB should resolve Ram 1500 truck")
dbK5 := AdvisorVehicleDbResolveLeadVehicle("2024", "Kia", "K5")
AssertEqual(dbK5["result"], "RESOLVED", "Vehicle DB should resolve Kia K5")

dbFuso := AdvisorVehicleDbResolveLeadVehicle("2024", "Mitsubishi Fuso", "FE")
AssertEqual(dbFuso["result"], "UNKNOWN", "Vehicle DB should safely return UNKNOWN for unsupported Mitsubishi Fuso coverage")
dbMiss := AdvisorVehicleDbResolveLeadVehicle("2024", "MadeUp", "Nope")
AssertEqual(dbMiss["result"], "UNKNOWN", "Vehicle DB miss should return UNKNOWN safely")
dbAmbiguous := AdvisorVehicleDbResolveLeadVehicle("2024", "Ford", "MUST")
AssertEqual(dbAmbiguous["result"], "AMBIGUOUS", "Broad DB vehicle input should return AMBIGUOUS safely")

workflowDb := GetAdvisorQuoteWorkflowDb()
AssertEqual(AdvisorQuoteRapportVehicleMode(workflowDb), "match-existing-then-add-complete", "RAPPORT vehicle mode should default to match-existing-then-add-complete")
AssertTrue(AdvisorQuoteRapportVehicleModeAllowsAddComplete("match-existing-then-add-complete"), "Add-complete RAPPORT mode should allow controlled DB-backed adds")
AssertFalse(AdvisorQuoteRapportVehicleModeAllowsAddComplete("match-existing-only"), "Match-existing-only RAPPORT mode should defer unmatched complete vehicles")

dbTahoe := AdvisorVehicleDbResolveLeadVehicle("2010", "Chevy", "Tahoe")
AssertEqual(dbTahoe["result"], "RESOLVED", "Vehicle DB should resolve Chevrolet Tahoe-style vehicle")
AssertEqual(AdvisorQuotePreferredDbMakeLabel(dbTahoe, "CHEVY"), "CHEVY TRUCKS", "DB add should prefer Advisor truck bucket when DB evidence uses it")
tahoeVsSilveradoScore := AdvisorVehicleDbScoreAdvisorCard(dbTahoe, "2010 Chevrolet SILVERADO Confirm Remove")
AssertEqual(tahoeVsSilveradoScore["yearMatch"], "1", "Tahoe regression card score should still see same year")
AssertEqual(tahoeVsSilveradoScore["makeMatch"], "1", "Tahoe regression card score should still see same make family")
AssertEqual(tahoeVsSilveradoScore["modelMatch"], "0", "Tahoe must not match Silverado")
AssertTrue(AdvisorQuoteCompleteDbResolvedVehicleAddEligible(TestVehicle("2010", "CHEVY", "TAHOE"), dbTahoe, "match-existing-then-add-complete"), "Complete DB-resolved Tahoe should be eligible for controlled Add when unmatched")

dbCivic := AdvisorVehicleDbResolveLeadVehicle("2014", "Honda", "Civic")
AssertEqual(dbCivic["result"], "RESOLVED", "Vehicle DB should resolve Honda Civic-style vehicle")
AssertEqual(AdvisorQuotePreferredDbMakeLabel(dbCivic, "HONDA"), "HONDA", "DB add should preserve standard Advisor make label when no bucket is needed")
AssertTrue(AdvisorQuoteCompleteDbResolvedVehicleAddEligible(TestVehicle("2014", "HONDA", "CIVIC"), dbCivic, "match-existing-then-add-complete"), "Complete DB-resolved Civic should be eligible for controlled Add when unmatched")
AssertFalse(AdvisorQuoteCompleteDbResolvedVehicleAddEligible(TestVehicle("2014", "HONDA", ""), dbCivic, "match-existing-then-add-complete"), "Partial year/make-only vehicle should not be eligible for controlled Add")
AssertFalse(AdvisorQuoteCompleteDbResolvedVehicleAddEligible(TestVehicle("2024", "MADEUP", "NOPE"), dbMiss, "match-existing-then-add-complete"), "Unknown DB miss should not be eligible for controlled Add")
AssertFalse(AdvisorQuoteCompleteDbResolvedVehicleAddEligible(TestVehicle("2024", "FORD", "MUST"), dbAmbiguous, "match-existing-then-add-complete"), "Ambiguous DB result should not be eligible for controlled Add")
AssertFalse(AdvisorQuoteCompleteDbResolvedVehicleAddEligible(TestVehicle("2014", "HONDA", "CIVIC"), dbCivic, "match-existing-only"), "Match-existing-only mode should defer unmatched complete DB-resolved vehicles")

ascRouteDb := Map("urls", Map("ascProductContains", "/ASCPRODUCT/"))
ascWaitArgs := AdvisorQuoteAscWaitArgs(ascRouteDb)
AssertEqual(ascWaitArgs["ascProductContains"], "/ASCPRODUCT/", "ASC wait args should include ASCPRODUCT route family")
ascWaitArgsWithConsent := AdvisorQuoteAscWaitArgs(ascRouteDb, Map("consumerReportsConsentYesId", "orderReportsConsent-yes-btn"))
AssertEqual(ascWaitArgsWithConsent["ascProductContains"], "/ASCPRODUCT/", "ASC wait args with extras should preserve route family")
AssertEqual(ascWaitArgsWithConsent["consumerReportsConsentYesId"], "orderReportsConsent-yes-btn", "ASC wait args should carry consent selector extras")
AssertEqual(AdvisorQuoteAscProductRouteIdText("109"), "ASCPRODUCT/109", "ASC route id log text should avoid fixed route assumptions")

ascVehiclePolicy := AdvisorQuoteClassifyAscVehicles(Map("vehicles", [
    TestVehicle("2019", "HONDA", "CRV"),
    TestVehicle("2013", "HYUNDAI", "SONATA"),
    TestVehicle("2010", "NISSAN", "")
]))
AssertEqual(ascVehiclePolicy["completeVehicles"].Length, 2, "ASC policy should keep year/make/model vehicles complete")
AssertEqual(ascVehiclePolicy["partialYearMakeVehicles"].Length, 1, "ASC policy should classify year/make-only vehicle as partial")
AssertEqual(ascVehiclePolicy["partialYearMakeVehicles"][1]["displayKey"], "2010|NISSAN", "ASC partial should preserve year/make identity")

ascSingleLedgerProfile := TestAscProfile("Single", "", [TestVehicle("2019", "HONDA", "CRV")])
ascPrimaryNeedsAddLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascSingleLedgerProfile,
    TestAscSnapshot("1", "1"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=0|add=1|remove=0", "1", "0"),
    TestAscVehicleStatus("2019 Honda CRV|added=1|vin=1", "0", "1"),
    TestAscParticipantStatus("Single")
)
AssertEqual(AdvisorQuoteStatusValue(ascPrimaryNeedsAddLedger, "nextAction"), "add_primary_driver", "Ledger should add primary before other row actions")
AssertEqual(AdvisorQuoteStatusValue(ascPrimaryNeedsAddLedger, "primaryDriverStatus"), "needs_add", "Ledger should classify unadded primary row")

ascResolvedSingleLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascSingleLedgerProfile,
    TestAscSnapshot("1", "1"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=1|add=0|remove=0", "0", "1"),
    TestAscVehicleStatus("2019 Honda CRV|added=1|vin=1", "0", "1"),
    TestAscParticipantStatus("Single")
)
AssertEqual(AdvisorQuoteStatusValue(ascResolvedSingleLedger, "spousePolicy"), "single-wins", "Explicit Single should keep conservative spouse policy")
AssertEqual(AdvisorQuoteStatusValue(ascResolvedSingleLedger, "spouseStatus"), "not_applicable", "Explicit Single should not add spouse")
AssertEqual(AdvisorQuoteStatusValue(ascResolvedSingleLedger, "nextAction"), "save", "Resolved ledger with enabled save should save")

ascMarriedExactProfile := TestAscProfile("Married", "Test Exact Spouse", [TestVehicle("2019", "HONDA", "CRV")])
ascMarriedExactLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascMarriedExactProfile,
    TestAscSnapshot("1", "1"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=1|add=0|remove=0||Test Exact Spouse|age=38|added=0|add=1|remove=0", "1", "1"),
    TestAscVehicleStatus("2019 Honda CRV|added=1|vin=1", "0", "1"),
    TestAscParticipantStatus("Married", "Test Exact Spouse", "driver-a:Test Exact Spouse||driver-b:Test Other Candidate")
)
AssertEqual(AdvisorQuoteStatusValue(ascMarriedExactLedger, "nextAction"), "add_spouse_driver", "Married exact spouse row should be added when selected")
AssertEqual(AdvisorQuoteStatusValue(ascMarriedExactLedger, "selectedSpouseName"), "Test Exact Spouse", "Ledger should preserve selected exact spouse")

ascMarriedWindowProfile := TestAscProfile("Married", "", [TestVehicle("2019", "HONDA", "CRV")])
ascMarriedWindowLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascMarriedWindowProfile,
    TestAscSnapshot("1", "1"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=1|add=0|remove=0||Test Near Candidate|age=37|added=0|add=1|remove=0", "1", "1"),
    TestAscVehicleStatus("2019 Honda CRV|added=1|vin=1", "0", "1"),
    TestAscParticipantStatus("Married", "", "driver-a:Test Near Candidate")
)
AssertEqual(AdvisorQuoteStatusValue(ascMarriedWindowLedger, "nextAction"), "resolve_participant_policy", "Married unique age-window spouse should select participant policy before row add")
AssertEqual(AdvisorQuoteStatusValue(ascMarriedWindowLedger, "spouseStatus"), "needs_select", "Unique age-window spouse should be represented as needs_select")

ascMarriedAmbiguousLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascMarriedWindowProfile,
    TestAscSnapshot("1", "1"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=1|add=0|remove=0||Test Candidate One|age=38|added=0|add=1|remove=0||Test Candidate Two|age=37|added=0|add=1|remove=0", "2", "1"),
    TestAscVehicleStatus("2019 Honda CRV|added=1|vin=1", "0", "1"),
    TestAscParticipantStatus("Married", "", "driver-a:Test Candidate One||driver-b:Test Candidate Two")
)
AssertEqual(AdvisorQuoteStatusValue(ascMarriedAmbiguousLedger, "nextAction"), "fail", "Married multiple age-window candidates should fail safe")
AssertTrue(InStr(AdvisorQuoteStatusValue(ascMarriedAmbiguousLedger, "reason"), "ASC_SPOUSE_AMBIGUOUS") = 1, "Ambiguous spouse failure should be explicit")

ascExtraDriverLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascSingleLedgerProfile,
    TestAscSnapshot("1", "1"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=1|add=0|remove=0||Test Other Driver|age=66|added=0|add=0|remove=1", "1", "1"),
    TestAscVehicleStatus("2019 Honda CRV|added=1|vin=1", "0", "1"),
    TestAscParticipantStatus("Single")
)
AssertEqual(AdvisorQuoteStatusValue(ascExtraDriverLedger, "nextAction"), "remove_extra_driver", "Ledger should remove unrelated driver after expected drivers are resolved")
AssertEqual(AdvisorQuoteStatusValue(ascExtraDriverLedger, "nextActionTarget"), "Test Other Driver", "Ledger should target the extra driver row by summary")

ascRemoveModalLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascSingleLedgerProfile,
    TestAscSnapshot("1", "0", "ASC_REMOVE_DRIVER_MODAL", "NONE", "ASC_REMOVE_DRIVER_MODAL_OPEN"),
    Map(),
    Map(),
    Map()
)
AssertEqual(AdvisorQuoteStatusValue(ascRemoveModalLedger, "nextAction"), "handle_remove_driver_modal", "Remove modal should route before row reconciliation")

ascInlinePanelLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascSingleLedgerProfile,
    TestAscSnapshot("1", "0", "NONE", "ASC_INLINE_PARTICIPANT_PANEL", "ASC_INLINE_PARTICIPANT_PANEL_OPEN"),
    Map(),
    Map(),
    Map()
)
AssertEqual(AdvisorQuoteStatusValue(ascInlinePanelLedger, "nextAction"), "handle_inline_participant_panel", "Inline participant panel should route before row reconciliation")

ascVehicleNeedsAddLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascSingleLedgerProfile,
    TestAscSnapshot("1", "0"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=1|add=0|remove=0", "0", "1"),
    TestAscVehicleStatus("2019 Honda CRV|added=0|vin=1", "1", "0"),
    TestAscParticipantStatus("Single")
)
AssertEqual(AdvisorQuoteStatusValue(ascVehicleNeedsAddLedger, "nextAction"), "add_vehicle_row", "Ledger should add expected ASC vehicle membership row")

ascSaveDisabledLedger := AdvisorQuoteBuildAscDriversVehiclesLedger(
    ascSingleLedgerProfile,
    TestAscSnapshot("1", "0"),
    TestAscDriverStatus("Test Primary Driver|age=40|added=1|add=0|remove=0", "0", "1"),
    TestAscVehicleStatus("2019 Honda CRV|added=1|vin=1", "0", "1"),
    TestAscParticipantStatus("Single")
)
AssertEqual(AdvisorQuoteStatusValue(ascSaveDisabledLedger, "nextAction"), "fail", "Resolved ledger with disabled save should fail diagnostic")
AssertTrue(InStr(AdvisorQuoteStatusValue(ascSaveDisabledLedger, "reason"), "ASC_SAVE_DISABLED_AFTER_LEDGER_RESOLUTION") = 1, "Disabled save diagnostic should be explicit")
AssertFalse(AdvisorQuoteAscLedgerLoopGuardHit(2), "Repeated same action should be allowed through the second attempt")
AssertTrue(AdvisorQuoteAscLedgerLoopGuardHit(3), "Repeated same action guard should trigger after two attempts")

gatherPartialPolicy := AdvisorQuoteClassifyGatherVehicles(Map("vehicles", [
    TestVehicle("2019", "HONDA", "CRV"),
    TestVehicle("2013", "HYUNDAI", "SONATA"),
    TestVehicle("2010", "NISSAN", "")
]))
AssertEqual(gatherPartialPolicy["actionableVehicles"].Length, 2, "Gather policy should keep complete vehicles actionable")
AssertEqual(gatherPartialPolicy["partialYearMakeVehicles"].Length, 1, "Gather policy should keep year/make-only vehicles in partial preflight")
AssertEqual(gatherPartialPolicy["partialYearMakeVehicles"][1]["displayKey"], "2010|NISSAN", "Gather partial should preserve year/make identity")

gatherRawRecoveryProfile := Map(
    "raw", "PERSONAL LEAD - Test Lead One 04/22/2026 10:00:00 AM 123 Example St Example City FL 32001 (555) 010-0001 test.lead.one@example.com Jan 1985 Male 2019 Honda CR-V 2013 Hyundai Sonata 2010 Nissan Note: synthetic coverage note Driver 1 Name-Age::",
    "vehicles", [
        TestVehicle("2019", "HONDA", "CRV"),
        TestVehicle("2013", "HYUNDAI", "SONATA")
    ]
)
gatherRawRecoveryPolicy := AdvisorQuoteClassifyGatherVehicles(gatherRawRecoveryProfile)
AssertEqual(gatherRawRecoveryPolicy["actionableVehicles"].Length, 2, "Gather policy should keep profile complete vehicles actionable during raw recovery")
AssertEqual(gatherRawRecoveryPolicy["partialYearMakeVehicles"].Length, 1, "Gather policy should recover omitted year/make-only vehicle from raw lead text")
AssertEqual(gatherRawRecoveryPolicy["partialYearMakeVehicles"][1]["displayKey"], "2010|NISSAN", "Recovered raw partial should preserve year/make identity")

singleLeadProfile := Map("raw", "Marital Status: Single", "person", Map("fullName", "Test Single Lead"))
AssertEqual(AdvisorQuoteLeadMaritalStatus(singleLeadProfile), "Single", "Lead marital status parser should preserve Single truth")

missingOnlyPolicy := AdvisorQuoteClassifyGatherVehicles(Map("vehicles", [
    TestVehicle("", "TOYOTA", "PRIUS PRIME")
]))
AssertEqual(missingOnlyPolicy["actionableVehicles"].Length, 0, "Missing-year-only lead should have no actionable vehicles")
AssertEqual(missingOnlyPolicy["blockingMissingVehicleData"].Length, 1, "Missing-year-only lead should block/manual")

vinDeferredPolicy := AdvisorQuoteClassifyGatherVehicles(Map("vehicles", [
    TestVehicle("", "TOYOTA", "PRIUS PRIME", "JTDKN3DP0D3000000")
]))
AssertEqual(vinDeferredPolicy["actionableVehicles"].Length, 0, "VIN-only missing-year lead should have no Gather Data actionable vehicles")
AssertEqual(vinDeferredPolicy["deferredVinVehicles"].Length, 1, "VIN-present missing-year lead should defer for later VIN-aware handling")
AssertEqual(vinDeferredPolicy["blockingMissingVehicleData"].Length, 0, "VIN-deferred vehicle should not be classified as generic missing data")

confirmedVehicleStatus := Map(
    "result", "ADDED",
    "confirmedVehicleMatched", "1",
    "confirmedStatusMatched", "1",
    "yearMatched", "1",
    "makeMatched", "1",
    "modelMatched", "1",
    "matchedText", "2019 Honda PILOT CONFIRMED"
)
AssertTrue(AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(confirmedVehicleStatus), "Exact confirmed-card status should count as already confirmed")

partialVehicleStatus := Map(
    "result", "ADDED",
    "confirmedVehicleMatched", "1",
    "confirmedStatusMatched", "1",
    "yearMatched", "1",
    "makeMatched", "1",
    "modelMatched", "0"
)
AssertFalse(AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(partialVehicleStatus), "Confirmed-card status must still match exact model")

partialPromotedStatus := Map(
    "result", "ADDED",
    "partialPromoted", "1",
    "confirmedVehicleMatched", "1",
    "confirmedStatusMatched", "1",
    "yearMatched", "1",
    "makeMatched", "1",
    "modelMatched", "1",
    "promotedModel", "CUBE",
    "promotedVinEvidence", "1",
    "promotionSource", "confirmed-card",
    "promotedVehicleText", "2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED"
)
AssertTrue(AdvisorQuoteGatherVehiclePartialStatusPromoted(partialPromotedStatus), "Unique VIN-bearing confirmed card should promote partial year/make vehicle")
promotedPartial := AdvisorQuoteBuildGatherPromotedPartialVehicle(nissanPartialVehicle, partialPromotedStatus)
AssertEqual(promotedPartial["year"], "2010", "Promoted partial should preserve year")
AssertEqual(promotedPartial["make"], "NISSAN", "Promoted partial should preserve make")
AssertEqual(promotedPartial["model"], "CUBE", "Promoted partial should use confirmed-card model")
AssertEqual(promotedPartial["displayKey"], "2010|NISSAN|CUBE", "Promoted partial should contribute a complete display key")
AssertEqual(promotedPartial["promotedFromPartial"], "1", "Promoted partial should carry first-class promotion marker")
finalExpectedVehiclesWithPromoted := AdvisorQuoteBuildGatherFinalExpectedVehicles(
    [TestVehicle("2019", "HONDA", "CRV"), TestVehicle("2013", "HYUNDAI", "SONATA")],
    [promotedPartial]
)
finalExpectedWithPromoted := AdvisorQuoteBuildExpectedVehiclesArgList(finalExpectedVehiclesWithPromoted)
AssertEqual(finalExpectedVehiclesWithPromoted.Length, 3, "Final expected list should include complete vehicles plus promoted partials")
AssertEqual(AdvisorQuoteVehicleListSummary(finalExpectedVehiclesWithPromoted), "2019|HONDA|CRV || 2013|HYUNDAI|SONATA || 2010|NISSAN|CUBE", "Final expected summary should include promoted partial")
AssertEqual(finalExpectedWithPromoted.Length, 3, "Final guard should include complete vehicles plus promoted partials")
AssertEqual(finalExpectedWithPromoted[3]["model"], "CUBE", "Final guard should include promoted partial model")
AssertEqual(finalExpectedWithPromoted[3]["promotedFromPartial"], "1", "Final guard args should preserve promoted partial marker")
AssertEqual(AdvisorQuoteCountExpectedArgsMatchingVehicles(finalExpectedWithPromoted, [promotedPartial]), 1, "Promoted partial should be counted in final expected args")
AssertEqual(AdvisorQuoteExpectedArgsMissingVehiclesSummary(finalExpectedWithPromoted, [promotedPartial]), "", "Promoted partial should not be reported dropped from final expected args")

unpromotedPartialFinalExpected := AdvisorQuoteBuildGatherFinalExpectedVehicles([TestVehicle("2019", "HONDA", "CRV")], [])
unpromotedPartialFinalArgs := AdvisorQuoteBuildExpectedVehiclesArgList(unpromotedPartialFinalExpected)
AssertEqual(unpromotedPartialFinalArgs.Length, 1, "Unpromoted partials should stay deferred and out of final expected args")
AssertEqual(unpromotedPartialFinalArgs[1]["model"], "CRV", "Unpromoted partial final args should contain only complete expected vehicles")

missingConfirmedStatus := Map(
    "result", "OK",
    "expectedCount", "2",
    "matchedExpectedCount", "1",
    "missingExpectedVehicles", "2007 Toyota PRIUS",
    "unexpectedVehicles", "",
    "unresolvedLeadVehicles", ""
)
missingReason := ""
AssertFalse(AdvisorQuoteGatherConfirmedVehiclesSafe(missingConfirmedStatus, Map(), &missingReason), "Missing actionable confirmed vehicles should fail final reconciliation")
AssertTrue(InStr(missingReason, "MISSING_EXPECTED_CONFIRMED_VEHICLES") = 1, "Missing confirmed failure should use explicit reason")

safeConfirmedStatus := Map(
    "result", "OK",
    "expectedCount", "2",
    "matchedExpectedCount", "2",
    "missingExpectedVehicles", "",
    "unexpectedVehicles", "",
    "unresolvedLeadVehicles", "TOYOTA PRIUS PRIME"
)
safeReason := ""
AssertTrue(AdvisorQuoteGatherConfirmedVehiclesSafe(safeConfirmedStatus, Map(), &safeReason), "Ignored missing-year vehicles should not block final reconciliation when expected actionable vehicles match")

startQuotingDb := GetAdvisorQuoteWorkflowDb()
startQuotingDisabledWithScopedAdd := Map(
    "hasStartQuotingText", "1",
    "startQuotingSectionPresent", "1",
    "autoProductPresent", "1",
    "autoProductChecked", "1",
    "autoProductSelected", "1",
    "ratingStateValue", "FL",
    "ratingStateText", "Florida",
    "createQuoteButtonPresent", "1",
    "createQuoteButtonEnabled", "0",
    "addProductLinkPresent", "1",
    "addProductPresent", "1"
)
startQuotingReason := ""
AssertFalse(AdvisorQuoteGatherStartQuotingStatusValid(startQuotingDisabledWithScopedAdd, startQuotingDb, &startQuotingReason), "Disabled Create Quotes should not be fully ready before handoff")
AssertEqual(startQuotingReason, "Create Quotes & Order Reports is still disabled on Gather Data.", "Disabled Create Quotes reason should remain explicit")
AssertTrue(AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(startQuotingDisabledWithScopedAdd, startQuotingDb, &startQuotingReason), "Scoped Start Quoting Add product should be eligible before disabled Create Quotes failure")
AssertEqual(startQuotingReason, "START_QUOTING_NEEDS_SCOPED_ADD_PRODUCT", "Scoped handoff should distinguish needs-handoff from failure")
AssertTrue(AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(startQuotingDisabledWithScopedAdd, startQuotingDb, true, &startQuotingReason), "Verified Product Tile Auto should allow scoped handoff")
AssertFalse(AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(startQuotingDisabledWithScopedAdd, startQuotingDb, false, &startQuotingReason), "Unverified Product Tile Auto should block scoped handoff")
AssertEqual(startQuotingReason, "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED", "Blocked scoped handoff should preserve Product Tile Auto gate reason")

startQuotingEnabled := startQuotingDisabledWithScopedAdd.Clone()
startQuotingEnabled["createQuoteButtonEnabled"] := "1"
AssertTrue(AdvisorQuoteGatherStartQuotingStatusValid(startQuotingEnabled, startQuotingDb, &startQuotingReason), "Enabled Create Quotes should be ready without Add product handoff")
AssertFalse(AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(startQuotingEnabled, startQuotingDb, &startQuotingReason), "Enabled Create Quotes should not run Add product handoff")

startQuotingSidebarOnly := startQuotingDisabledWithScopedAdd.Clone()
startQuotingSidebarOnly["addProductLinkPresent"] := "0"
startQuotingSidebarOnly["addProductPresent"] := "0"
AssertFalse(AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(startQuotingSidebarOnly, startQuotingDb, &startQuotingReason), "Sidebar-only Add Product should not satisfy scoped handoff")

startQuotingAutoUnchecked := startQuotingDisabledWithScopedAdd.Clone()
startQuotingAutoUnchecked["autoProductChecked"] := "0"
startQuotingAutoUnchecked["autoProductSelected"] := "0"
AssertFalse(AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(startQuotingAutoUnchecked, startQuotingDb, &startQuotingReason), "Unchecked Start Quoting Auto should block Add product handoff")

legacyCreateQuotesAliasStatus := Map(
    "hasStartQuotingText", "1",
    "startQuotingSectionPresent", "1",
    "autoProductPresent", "1",
    "autoProductChecked", "1",
    "ratingStateValue", "FL",
    "ratingStateText", "Florida",
    "createQuotesPresent", "1",
    "createQuotesEnabled", "1",
    "addProductLinkPresent", "0"
)
AssertTrue(AdvisorQuoteGatherStartQuotingStatusValid(legacyCreateQuotesAliasStatus, startQuotingDb, &startQuotingReason), "Create Quotes alias fields should still be accepted")
AssertTrue(AdvisorQuoteStartQuotingScopedAddProductPresent(Map("startQuotingAddProductPresent", "1")), "Future Start Quoting Add product alias should be accepted")

headless := false
for _, arg in A_Args {
    if (arg = "--headless" || arg = "headless") {
        headless := true
        break
    }
}

ExitApp(0)

TestVehicle(year, make, model, vin := "") {
    display := Trim(String(year) "|" String(make) "|" String(model), "|")
    vehicle := Map(
        "year", year,
        "make", make,
        "model", model,
        "raw", Trim(year " " make " " model),
        "trimHint", "",
        "displayKey", display
    )
    if (vin != "") {
        vehicle["vin"] := vin
        vehicle["vinSuffix"] := SubStr(vin, -5)
    }
    return vehicle
}

TestAscProfile(maritalStatus, spouseName := "", vehicles := "") {
    raw := "Marital Status: " maritalStatus
    if (Trim(String(spouseName)) != "")
        raw .= "`nSpouse: " spouseName
    return Map(
        "raw", raw,
        "person", Map("fullName", "Test Primary Driver"),
        "vehicles", IsObject(vehicles) ? vehicles : []
    )
}

TestAscSnapshot(mainSavePresent := "1", mainSaveEnabled := "0", activeModalType := "NONE", activePanelType := "NONE", blockerCode := "", unresolvedDriverCount := "0", unresolvedVehicleCount := "0", addedVehicleCount := "0") {
    return Map(
        "result", "OK",
        "routeFamily", "ASCPRODUCT",
        "ascProductRouteId", "112",
        "activeModalType", activeModalType,
        "activePanelType", activePanelType,
        "blockerCode", blockerCode,
        "unresolvedDriverCount", unresolvedDriverCount,
        "unresolvedVehicleCount", unresolvedVehicleCount,
        "addedVehicleCount", addedVehicleCount,
        "mainSavePresent", mainSavePresent,
        "mainSaveEnabled", mainSaveEnabled
    )
}

TestAscParticipantStatus(maritalStatus, spouseText := "", spouseOptions := "") {
    return Map(
        "result", "FOUND",
        "maritalStatusSelected", maritalStatus,
        "spouseDropdownText", spouseText,
        "spouseOptions", spouseOptions,
        "ageFirstLicensedValue", "16",
        "propertyOwnershipValue", "0001_0120",
        "propertyOwnershipText", "Own Home",
        "missing", ""
    )
}

TestAscDriverStatus(driverSummaries, unresolvedDriverCount := "0", addedDriverCount := "0") {
    return Map(
        "result", "FOUND",
        "driverCount", String(AdvisorQuoteAscSplitSummaryRecords(driverSummaries).Length),
        "unresolvedDriverCount", unresolvedDriverCount,
        "addedDriverCount", addedDriverCount,
        "removedDriverCount", "0",
        "driverSummaries", driverSummaries
    )
}

TestAscVehicleStatus(vehicleSummaries, unresolvedVehicleCount := "0", addedVehicleCount := "0") {
    return Map(
        "result", "FOUND",
        "vehicleCount", String(AdvisorQuoteAscSplitSummaryRecords(vehicleSummaries).Length),
        "unresolvedVehicleCount", unresolvedVehicleCount,
        "addedVehicleCount", addedVehicleCount,
        "confirmedOrAddedVehicleCount", addedVehicleCount,
        "removedVehicleCount", "0",
        "vehicleSummaries", vehicleSummaries
    )
}

AssertEqual(actual, expected, message) {
    if (actual != expected)
        throw Error(message . "`nExpected: " expected "`nActual: " actual)
}

AssertTrue(condition, message) {
    if !condition
        throw Error(message)
}

AssertFalse(condition, message) {
    if condition
        throw Error(message)
}

LabelListContains(labels, wanted) {
    needle := "|" AdvisorVehicleNormalizeText(wanted) "|"
    haystack := "|"
    for _, label in StrSplit(String(labels), "|") {
        if (Trim(label) != "")
            haystack .= AdvisorVehicleNormalizeText(label) "|"
    }
    return InStr(haystack, needle) > 0
}

AssertListContains(list, wanted, message) {
    if !VehicleTestListContains(list, wanted)
        throw Error(message)
}

AssertListNotContains(list, wanted, message) {
    if VehicleTestListContains(list, wanted)
        throw Error(message)
}

VehicleTestListContains(list, wanted) {
    needle := AdvisorVehicleNormalizeText(wanted)
    if !IsObject(list)
        list := StrSplit(String(list), "|")
    for _, item in list {
        if (AdvisorVehicleNormalizeText(item) = needle)
            return true
    }
    return false
}
