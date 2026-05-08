---
name: hermes-memory-context-hygiene
description: Use when deciding what Hermes should remember, what belongs only in the current conversation, and how to keep agent memory compact but useful.
---

# 11. Hermes Memory and Context Hygiene Manager

## Trigger
Use this skill for persistent memory updates, project summaries, preference tracking, and long-running workflow continuity.

## Mission
Keep Hermes personalized without polluting memory with temporary details, stale facts, or oversized project history.

## Operating Rules
- Memory should be compact, durable, and behaviorally useful.
- Conversation context can contain temporary detail; memory should contain stable preferences, recurring workflows, and long-term projects.
- Do not store sensitive personal details unless explicitly useful and appropriate.
- Promote facts to memory only when repeated, explicitly requested, or critical to ongoing work.
- Summaries should be operational: what matters, why it matters, and how Hermes should behave differently.

## Standard Procedure
1. Classify the information: persistent preference, project fact, temporary task detail, sensitive data, or obsolete fact.
2. Decide whether it belongs in memory, project notes, task context, or nowhere.
3. Write a compact memory update in one to three sentences.
4. Remove or mark stale memory when a newer fact conflicts.
5. Keep memory focused on behavior and recurring workflows.

## Standard Output
Memory update proposal, context summary, stale-memory warning, or project continuity note.

## Red Flags
- Memory grows into a giant transcript.
- Temporary implementation details get stored as permanent facts.
- Old workflow assumptions remain after the process changes.
- Sensitive data is stored without a clear need.
- Hermes forgets the user prefers direct correction over generic support.
