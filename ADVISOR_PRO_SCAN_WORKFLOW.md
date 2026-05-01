# Advisor Pro Scan Workflow Reference

This document consolidates the scan-backed workflow details for the refactored Advisor Pro quote automation.

It is organized by workflow stage and only includes selectors, ids, text anchors, and business rules that came from the scans and user confirmations in this thread.

## 1. Advisor Pro Entry

### Advisor Pro home
- Purpose: enter the quoting flow from the Advisor Pro landing page.
- Known control:
  - `button#group2_Quoting_button`

### Begin Quoting
- Purpose: move from the start page into the prospect flow.
- Known control:
  - `button#PrimaryApplicant-Continue-button`

## 2. Prospect Creation and Duplicate Resolution

### New Prospect
- The refactored app already has a prospect fill path via `FillNewProspectForm(fields)`.
- Current scan retention for this stage is behavioral, not selector-complete.
- Practical rule:
  - use the normalized clipboard lead
  - continue into duplicate resolution or a newly created prospect

### Duplicate prospect page
- User-confirmed page text:
  - `This Prospect May Already Exist`
- Earlier scan reference mentioned duplicate candidate rows as:
  - `.sfmOption`
- Matching rule confirmed by the user:
  - require exact normalized last-name match
  - require normalized address match on street number + street text + zip
  - use first-name exact/prefix/fuzzy match as supporting evidence
  - DOB is weak evidence only
- Decision rule:
  - if exactly one row passes the required checks, select it
  - otherwise create a new prospect

## 3. Gather Data / Rapport

### Page
- URL pattern:
  - `https://advisorpro.allstate.com/#/apps/intel/102/rapport`

### Known vehicle row structure
- Vehicle row index is dynamic:
  - `ConsumerData.Assets.Vehicles[n]`
- Required add-car fields:
  - `ConsumerData.Assets.Vehicles[n].ModelYear`
  - `ConsumerData.Assets.Vehicles[n].VehIdentificationNumber`
  - `ConsumerData.Assets.Vehicles[n].Manufacturer`
  - `ConsumerData.Assets.Vehicles[n].Model`
  - `ConsumerData.Assets.Vehicles[n].SubModel`
- Confirm/add button:
  - `button#confirmNewVehicle`

### Known person fields used for defaults
- Email:
  - `input#ConsumerData.People[0].Communications.EmailAddr`
- Age first licensed:
  - `input#ConsumerData.People[0].Driver.AgeFirstLicensed`

### Known vehicle flow
- Confirmed progressive dependency:
  - `Year -> Manufacturer -> Model -> Sub-Model`
- Confirmed behavior:
  - `Manufacturer`, `Model`, and `Sub-Model` stay disabled until prior fields are set
  - if no exact trim/submodel match is available, first non-empty submodel is acceptable

### Existing vehicle tiles
- Example scan-backed headings:
  - `h3#2CARTRUCK_0_title` -> `2021 Nissan SENTRA 3N1AB8CV1MY219911`
  - `h3#1CARTRUCK_0_title` -> `2026 Toyota TACOMA 3TYKB5FN0TT032861`
  - `h3#3CARTRUCK_0_title` -> `2020 Toyota RAV4 JTMW1RFV8LJ019232`
  - `h3#4CARTRUCK_0_title` -> `2014 Toyota CAMRY 4T4BF1FK8ER414537`
  - `h3#5CARTRUCK_0_title` -> `Add Car or Truck`

### Start Quoting block at the end of Gather Data
- Auto checkbox:
  - `input#ConsumerReports.Auto.Product-intel#102`
- Rating state:
  - `select#ConsumerReports.Auto.RatingState`
- Final create quote button:
  - `button#consentModalTrigger`
- Add product link in quote block:
  - `a#quotesButton`
- Sidebar add product link also exists:
  - `a#addProduct`

### Start Quoting rule after vehicle confirmation
- Primary path:
  - validate the Start Quoting block on Rapport
  - ensure `Auto` is selected/checked
  - ensure `Rating State = FL`
  - click `Create Quotes & Order Reports`
  - wait for Consumer Reports / ASC product / Drivers and Vehicles / Incidents
- Fallback path:
  - use `/selectProduct` only if the Start Quoting block cannot be made valid
  - use `Add Product` only as the fallback entry to `/selectProduct`
- Validation note:
  - a successful `Auto` tile click on Product Overview is not enough by itself
  - the workflow must validate downstream on Rapport that the Start Quoting block actually has `Auto` committed before launching quote creation

### Gather Data rules confirmed by the user
- Fill email here so it does not need to be entered again later.
- Fill age first licensed here with `16`.
- Vehicle creation/editing belongs here, not on the later Drivers and Vehicles page.

## 3B. Customer Summary Overview Bridge

### Page
- URL pattern:
  - `/apps/customer-summary/{id}/overview`

### Scan-backed anchors
- visible action:
  - `START HERE (Pre-fill included)`
- supporting page text:
  - `Add Product`
  - `Quote History`
  - `Assets Details`

