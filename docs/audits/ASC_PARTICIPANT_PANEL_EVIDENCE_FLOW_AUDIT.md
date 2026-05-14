# ASC Participant Panel Evidence Flow Audit

Date: 2026-05-14
Branch: `fix/asc-drivers-vehicles-ledger`

Scope: audit only. No runtime behavior, vehicle matching, RAPPORT, renters product logic, Playwright mutation, or purchase/bind/final-sale behavior was changed for this audit.

## Sources Inspected

- `assets/js/advisor_quote/src/operator.template.js`
- `assets/js/advisor_quote/ops_result.js` for generated-path confirmation only
- `workflows/advisor_quote_workflow.ahk`
- `workflows/advisor/advisor_quote_transport.ahk`
- `assets/js/advisor_quote/src/resident/command_bus.js`
- `tests/advisor_quote_ops_smoke.js`
- `tests/fixtures/advisor_quote_operator/sanitized_dom_scenarios.json`
- Latest local scan/trace files under `logs/` as inspection inputs only

Raw scan/log/customer data was not copied into this audit. The field values below are limited to workflow status and sanitized evidence-flow facts.

## Evidence Path Diagram

```text
scan_current_page
  -> readAscActiveParticipantPanelRoot()
  -> ascPanelRadioLikeControls(activePanelRoot)
  -> activeParticipantPanel.radioLikeControls
     Observed: rootStatus=ok; movingViolations label/Yes/No are cleanly scoped.

asc_drivers_vehicles_snapshot
  -> readAscDriversVehiclesSnapshotFields()
  -> readAscActiveParticipantPanelFields(collectAscDriverRows())
  -> readAscParticipantPanelReadiness(activePanelRoot)
     Observed: activeParticipantMovingViolationsQuestionPresent=1,
               selectedValue blank,
               activeParticipantDefensiveDrivingQuestionPresent=1 in the inspected run,
               panelReadyToSave=0.
     Also observed: activeParticipantRowKey blank,
                    activeParticipantRowStatus=UNKNOWN,
                    activeParticipantPanelKind=UNKNOWN,
                    activeParticipantPanelAction=FAIL_SAFE.

AdvisorQuoteBuildAscDriversVehiclesLedger()
  -> activePanelType=ASC_INLINE_PARTICIPANT_PANEL
  -> nextAction=handle_inline_participant_panel
  -> reason=ASC_ACTIVE_PARTICIPANT_PANEL_BLOCKS_ROW_PROGRESS

AdvisorQuoteHandleAscInlineParticipantPanelLedger()
  -> reads panelKind from snapshot/context
  -> contextPanelKind is empty because no clicked row/action context is present
  -> guard fires before readiness/defaulting:
     if panelKind UNKNOWN or activePanelAction FAIL_SAFE with no context -> fail safe

NOT REACHED in this live run:
  -> AdvisorQuoteEnsureActiveParticipantPanelReady()
  -> op asc_ensure_active_participant_panel_ready
  -> applyAscKnownParticipantDefaults()
  -> selectAscKnownParticipantQuestionNo()
  -> click movingViolations No
  -> readback selectedValue=NO
  -> asc_click_active_participant_save
  -> post-save panel closed check
```

## Line-Level Path References

- `scan_current_page` builds `activeParticipantPanel.radioLikeControls` from `readAscActiveParticipantPanelRoot()` and `ascPanelRadioLikeControls()` in `operator.template.js` around lines 9757 and 9858-9876.
- `asc_drivers_vehicles_snapshot` calls `readAscActiveParticipantPanelFields(collectAscDriverRows())` in `operator.template.js` around line 6142.
- `readAscActiveParticipantPanelFields()` calculates readiness and panel row/kind/action in `operator.template.js` around lines 5934-6040.
- `readAscParticipantPanelReadiness()` reads moving-violations and defensive-driving status in `operator.template.js` around lines 5884-5913.
- `asc_ensure_active_participant_panel_ready` would call `applyAscKnownParticipantDefaults()` only after panel kind passes the primary/non-driver check in `operator.template.js` around lines 9302-9378.
- `AdvisorQuoteHandleAscInlineParticipantPanelLedger()` fails safe before calling `AdvisorQuoteEnsureActiveParticipantPanelReady()` when panel kind and action context are unknown in `workflows/advisor_quote_workflow.ahk` around lines 2040-2071.
- Row/action context is set only from driver reconciliation results in `AdvisorQuoteSetAscPanelActionContextFromDriverResult()` around lines 542-559 and then passed into JS by `AdvisorQuoteAscPanelActionContextArgs()` around lines 597-606.

## Answers

### 1. Is questionContext still bleeding anywhere after the latest patch?

For the current moving-violations failure path, no moving-violations bleed was found. The latest scan evidence shows moving-violations context scoped to its own label/Yes/No controls.

The inspected latest scan did include a defensive-driving help-style button inside the defensive-driving block that inherited `questionContext=defensiveDriving`. That is not the moving-violations failure. It is also ignored by the click/default path because candidate selection filters to Yes/No answers.

### 2. Does scan_current_page see clean movingViolations controls but asc_participant_detail_status sees different evidence?

No latest `asc_participant_detail_status` call was observed for the failing active-panel path. The ledger skips participant detail status reads while an active modal/panel is already blocking the page, then routes directly to `handle_inline_participant_panel`.

Code inspection shows `asc_participant_detail_status` uses the same active panel root and readiness helpers, so it should see the same moving/defensive required-state evidence if invoked. The live failure happens before that op is called.

### 3. Does activeParticipantMovingViolationsQuestionPresent become 1 in the status op?

In `asc_drivers_vehicles_snapshot`, yes: `activeParticipantMovingViolationsQuestionPresent=1`, selected value blank, default applied `0`.

