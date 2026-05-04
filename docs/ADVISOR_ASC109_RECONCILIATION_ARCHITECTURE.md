# Advisor ASC/ASCPRODUCT Reconciliation Architecture

## 1. Executive summary

The current architecture should be treated as two separate stages:

- `102 Gather Data`: minimum safe product and vehicle setup. It should only resolve vehicles that are safe from lead data alone: exact year, make, and model.
- `ASCPRODUCT`: full downstream reconciliation. This is where Advisor Pro public-record evidence, VIN-bearing candidates, household/driver review, participant details, vehicle modals, incidents, and insurance-history branches belong.

The source now mostly respects this separation in `AdvisorQuoteHandleGatherData()` (`workflows/advisor_quote_workflow.ahk:1159`) and the documented 102 policy. However, downstream ASCPRODUCT logic still mixes responsibilities because `AdvisorQuoteResolveVehicles()` (`workflows/advisor_quote_workflow.ahk:2642`) reads `profile["vehicles"]` directly instead of a durable staged vehicle plan. Deferred 102 vehicles are logged, but not carried forward as first-class ASCPRODUCT reconciliation objects.

Operational risk is still high downstream. ASCPRODUCT currently has page detectors and action handlers, but no route-family status object, no durable reconciliation plan, no iframe inventory, no explicit insurance-history model, and only heuristic driver/spouse handling.

Implementation update: the Drivers and Vehicles stage now has a bounded ASCPRODUCT reconciliation path. It detects `/apps/ASCPRODUCT/<dynamicId>/`, reads participant detail status, resolves marital/spouse from lead truth, reconciles driver rows, reconciles complete and partial vehicle rows, then clicks Save and Continue only after re-reading committed state. The numeric route id is logged as evidence only and is not a condition.

## 2. Current 102 contract

Current 102 Gather Data vehicle contract:

- `actionableVehicles`: lead vehicle has year, make, and model.
- `ignoredMissingYearVehicles`: make/model present, year missing, no VIN/VIN suffix, and at least one actionable vehicle exists.
- `deferredVinVehicles`: VIN/VIN suffix exists but year/make/model are incomplete.
- `blockingMissingVehicleData`: insufficient data and no actionable vehicle exists.
- Confirmed vehicle cards are primary success evidence.
- Potential vehicles are not success.
- Unexpected confirmed vehicles fail safely.
- Final reconciliation passes structured `expectedVehicles` objects, not the old pipe-delimited string.
- The vehicle loop preflights already confirmed expected vehicles and skips confirm/add attempts for them.

Source/document anchors:

- Policy and loop: `AdvisorQuoteHandleGatherData()` in `workflows/advisor_quote_workflow.ahk:1176-1280`.
- Policy helpers: `AdvisorQuoteClassifyGatherVehicles()` and `AdvisorQuoteLogGatherVehiclePolicy()` around `workflows/advisor_quote_workflow.ahk:1647-1706`.
- Structured final expected list: `AdvisorQuoteBuildExpectedVehiclesArgList()` at `workflows/advisor_quote_workflow.ahk:1752`.
- Notes: `docs/ADVISOR_GATHER_DATA_VEHICLE_ADD_NOTES.md`, especially Gather Data Lead Vehicle Policy, Vehicle Loop Idempotency, and Final Confirmed-Vehicle Reconciliation.

Deferred vehicle information is currently only logged within 102 workflow state. It is not persisted as a durable plan object for ASCPRODUCT. That is the next architectural gap.

## 3. Cross-stage data model proposal

Introduce a durable internal plan object for every lead vehicle:

```text
LeadVehiclePlan
- originalText
- normalizedText
- year
- make
- model
- trimHint
- vin
- vinSuffix
- source
- stage102Status
  - actionable102
  - confirmed102
  - ignored102MissingYear
  - deferred102Vin
  - blocking102
- stageAscStatus
  - pendingAsc
  - matchedPublicRecordAsc
  - addedAsc
  - removedAsc
  - manualReviewAsc
  - notApplicable
- confidence
- reason
- evidence
```

Recommended ownership:

- Business ownership should live in AHK/domain code, not JS. AHK owns the workflow and can carry the plan across states.
- Add a new domain helper file or domain helper section for plan creation. `advisor_quote_db.ahk` already contains vehicle normalization helpers, but it is becoming crowded.
- JS should remain responsible for DOM evidence and scoped actions only: list visible candidates, return key=value diagnostics, and click a specific approved target.
- Workflow AHK should decide whether a candidate is actionable, ignored, deferred, manual, or unexpected.

## 4. ASCPRODUCT route-family taxonomy

Treat all ASC routes as:

```text
/apps/ASCPRODUCT/<dynamicId>/
```

