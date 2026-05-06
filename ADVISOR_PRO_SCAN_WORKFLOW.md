# Advisor Pro Scan Workflow Reference

This is the scan-backed workflow reference for the implemented Advisor Pro quote automation. It keeps only selectors, text anchors, route families, and business rules that the current workflow depends on.

## Entry

- Hotkey: `Ctrl+Alt+-` / AHK `^!-`
- AHK entry: `RunAdvisorQuoteWorkflowFromClipboard()`
- Landing quote button: `button#group2_Quoting_button`
- Begin quoting continue button: `button#PrimaryApplicant-Continue-button`

## Prospect And Duplicate Handling

- Prospect fields are filled from the normalized clipboard lead profile.
- New-prospect readiness is checked through the JS operator before writing.
- Address verification is handled as an intermediate state when `snaOption` radio choices and `Continue with Selected` are present.
- Duplicate page text anchor: `This Prospect May Already Exist`
- Duplicate candidate shape can include `.sfmOption` rows.
- Existing prospect selection requires an exact normalized last name and normalized address match on street number, street text, and ZIP. First-name exact/prefix/fuzzy match is supporting evidence. DOB is weak evidence only.
- If exactly one duplicate candidate passes the required checks, select it. Otherwise create a new prospect.

## Customer Summary Overview

- Route family: `/apps/customer-summary/{id}/overview`
- Primary action text: `START HERE (Pre-fill included)`
- Supporting anchors: `Quote History`, `Assets Details`, `Contact Information`, `Family Members`, `Net Worth`
- Implemented effect: click `START HERE (Pre-fill included)` and wait for Product Overview, Rapport, Select Product, ASC Product, or Incidents.
- Do not click `START HERE` if the flow is already on `/apps/intel/102/overview` or a later quote state.

## Product Overview Grid

- Route: `/apps/intel/102/overview`
- Page text: `Select Product`
- Product tile text: `Auto`
- Continue text: `Save & Continue to Gather Data`
- Implemented effect: resolve the scoped Auto tile, select it only when not already selected, verify selected-state evidence, then continue to Rapport.
- This is not the older `/selectProduct` form page. The current implementation uses text/card resolution for this grid, not the `SelectProduct.Product` dropdown.

## Gather Data / Rapport

- Route: `/apps/intel/102/rapport`
- Vehicle row prefix: `ConsumerData.Assets.Vehicles[n]`
- Vehicle fields:
  - `ConsumerData.Assets.Vehicles[n].ModelYear`
  - `ConsumerData.Assets.Vehicles[n].VehIdentificationNumber`
  - `ConsumerData.Assets.Vehicles[n].Manufacturer`
  - `ConsumerData.Assets.Vehicles[n].Model`
  - `ConsumerData.Assets.Vehicles[n].SubModel`
- Confirm/add button: `button#confirmNewVehicle`
- Person defaults used here:
  - email: `input#ConsumerData.People[0].Communications.EmailAddr`
  - age first licensed: `input#ConsumerData.People[0].Driver.AgeFirstLicensed`
- Vehicle cascade is `Year -> Manufacturer -> Model -> Sub-Model`. Later fields remain disabled until prior fields are set.
- Existing vehicle cards are matched by exact year, DB-backed Advisor make label/family, DB-normalized model key, and VIN evidence when available.
- Confirmed cards are read first; exactly one DB-backed confirmed card satisfies a lead vehicle.
- Potential/public-record cards can be confirmed only when exactly one scoped DB-backed card matches.
- If no safe existing Advisor card matches, the lead vehicle is skipped/deferred in Rapport. Do not open Add Car or Truck for that unmatched vehicle.
- Broad dropdown construction is not allowed for unmatched Rapport vehicles. Do not select the first model from a broad dropdown.
- First valid non-placeholder Sub-Model selection is acceptable only inside an already-open Edit Vehicle panel when Advisor requires completion and no safer VIN/trim evidence distinguishes options.
- If an open Edit Vehicle panel already has required fields populated and `Update` is enabled, click `Update` and verify the panel closes or the matching vehicle becomes confirmed.
- Partial year/make lead vehicles may be promoted only from a unique confirmed card with visible model text and VIN or masked-VIN evidence.
- The later Drivers and Vehicles page only reconciles quote membership. It does not create lead vehicles.

## Start Quoting On Rapport

- Auto checkbox: `input#ConsumerReports.Auto.Product-intel#102`
- Rating state select: `select#ConsumerReports.Auto.RatingState`
- Create quote button: `button#consentModalTrigger`
- Quote-block Add Product link: `a#quotesButton`
- Sidebar Add Product link: `a#addProduct`
- Implemented primary path: verify the Start Quoting block, ensure Auto is checked, ensure rating state is `FL`, click `Create Quotes & Order Reports`, then wait for Consumer Reports, Drivers and Vehicles, Incidents, or quote landing.
- Implemented fallback path: use Add Product / `/selectProduct` only when the Start Quoting block cannot be made valid.

## Select Product Form Fallback