For `asc_participant_detail_status`, no current-run evidence exists because the op was not reached in the inspected failure path.

### 4. Does the readiness/action path choose ASC_PARTICIPANT_MOVING_VIOLATIONS_NO_SELECTED or fail before click?

It fails before click. The AHK panel handler fails safe before invoking `asc_ensure_active_participant_panel_ready`, so `ASC_PARTICIPANT_MOVING_VIOLATIONS_NO_SELECTED` is never produced in the inspected live path.

### 5. If it fails before click, what condition blocks it?

The blocking condition is panel identity, not question detection:

- `activeParticipantPanelKind=UNKNOWN`
- `activeParticipantRowStatus=UNKNOWN`
- `activeParticipantRowKey` blank
- no carried `clickedButtonId,rowKey,actionKind`
- `activeParticipantPanelAction=FAIL_SAFE`

`AdvisorQuoteHandleAscInlineParticipantPanelLedger()` treats this as unsafe and clears context before any defaulting/click action.

### 6. If it tries to click, what exact target does it click?

It does not try to click in this run.

If reached, `selectAscKnownParticipantQuestionNo()` would prefer the scoped question block, find exactly one No candidate, and click `noCandidates[0].target`.

### 7. Does the No label have an associated input/control, or is it only a label?

The latest scan shows `LABEL` nodes for the question, Yes, and No. The scan evidence does not expose a linked input id. Code inspection shows label handling attempts `for=`/descendant control lookup first, then can fall back to the label/clickable target if it remains strictly inside the scoped block.

### 8. Does the click target resolver reject the label because it cannot find a linked input?

No evidence of that in this failure. The click resolver was not reached. Code inspection suggests label-only controls are allowed as targets when scoped inside the question block; they are not automatically rejected only because no linked input is found.

### 9. Is the resident/tiny command path using stale generated operator code?

No direct stale-build result was observed in the latest failure. The resident health path reported OK and the snapshot fields show the newer active-panel fields, including moving/defensive question presence.

However, there is a structural stale-code risk: `AdvisorQuoteResidentOperatorBuildHash()` returns a constant string (`advisor-resident-operator-phase1-command-bus`) rather than a content hash of `ops_result.js`. A resident operator that was bootstrapped before a JS code change could pass the build-hash check unless it is explicitly replaced. This does not appear to be the first failure point in the inspected run, but it can make future evidence comparisons confusing.

### 10. Are scan/status/action using different helper functions for question blocks?

They share the same underlying panel root and question helpers in `operator.template.js`:

- scanner evidence: `ascPanelRadioLikeControls()`
- status/readiness: `readAscKnownQuestionState()` and `readAscParticipantPanelReadiness()`
- action/default: `applyAscKnownParticipantDefaults()` and `selectAscKnownParticipantQuestionNo()`

The divergence is not a different question parser in this run. The divergence is that the AHK path refuses to call the action/default op while panel kind is unknown and no row/action context exists.

## First Point Where Evidence Is Ignored

The first point where usable moving-violations evidence is ignored is `AdvisorQuoteHandleAscInlineParticipantPanelLedger()` in `workflows/advisor_quote_workflow.ahk`.

At that point, `asc_drivers_vehicles_snapshot` has already established:

- active participant panel present
- panel root ok
- moving-violations question present
- moving-violations selected value blank
- save enabled
- panel not ready because required fields are missing

But the handler fails safe because the active participant row/kind cannot be tied to a row:

- no snapshot `activeParticipantRowKey`
- no snapshot `activeParticipantPanelKind`
- no persisted row/action context

Therefore the No default click is never attempted.

## Likely Root Cause

The current failure is not the old moving-violations scanner bug. The question evidence is now available before the failure.

The root cause is active panel ownership/classification. The inspected snapshot shows one driver row already resolved as non-driver/removed and an active participant panel still open, but `readAscActiveParticipantPanelFields()` cannot map that open panel back to the row. Because the row/action context is only in memory and was not present for this active-panel attempt, the AHK fail-safe blocks before defaulting.

This can happen when the workflow resumes or retries with a participant panel already open, after the original row click context has been lost or was never set in this process.

## Minimal Patch Recommendation

Do not broaden question clicking. Keep the scoped question-block logic.

Minimal patch option:

1. In `readAscActiveParticipantPanelFields()`, add a narrow fallback for already-open panels:
   - If panel root is ok,
   - and known required participant questions are present,
   - and there is exactly one driver row that is `nonDriverResolved`/removed,
   - and there are no plausible unresolved/add rows,
   - and panel text does not identify a conflicting person,
   - then classify as `NON_DRIVER` and set `activeParticipantRowKey` from that row.

2. Keep the existing primary/add fallback for a single unresolved add row, but do not use it when a panel explicitly says unknown/other person.

3. Optionally add a trace field such as `activeParticipantRowKeyFallback=single-non-driver-row` so postconditions are auditable.

4. Consider changing the resident operator build hash from a fixed string to a generated/content hash, or force `replaceStale=1` on workflow start, so stale resident code cannot survive JS operator changes invisibly.

This should allow the existing path to reach `asc_ensure_active_participant_panel_ready`, select scoped moving-violations No, select defensive-driving No if present, read back `NO`, then save/close with the existing postcondition logic.

## Non-Findings

- No evidence that moving-violations question context is still bleeding to gender or marital controls in the current scan.
- No evidence that click target resolution is rejecting the No label in the current failure; click resolution is not reached.
- No evidence that readback is too strict in the current failure; readback is not reached.
- No evidence that vehicle matching, RAPPORT, renters product logic, Playwright mutation, or purchase/bind/final-sale paths are involved.
