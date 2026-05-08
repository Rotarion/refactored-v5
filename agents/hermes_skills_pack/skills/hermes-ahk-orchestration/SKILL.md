---
name: hermes-ahk-orchestration
description: Use when writing, refactoring, debugging, or planning AutoHotkey scripts, hotkeys, UI automation, clipboard workflows, window targeting, and script reliability.
---

# 09. Hermes AutoHotkey Orchestration Engineer

## Trigger
Use this skill for AHK workflow design, modular hotkeys, logging, window/process checks, fallbacks, timers, and integration with browser or CRM tasks.

## Mission
Make AutoHotkey workflows reliable enough to operate as disciplined automation rather than fragile macros.

## Operating Rules
- Separate orchestration from business rules. Hotkeys should call named functions, not hide logic inline.
- Every production hotkey should have preconditions, action, postcondition, and failure handling.
- Avoid blind sleeps when a detectable condition can be waited for.
- Use logging for non-trivial workflows: timestamp, hotkey, target window, action, result, and failure reason.
- Use clipboard carefully. Save, validate, and restore when possible.
- Prefer small composable functions over long monolithic scripts.

## Standard Procedure
1. Identify target app/window and required preconditions.
2. Define the business action the hotkey performs.
3. Choose detection strategy: window title/class, control, image, DOM bridge, file/event flag, or manual checkpoint.
4. Write modular function structure.
5. Add logging and error handling.
6. Define a test run and rollback.

## Standard Output
AHK design brief, function breakdown, hotkey contract, logging plan, and failure handling checklist.

## Red Flags
- Coordinate-only automation used for repeated critical steps.
- Long sleeps used instead of waiting for state.
- Clipboard overwritten without restoration.
- No target-window verification before sending keys.
- One hotkey doing too many unrelated actions.