Never classify by fixed numeric id. Sub-state must come from visible text, fields, and buttons.

| Sub-state | URL pattern | Evidence | Current handler | Risk | Scan evidence |
|---|---|---|---|---|---|
| Consumer Reports / participant details | `/apps/ASCPRODUCT/<dynamicId>/` | order consumer reports text, consent yes id, or participant fields such as `propertyOwnershipEntCd_option`, `ageFirstLicensed_ageFirstLicensed`, `emailAddress.emailAddress`, `PARTICIPANT_SAVE-btn` | `AdvisorQuoteStateConsumerReports()` at `workflows/...:540`; JS `isConsumerReportsPage()` at `operator.template.js:168`; modal handling via `fill_participant_modal` | high | Recent `/ASCPRODUCT/110/` scan exposed participant fields directly to scanner. |
| Drivers and Vehicles | same family | "Drivers and vehicles" plus `profile-summary-submitBtn` or add/remove buttons | `AdvisorQuoteStateDriversVehicles()` at `workflows/...:553`; `AdvisorQuoteHandleDriversVehicles()` at `:2546`; JS `isDriversAndVehiclesPage()` at `operator.template.js:178` | high | Existing scans show household members, properties, vehicles, potential vehicles, and Start/continue controls. |
| Driver/Participant modal or inline panel | same family or modal overlay | `PARTICIPANT_SAVE-btn`, participant fields, marital/spouse controls | `AdvisorQuoteHandleOpenModals()` at `:2693`; `AdvisorQuoteFillParticipantModal()` at `:2807`; JS op at `operator.template.js:2558` | high | Recent scan shows participant fields were visible without proven iframe blocker. |
| Vehicle modal | same family or modal overlay | `ADD_ASSET_SAVE-btn`, garaging/purchase/ownership controls | `AdvisorQuoteFillVehicleModal()` at `workflows/...:2859`; JS op at `operator.template.js:2682` | high | Needs dedicated scans after add/confirm vehicle actions. |
| Remove-driver modal | same family or modal overlay | `REMOVE_PARTICIPANT_SAVE-btn`, remove reason radio | `AdvisorQuoteSelectRemoveReason()` at `workflows/...:2854`; JS op at `operator.template.js:2676` | high | Remove reason modal scan still needed. |
| Prior-insurance branch | same family | prior/current provider, continuous coverage, share prior details, Continue | no dedicated handler found | high | Source search found no dedicated prior-insurance branch handler. |
| No-prior / insurance-history branch | same family | current provider, coverage length, BI limits, expiration/start dates | no dedicated handler found | high | Needs scan. |
| Incidents | same family | Incidents heading plus `CONTINUE_OFFER-btn` or animal/road-debris text | `AdvisorQuoteStateIncidents()` at `workflows/...:566`; JS `isIncidentsPage()` at `operator.template.js:185`; `handle_incidents` at `operator.template.js:2718` | medium-high | Existing fixture coverage, live scan target still useful. |
| Quote landing | same family | coverages, personalized quote, quote details, your quote | `AdvisorQuoteStateQuoteLanding()` at `workflows/...:575`; JS `isQuoteLandingPage()` at `operator.template.js:202` | medium | Wait can detect it; `detect_state` returns `ASC_PRODUCT` family rather than a dedicated `QUOTE_LANDING`. |

Recent `/ASCPRODUCT/110/` scan assessment: current scanner saw top-level participant fields `propertyOwnershipEntCd_option`, `ageFirstLicensed_ageFirstLicensed`, `emailAddress.emailAddress`, and button `PARTICIPANT_SAVE-btn`. That makes iframe an unproven blocker for that participant screen.

## 5. Iframe and embedded-context diagnostic assessment

Current `scan_current_page` behavior is in `assets/js/advisor_quote/src/operator.template.js:2759`.

Answers:

- Does it report iframe inventory? No.
- Does it scan accessible iframes? No. It queries the current `document` only.
- Does it report iframe id/name/src/title? No.
- Does it report whether iframes are same-origin accessible? No.
- Does it count fields/buttons inside accessible iframes? No.
- Is iframe currently proven as a blocker? No. The recent ASCPRODUCT participant scan exposed the relevant fields to the current scanner.

Future diagnostic-only enhancement:

- `iframeCount`
- each iframe `id`, `name`, `src`, `title`
- same-origin accessibility flag
- accessible iframe field/button/radio counts
- optional capped, sanitized body sample for accessible iframes
- no workflow behavior changes

This should be a scanner diagnostics patch, not a routing or action patch.

## 6. Deferred vehicle handling in ASCPRODUCT

Toyota Prius Prime with no year:

- Do not add in 102.
- Do not infer a year in 102.
- In ASCPRODUCT, it may become a candidate only if Advisor Pro presents strong public-record evidence.