### Confirmed rule
- click `START HERE (Pre-fill included)`
- expected next state is the Product Overview Grid at `/apps/intel/102/overview`
- allowed skip-ahead states after the click:
  - `RAPPORT/GATHER_DATA`
  - `SELECT_PRODUCT`
  - `ASC_PRODUCT`
  - `INCIDENTS`

### Important notes
- this page may appear after creating a new prospect, selecting an existing prospect, or resuming a customer profile
- do not click `START HERE` if already on `/apps/intel/102/overview` or later quote states

## 4. Product Overview Grid

### Page
- URL pattern:
  - `https://advisorpro.allstate.com/#/apps/intel/102/overview`

### Scan-backed anchors
- page text:
  - `Select Product`
- product tile:
  - `Auto`
- primary button:
  - `Save & Continue to Gather Data`
- sidebar link also present:
  - `Add Product`

### Confirmed rule
- select `Auto`
- click `Save & Continue to Gather Data`
- wait for Gather Data / Rapport

### Important note
- this is different from the older `/selectProduct` form page
- do not treat this page as the old `SelectProduct.Product` select-form
- use text-based matching for the `Auto` tile and `Save & Continue to Gather Data`

## 4B. Select Product Form

### Page
- URL pattern:
  - `https://advisorpro.allstate.com/#/apps/intel/102/selectProduct`

### Known controls
- Rating state:
  - `select#SelectProduct.RatingState`
- Product:
  - `select#SelectProduct.Product`
- Current insured radios:
  - `input#SelectProduct.CustomerCurrentInsured`
- Own/rent radios:
  - `input#SelectProduct.CustomerOwnOrRent`
- Continue button:
  - `button#selectProductContinue`
- Current address selector also appeared in scan:
  - `select#SelectProduct.CurrentAddress`

### Confirmed defaults
- `SelectProduct.Product = AUTO`
- `SelectProduct.RatingState = FL`
- current insured = `YES`
- own/rent = `OWN`

## 5. Consumer Reports

### Page
- URL pattern seen in scan:
  - `https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/`
- Heading:
  - `order consumer reports`

### Known controls
- Consent yes:
  - `button#orderReportsConsent-yes-btn`

### Confirmed rule
- Always click `Yes`.

## 6. Drivers and Vehicles

### Page
- URL pattern seen in scan:
  - `https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/`
- Heading:
  - `Drivers and vehicles`

### Known driver action examples
- Add lead driver:
  - `button#amalia-garcia-add`
- Add spouse/other driver:
  - `button#dennis-rivera-addToQuote`
- Remove driver:
  - `button#dennis-rivera-remove`

### Known vehicle action examples
- Add matching vehicle:
  - `button#2021-nissan-sentra-add`
  - `button#2026-toyota-tacoma 2wd-add`
  - `button#2026-toyota-rav4-add`
- Remove vehicle buttons also exist, but user explicitly said they are not needed for normal workflow:
  - `button#2021-nissan-sentra-remove`
  - `button#2026-toyota-tacoma 2wd-remove`
  - `button#2026-toyota-rav4-remove`

### Continue button
- Save and continue:
  - `button#profile-summary-submitBtn`

### Confirmed workflow rules
- Always add the lead driver.
- Never leave a driver unresolved.
- Remove extra drivers only.
- Do not remove extra vehicles.
- Add only lead-matching vehicles to the quote and leave non-matching vehicles untouched.

## 7. Driver Details Modal

### Modal heading
- `Let's get some more details`

### Known controls
- Gender:
  - `input#gender_1002` -> `Male`
  - `input#gender_1001` -> `Female`
- Marital status:
  - `input#maritalStatusEntCd_0006` -> `Single`
  - `input#maritalStatusEntCd_0001` -> `Married`
  - `input#maritalStatusEntCd_0007` -> `Widowed`
- Spouse chooser:
  - `select#maritalStatusWithSpouse_spouseName`
- Own/rent home:
  - `select#propertyOwnershipEntCd_option`
- Age first licensed:
  - `input#ageFirstLicensed_ageFirstLicensed`
- Military:
  - `input#militaryInd_true`
  - `input#militaryInd_false`
- Moving violations:
  - `input#violationInd_true`
  - `input#violationInd_false`
- Defensive driving:
  - `input#defensiveDriverInd_true`
  - `input#defensiveDriverInd_false`
- Email:
  - `input#emailAddress.emailAddress`
- Phone:
  - `input#phoneNumber_phoneNumber`
- Save:
  - `button#PARTICIPANT_SAVE-btn`

### Confirmed defaults
- gender from lead
- military = `No`
- moving violations = `No`
- defensive driving = `No` when shown
- own/rent default = `Own a home`
- age first licensed = `16`

## 8. Spouse Modal

### Scan-backed behavior
- If `Married` is selected, a spouse flow can appear.
- One observed example showed:
  - heading `Dennis Rivera`
  - modal text `Add spouse`

### Known controls
- Name fields:
  - `input#fullName_givenName`
  - `input#fullName_middleName`
  - `input#fullName_surname`
  - `select#fullName_nameSuffix`
- Gender:
  - `input#gender_1002`
  - `input#gender_1001`
- Age first licensed:
  - `input#ageFirstLicensed_ageFirstLicensed`
