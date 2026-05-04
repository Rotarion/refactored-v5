# Advisor ASC/ASCPRODUCT Reconciliation Patch Notes

## Scope

This patch makes ASCPRODUCT Drivers and Vehicles reconciliation state-driven:

1. detect dynamic `/apps/ASCPRODUCT/<id>/`
2. act on scoped participant, driver, or vehicle rows
3. re-read committed state
4. continue only when save readiness is proven

It does not change Product Tile Grid, Address Verification, duplicate prospect handling, Gather Data vehicle add behavior, ASC/109 coverage selection, hotkeys, CRM/Blitz, or JS return transport.

## Participant and Spouse

Lead marital status is the source of truth.

- `Single`: set/confirm Single and skip the spouse dropdown even if it is visible.
- `Married`: select spouse by exact lead spouse name first.
- If no spouse name is available, select only one unique spouse candidate within the age-window rule.
- Ambiguous spouse candidates and no-safe-spouse cases fail safely.

The participant modal filler also receives lead marital status; a Single lead does not trigger the old unique-spouse fallback while a modal is open.

## Drivers

The old ASCPRODUCT rule that kept a second driver when exactly two driver rows existed is no longer used in the Drivers and Vehicles handler.

Driver reconciliation:

- add the primary applicant row when needed
- add a selected spouse only for true Married cases
- remove unrelated public-record drivers for Single leads unless they match expected lead driver data
- act one scoped row at a time
- re-run modal handling and re-read state before the next action

## Vehicles

Vehicle classification for ASCPRODUCT is separate from 102 Gather Data:

- complete: year + recognized make + non-empty model text
- partial year/make: year + recognized make + no model text
- deferred: insufficient evidence for automatic action

Complete vehicles require exact year, catalog-aware make labels, and strict normalized model. Partial year/make vehicles are promoted only from unique, scoped live Advisor evidence with:

- exact year
- make-family match
- visible model text
- VIN or masked VIN evidence
- exactly one matching row

The workflow does not select a first model from a broad model dropdown.

## Save Gate

Save and Continue is clicked only after:

- participant detail status is readable
- driver rows are resolved
- at least one expected or safely promoted vehicle is added/confirmed
- vehicle rows are resolved
- `profile-summary-submitBtn` is present and enabled

If the button remains disabled, the workflow logs unresolved driver/vehicle counts and fails with `ASC109_SAVE_DISABLED_AFTER_RECONCILIATION`.

## Consumer Reports Route Forwarding

`/apps/ASCPRODUCT/<dynamicId>/` is treated as a route family, not as a completed state. When the workflow is in `CONSUMER_REPORTS`, it now checks ASCPRODUCT route evidence before waiting for the simple Consumer Reports consent page.

- If the browser is already on ASCPRODUCT Drivers and Vehicles, the workflow skips the `consumer_reports_ready` wait and invokes the existing Drivers/Vehicles reconciliation handler.
- If the simple Consumer Reports consent page is present, the existing consent yes-button flow is still used.
- Incidents and quote landing substates are accepted only with their existing page evidence.
- Unknown ASCPRODUCT substates fail with diagnostics instead of being treated as success.

This is a routing/wait-argument patch only. It does not add broad yes/no radio defaults, spouse selection rules, or new driver/vehicle reconciliation behavior.

## Parser Fix

The AHK v2 RegExMatch capture-count crash path was kept on the safe `m.Count` pattern. Split model forms now canonicalize for strict matching:

- `Ford F 250`, `Ford F-250`, `Ford F250` -> `F250`
- `Honda CR-V` -> `CRV`
- safe split forms such as `CX 30`, `QX 56`, `GLE 350`, and `4 Runner` are normalized without broad fuzzy matching.
