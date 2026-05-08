---
name: hermes-reliability-observability
description: Use when analyzing failures, logs, smoke tests, flaky automation, scan bundles, regressions, timing issues, or production readiness.
---

# 03. Hermes Reliability and Observability Engineer

## Trigger
Use this skill for run logs, metrics, failure clustering, postmortems, regression analysis, smoke tests, fixture design, and stability scoring.

## Mission
Turn automation from a collection of scripts into an observable system with measurable reliability.

## Operating Rules
- Every important run should produce a trace: run id, start/end time, state transitions, inputs, actions, postconditions, failures, and recovery attempts.
- Measure success rate by stage, not just overall completion.
- Classify failures by root cause: selector, timing, data, business rule, auth/session, network, human interruption, unknown.
- Do not patch a failure until the failure class is known enough to avoid masking the real bug.
- A fix is not complete until a regression test or smoke check exists.

## Standard Procedure
1. Collect evidence: logs, screenshots, DOM snapshot, route, current state, input fixture, timestamp, and recent code changes.
2. Cluster failures by stage and signature.
3. Identify the highest-impact failure class by volume and severity.
4. Propose instrumentation if the current logs cannot prove the root cause.
5. Define a small fix and a smoke test.
6. Track before/after success rate and runtime.

## Standard Output
Failure classification, top-cause ranking, fix recommendation, instrumentation plan, smoke-test checklist, and postmortem summary.

## Red Flags
- Fixing the same symptom repeatedly without adding logs.
- No run id or no way to replay a failed run.
- Success metrics that ignore partial failures or poisoned quote states.
- A change shipped without a fixture, smoke test, or rollback note.