- Moving violations:
  - `input#violationInd_true`
  - `input#violationInd_false`
- Defensive driving:
  - `input#defensiveDriverInd_true`
  - `input#defensiveDriverInd_false`
- Save:
  - `button#PARTICIPANT_SAVE-btn`

### Confirmed spouse rule
- Aggressive heuristic:
  - temporarily choose `Married`
  - if the spouse selector reveals exactly one spouse candidate, select that candidate
  - if the spouse modal appears:
    - default gender to opposite of the lead if blank
    - set age first licensed = `16`
    - set moving violations = `No`
    - set defensive driving = `No` only if the question exists
  - if no unique spouse candidate exists, revert to the original non-spouse path

## 9. Remove Driver Modal

### Example heading
- `Remove Driver Angel Test`

### Known reason controls
- `input#nonDriverReasonOthers_0008` -> duplicated or incorrect
- `input#nonDriverReasonOthers_0006` -> has their own car insurance
- `input#nonDriverReasonOthers_0012` -> does not have a license
- `input#nonDriverReasonOthers_0009` -> away on military duty
- `input#nonDriverReasonOthers_0010` -> deceased
- `input#nonDriverReasonOthers_0013` -> no longer lives with me
- `input#nonDriverReasonOthers_0014` -> I don't know this person
- `input#nonDriverReasonOthers_0011` -> I don't want to cover this driver

### Save controls
- Save:
  - `button#REMOVE_PARTICIPANT_SAVE-btn`
- Cancel:
  - `button#PARTICIPANT_CANCEL-btn`

### Confirmed remove rule
- When removing a driver, always choose:
  - `input#nonDriverReasonOthers_0006`
- User reason:
  - remove now, but add later if requested by the customer

## 10. Vehicle Add-to-Quote Modal

### Example heading
- `2021 Nissan Sentra`

### Known controls
- Ownership:
  - `input#vehicleOwnershipCd_0001` -> `Own`
  - `input#vehicleOwnershipCd_0003` -> `Lease`
  - `input#vehicleOwnershipCd_0007` -> `Finance`
- Garaging same as home:
  - `input#garagingAddressSameAsOther-control-item-0` -> `Yes`
  - `input#garagingAddressSameAsOther-control-item-1` -> `No`
- Purchased within 90 days:
  - `input#purchaseDate_true` -> `Yes`
  - `input#purchaseDate_false` -> `No`
- Save:
  - `button#ADD_ASSET_SAVE-btn`
- Cancel:
  - `button#ASSET_CANCEL-btn`

### Confirmed vehicle modal rules
- Always set garaging = `Yes`
- Always set recent purchase = `No`
- If vehicle year is greater than `2015`, set ownership = `Finance`
- If vehicle year is `2015` or older, leave ownership blank

## 11. Incidents

### Page
- URL seen in scan:
  - `https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/`
- Heading:
  - `Incidents`

### Known controls
- Continue:
  - `button#CONTINUE_OFFER-btn`
- Back:
  - `button#BACK_TO_PROFILE_SUMMARY-btn`

### Important note
- Incident checkbox ids are dynamic and should not be treated as stable selectors.
- Stable interaction anchor is the label text.

### Example labels from scan
- `Hit by a driver who left the scene of the accident`
- `Hit by a driver who did not have enough insurance to cover the damage to the vehicle`
- `Accident caused by being hit by animal or road debris`
- `None of these`

### Confirmed incident rule
- Always choose:
  - `Accident caused by being hit by animal or road debris`
- Then click:
  - `button#CONTINUE_OFFER-btn`

## 12. Workflow Defaults Confirmed by User

- Hotkey:
  - `Ctrl+Alt+-`
  - AHK binding:
    - `^!-::`
- Rating state:
  - `FL`
- Current insured:
  - `Yes`
- Own/rent:
  - `Own`
- Consumer reports:
  - `Yes`
- Age first licensed:
  - `16`
- Military:
  - `No`
- Moving violations:
  - `No`
- Defensive driving:
  - `No` only when the question appears
- Vehicle ownership in add-to-quote modal:
  - `Finance` for `year > 2015`
  - blank for `year <= 2015`
- Garaging:
  - `Yes`
- Purchased in last 90 days:
  - `No`
- Remove-driver reason:
  - `This driver has their own car insurance`
- Incident reason:
  - `Accident caused by being hit by animal or road debris`

## 13. Workflow Notes

- The environment is user-driven and page readiness can stall, so every page/action handler should have a timeout and a fallback path.
- Existing vehicles should be matched by normalized `year + make + model`, ignoring trim.
- Later Drivers and Vehicles logic should only add/remove already-listed entities and should not be used for creating new vehicles.
- The scan history proved that `selected: false` on raw option entries is not reliable; use the parent select's `value`, `selectedIndex`, and `selectedText`.

## 14. Known Gaps

- Exact selector retention for the New Prospect page was not preserved in this document.
- Exact selector retention for the Duplicate Prospect primary action button was not preserved in this document.
- Those stages should rely on:
  - the existing prospect fill path
  - scan-backed duplicate matching heuristics
  - runtime DOM discovery with timeouts/fallbacks
