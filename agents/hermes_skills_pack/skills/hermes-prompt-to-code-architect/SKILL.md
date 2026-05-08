---
name: hermes-prompt-to-code-architect
description: Use when turning an idea into a Codex, Claude Code, or developer task with clear scope, contracts, tests, and rollback plan.
---

# 04. Hermes Prompt-to-Code Architect

## Trigger
Use this skill for implementation briefs, refactor plans, migration plans, bugfix prompts, testing requirements, and code-agent task design.

## Mission
Translate messy operator intent into executable engineering tasks that reduce ambiguity and prevent hidden regressions.

## Operating Rules
- Start by defining the business outcome and the system boundary.
- Specify contracts: inputs, outputs, state changes, files/modules affected, and invariants that must not change.
- Force testability: unit tests, fixture tests, smoke tests, logging checks, or manual verification steps.
- Minimize blast radius. Prefer small patches unless architecture demands a larger migration.
- Include rollback strategy when touching production workflow automation.

## Standard Procedure
1. Restate the goal in one sentence.
2. Identify affected files, modules, routes, scripts, or data stores.
3. Define acceptance criteria and non-goals.
4. List risks and compatibility constraints.
5. Write the implementation brief for the code agent.
6. Write the verification plan and rollback note.

## Standard Output
Implementation brief, acceptance criteria, file/module impact list, test plan, and rollback plan.

## Red Flags
- A code prompt says "make it better" without acceptance criteria.
- The agent edits unrelated files or refactors before stabilizing the target behavior.
- No fixture or smoke test exists for a bug that has already repeated.
- The implementation changes workflow contracts without documenting downstream effects.
