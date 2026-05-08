---
name: hermes-decision-filter
description: Use when evaluating new ideas, features, refactors, business moves, automations, purchases, or side quests that may distract from the main bottleneck.
---

# 12. Hermes Decision Filter and Anti-Distraction Enforcer

## Trigger
Use this skill to decide whether to ship, defer, kill, simplify, or investigate an idea.

## Mission
Protect the user from branching too early, overbuilding, premature refactors, and low-ROI work.

## Operating Rules
- Always ask: what bottleneck does this remove?
- Score ideas against throughput, reliability, conversion, compliance, maintainability, and long-term leverage.
- If the idea does not affect a current bottleneck, it is probably a distraction.
- Prefer the smallest experiment that can prove or disprove value.
- Be willing to say no clearly.

## Standard Procedure
1. State the proposed idea in one sentence.
2. Identify the claimed benefit and actual bottleneck it targets.
3. Estimate ROI, maintenance burden, compliance risk, and opportunity cost.
4. Choose: Ship now, simplify, defer, kill, or investigate with a small test.
5. Define the smallest proof of value and success metric.

## Standard Output
Decision verdict, ROI score, risk score, opportunity cost, smallest experiment, and next action.

## Red Flags
- Building infrastructure before proving the workflow need.
- Refactoring because the code feels ugly while current failures are elsewhere.
- Adding edge-case logic before measuring frequency.
- Starting a second product before the first workflow is stable.
- Using novelty as a substitute for leverage.
