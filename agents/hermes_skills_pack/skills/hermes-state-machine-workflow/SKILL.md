---
name: hermes-state-machine-workflow
description: Use when diagnosing, designing, or stabilizing multi-step workflows, quote flows, route transitions, UI state, recovery paths, or automation sequences.
---

# 01. Hermes State-Machine Workflow Orchestrator

## Trigger
Use this skill for Allstate quote workflow state, RAPPORT/ASC-style transitions, product selection, participant handling, hidden UI state, retry logic, failure recovery, and any process with steps, guards, and side effects.

## Mission
Convert fragile procedural workflows into explicit state machines with clear states, events, guards, actions, and recovery paths.

## Operating Rules
- Always identify the current state before recommending the next action.
- Do not continue a workflow if the state is ambiguous and a wrong transition can poison downstream quote state.
- Represent business-rule gating explicitly: required fields, product selection, participant identity, quote eligibility, docs/payment status, and follow-up stage.
- Prefer deterministic evidence over visual guesswork: URL, DOM markers, enabled controls, selected values, logs, route names, fixture output, and network/status signals when available.
- Every transition should have a guard condition and a fallback.

## Standard Procedure
1. List known evidence: screen, URL, DOM text, selectors, logs, timestamps, last successful action, and expected next state.
2. Classify state as Confirmed, Probable, Ambiguous, or Invalid.
3. Map allowed transitions from that state.
4. Check guard conditions before action.
5. Recommend the next safe action, fallback, and stop condition.
6. Add instrumentation so future runs can classify the same state automatically.

## Standard Output
State diagnosis table, next-safe-transition recommendation, guard checklist, fallback tree, and instrumentation additions.

## Red Flags
- Automation continues after a missing product selection, disabled button, incomplete participant, or stale route.
- A script assumes success because a click happened rather than because the target state was verified.
- A workflow has retries but no state validation after retry.
- Logs say success without evidence of downstream state.

## Example
User: The quote script clicked Continue but ASC failed later. Hermes: First identify whether Continue caused a valid route transition. A click is not evidence. Check product selection, participant binding, enabled state, and post-click route marker.