- Route: `/apps/intel/102/selectProduct`
- Rating state: `select#SelectProduct.RatingState`
- Product: `select#SelectProduct.Product`
- Current insured radios: `input#SelectProduct.CustomerCurrentInsured`
- Own/rent radios: `input#SelectProduct.CustomerOwnOrRent`
- Continue button: `button#selectProductContinue`
- Defaults: product `AUTO`, rating state `FL`, current insured `YES`, own/rent `OWN`.

## Consumer Reports

- Route family: `/apps/ASCPRODUCT/{id}/`
- Text anchor: `order consumer reports`
- Consent button: `button#orderReportsConsent-yes-btn`
- Implemented effect: always click Yes.

## Drivers And Vehicles

- Route family: `/apps/ASCPRODUCT/{id}/`
- Text anchor: `Drivers and vehicles`
- Continue button: `button#profile-summary-submitBtn`
- Driver actions use row-scoped add/remove buttons.
- Vehicle actions use row-scoped add buttons and modal handling.
- Implemented rules:
  - Always add the lead driver.
  - Never leave a driver unresolved.
  - Remove extra drivers with the configured reason.
  - Do not remove extra vehicles.
  - Add only lead-matching vehicles to the quote and leave non-matching vehicles untouched.
  - Save only after driver and vehicle reconciliation reaches a complete state.

## Participant Detail Modal

- Heading anchor: `Let's get some more details`
- Save button: `button#PARTICIPANT_SAVE-btn`
- Known controls:
  - gender: `input#gender_1002` / `input#gender_1001`
  - marital status: `input#maritalStatusEntCd_0006`, `input#maritalStatusEntCd_0001`, `input#maritalStatusEntCd_0007`
  - spouse chooser: `select#maritalStatusWithSpouse_spouseName`
  - property ownership: `select#propertyOwnershipEntCd_option`
  - age first licensed: `input#ageFirstLicensed_ageFirstLicensed`
  - military: `input#militaryInd_true` / `input#militaryInd_false`
  - violations: `input#violationInd_true` / `input#violationInd_false`
  - defensive driving: `input#defensiveDriverInd_true` / `input#defensiveDriverInd_false`
  - email: `input#emailAddress.emailAddress`
  - phone: `input#phoneNumber_phoneNumber`
- Defaults: lead gender, military No, moving violations No, defensive driving No when shown, own home unless the parsed address classifies as renter, age first licensed `16`.
- Married leads select an exact spouse match first, then a unique safe spouse candidate. Single or unknown leads may select Married only when the ASC spouse override is enabled and exactly one Advisor-surfaced driver candidate is within the configured age window and present in the spouse dropdown; otherwise they keep Single/no spouse. Same last name alone is not enough.

## Remove Driver Modal

- Save button: `button#REMOVE_PARTICIPANT_SAVE-btn`
- Configured reason: `input#nonDriverReasonOthers_0006` / own car insurance.
- Implemented effect: select the reason and save the scoped removal modal.

## Vehicle Add Modal

- Save button: `button#ADD_ASSET_SAVE-btn`
- Ownership controls:
  - own: `input#vehicleOwnershipCd_0001`
  - lease: `input#vehicleOwnershipCd_0003`
  - finance: `input#vehicleOwnershipCd_0007`
- Garaging same as home: `input#garagingAddressSameAsOther-control-item-0`
- Purchased within 90 days No: `input#purchaseDate_false`
- Implemented defaults: garaging Yes, recent purchase No, ownership Finance when vehicle year is greater than `2015`; leave ownership blank for `2015` or older.

## Incidents

- Route family: `/apps/ASCPRODUCT/{id}/`
- Text anchor: `Incidents`
- Continue button: `button#CONTINUE_OFFER-btn`
- Back button: `button#BACK_TO_PROFILE_SUMMARY-btn`
- Incident ids are dynamic; use label text.
- Configured incident reason: `Accident caused by being hit by animal or road debris`
- Implemented effect: choose that label and continue.

## Quote Landing

- Route family: `/apps/ASCPRODUCT/{id}/`
- Success condition: page has quote/offer landing evidence after incidents or reconciliation.
- Workflow returns success at the first quote-ready page.

## Workflow Defaults

- Rating state: `FL`
- Current insured: `Yes`
- Own/rent: `Own`
- Consumer reports: `Yes`
- Age first licensed: `16`
- Military: `No`
- Moving violations: `No`
- Defensive driving: `No` only when the question appears
- Vehicle ownership: `Finance` for `year > 2015`, blank for `year <= 2015`
- Garaging: `Yes`
- Purchased in last 90 days: `No`
- Remove-driver reason: own car insurance
- Incident reason: animal or road debris

## Safety Rules

- Every page wait, action wait, retry loop, and readiness loop must have an explicit timeout.
- Do not send Enter unless the active context and target field are verified.
- Do not assume the correct browser tab merely because Edge or Chrome is focused.
- Preserve clipboard contents where practical; document any destructive clipboard action when preservation is not practical.
- Scan-backed selectors and text anchors in this file are the source of truth for Advisor Pro workflow patches.