Confidence levels:

- `high`: exact normalized make/model `TOYOTA PRIUS PRIME`, public-record year present, and VIN or VIN suffix present.
- `medium`: exact make/model, exactly one public-record candidate, year present, no VIN.
- `low`: partial/contains model match only.
- `reject`: missing year and no public-record support, different model, generic Prius used for Prius Prime, multiple candidates, or weak evidence.

Safe auto-add recommendation:

- Auto-add only `high`.
- Consider `medium` only after a separate live-evidence patch and fixture coverage.
- Fail/manual for `low` and `reject`.

If public record supplies year/VIN, use it as ASCPRODUCT evidence only. Do not rewrite the original lead text.

## 7. ASCPRODUCT vehicle action model

Future sequence:

1. List visible public-record vehicle candidates by single-card scope.
2. Compare against confirmed 102 vehicles.
3. Compare against deferred ASCPRODUCT vehicle plans.
4. Flag unexpected public-record extras.
5. Add only allowed high-confidence matches.
6. Remove or ignore unrelated vehicles only under an explicit future rule.
7. Save/continue only when required vehicle decisions are resolved.

Rules:

- Do not auto-remove confirmed 102 vehicles.
- Do not add unrelated public-record vehicles.
- Do not add deferred missing-year vehicles unless the confidence rule passes.
- Do not leave required public-record prompts unresolved if Advisor blocks continue.
- Do not use broad containers.
- Use single-card scoped confirm/remove logic only.

Implementation update: `AdvisorQuoteHandleDriversVehicles()` now calls `asc_vehicle_rows_status` and `asc_reconcile_vehicle_rows` instead of the old direct `AdvisorQuoteResolveVehicles()` path for ASCPRODUCT Drivers and Vehicles. Complete vehicles are passed as structured expected vehicles with catalog-aware make labels and strict model matching. Partial year/make vehicles are passed separately and may be promoted only from a unique VIN-bearing live row with visible model text.

## 8. Driver/spouse action model

Future driver rules:

- Add primary insured.
- Remove household members/drivers not in the quote unless spouse rule applies.
- If another adult appears within spouse-age range, max 14 years difference, evaluate spouse candidate only when page evidence supports spouse/household relationship.
- If spouse candidate is selected, set primary marital status to Married where required and select spouse in the spouse dropdown if the UI requires it.
- Remove other unrelated household members/drivers.
- Do not infer spouse if multiple candidates or weak evidence.
- Do not silently keep extra drivers.

Current source:

- `AdvisorQuoteResolveDrivers()` at `workflows/advisor_quote_workflow.ahk:2572`.
- `AdvisorQuoteListDriverSlugs()` at `:2607` calls JS `list_driver_slugs` at `operator.template.js:2481`.
- `AdvisorQuoteDriverIsAlreadyAdded()` at `:2629` calls JS `driver_is_already_added` at `operator.template.js:2495`.
- `AdvisorQuoteFillParticipantModal()` at `:2807` calls JS `fill_participant_modal` at `operator.template.js:2558`.
- `AdvisorQuoteSelectRemoveReason()` at `:2854` calls JS `select_remove_reason` at `operator.template.js:2676`.

Implementation update: the old "keep a second driver when there are two rows" heuristic is no longer used by the ASCPRODUCT Drivers and Vehicles handler. Lead `Single` keeps/sets Single and skips the spouse dropdown. Lead `Married` selects a spouse only by exact lead spouse name or by one unique candidate within the configured age window; ambiguous/no-safe-spouse cases fail safely. Driver add/remove acts one scoped row at a time and AHK re-reads state after modal handling.

## 9. Participant detail defaults

Current/future defaults:

- Age first licensed = 16 unless valid existing value or explicit rule applies.
- Property ownership = Own / Own a home by current business default, with rent mapping for apartment classification.
- Military/deployed = No.
- Past five years / violations = No.
- Defensive driver = No if visible.
- Missing age-gated fields = SKIP, not failure.
- For 55+ drivers, senior/defensive-driver-style questions may appear and should be answered only if visible.

Current source:

- AHK assembles args in `AdvisorQuoteFillParticipantModal()` at `workflows/...:2807`.
- Defaults live in `domain/advisor_quote_db.ahk:31-49`.
- JS sets age, email, military, violations, defensive driving, property ownership, gender fallback, and unique spouse selection in `fill_participant_modal` at `operator.template.js:2558`.

Gaps:

- No route-family status op distinguishes participant-details inline screen from modal.
- Defensive-driver skip exists for missing radio, but senior-specific question inventory is not explicit.
- Spouse selection uses a unique spouse dropdown option, not a full spouse evidence model.

## 10. Vehicle modal defaults

Rules:

- Vehicle year 2016+ = financed.
- Older than 2016 = owned.
- Parked at home = Yes.
- Purchased in last 90 days = No.
- Save only after required fields verify.
- Do not guess if vehicle year is unknown.

Current source:

- AHK `AdvisorQuoteFillVehicleModal()` at `workflows/...:2859`.
- JS `fill_vehicle_modal` at `operator.template.js:2682`.
- Threshold is `vehicleFinanceYearThreshold = 2015` in `domain/advisor_quote_db.ahk:49`, and JS uses `year > threshold` to choose financed.

Gaps:

- Year is detected from body text, not a specific vehicle plan.
- Unknown year causes ownership to be skipped rather than explicitly manual-reviewed.
- No durable evidence binding a modal to a specific deferred ASCPRODUCT vehicle.

## 11. Insurance-history architecture

No dedicated insurance-history branch handler was found in current AHK/JS source.

Prior-not-enough branch design:

- Share prior details = Yes.
- Previous provider = Other.
- Continuous coverage = 3+ years.
- Continue.

No-prior branch design:

- Current provider = Other if required.
- Length of coverage: no current rule found; recommend a conservative explicit business default before implementation.
- BI limits = I do not know.
- Policy expiration date = December 31 of the current year.
- New policy start date = existing quote date/start date rule.
- Proof of prior remains manual/client follow-up.

Needed before implementation:

- scans for both prior-not-enough and no-prior/no-insurance paths
- field ids, labels, button ids, disabled/required states
- evidence for date fields and whether they are native inputs or masked controls

## 12. Proposed patch phases

| Phase | Goal | Likely files | JS changes? | AHK changes? | Tests | Scans | Risk |
|---|---|---|---|---|---|---|---|
| ASC-0 | Carry `LeadVehiclePlan` / deferred vehicle plan from 102 into run/log state only | workflow or new domain helper, docs | no | yes | AHK helper tests | no new live scan required | low-medium |
| ASC-1 | ASCPRODUCT route-family classifier/status op; optional iframe inventory diagnostics | `operator.template.js`, `ops_result.js` via build, smoke fixtures, docs | yes | maybe | JS smoke route fixtures | ASCPRODUCT participant/drivers/incidents scans | medium-high |
| ASC-2 | Participant/consumer report detail defaults, visible yes/no questions | JS op + AHK handler + fixtures | yes | yes | JS smoke + AHK toolchain | participant details with senior questions | medium |
| ASC-3 | Driver primary/spouse/remove handling | workflow + JS driver status ops + docs | yes | yes | spouse/extra-driver fixtures | driver list and remove modal | high |
| ASC-4 | ASCPRODUCT public-record vehicle reconciliation using deferred plan | workflow + JS vehicle candidate/status ops | yes | yes | vehicle public-record fixtures | Prius Prime/public-record candidate scan | high |
| ASC-5 | Vehicle modal defaults bound to vehicle plan | JS modal op + AHK plan handoff | yes | yes | vehicle modal fixtures | vehicle modal scan | medium-high |
| ASC-6 | Prior/no-prior insurance-history branches | new status/action ops + AHK branch handler | yes | yes | branch fixtures | both insurance-history branch scans | high |
| ASC-7 | Incidents and quote landing hardening | workflow + JS status ops if needed | maybe | yes | incidents/landing fixtures | quote landing scan | medium |

## 13. Exact recommended next patch

Recommended next patch: ASC-0, carry a `LeadVehiclePlan` / deferred vehicle plan from 102 into ASCPRODUCT logs/run state only.

Why:

- It is the smallest patch that preserves the newly clean 102 contract.
- It avoids guessing on ASCPRODUCT public-record vehicles.
- It creates a stable object for later ASC-3/ASC-4 patches.
- It should not require JS changes.
- It will make logs explicit: confirmed 102 vehicles, deferred missing-year vehicles, deferred VIN vehicles, and manual/blocking vehicles.

After ASC-0, ASC-1 route-family classifier/status op is the next best implementation step.

## 14. Scans still needed

Needed before implementation beyond ASC-0:

- ASCPRODUCT public-record vehicle screen with a Prius Prime candidate visible, including whether year/VIN are visible in the same single card.
- Driver list with a possible spouse candidate visible and any relationship/marital controls visible.
- Remove-driver reason modal for a non-spouse household member.
- Vehicle modal after adding or confirming an ASCPRODUCT public-record vehicle.
- Prior-not-enough insurance-history branch.
- No-prior/no-insurance branch.
- Incidents page and quote landing page after the downstream flow.
- Any ASCPRODUCT page where current scanner misses visible controls; only then prioritize iframe diagnostics as a blocker fix.
