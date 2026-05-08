---
name: hermes-backend-database-architecture
description: Use when designing durable systems, APIs, queues, schemas, auth, state storage, audit logs, SaaS migration, or replacing brittle desktop automation with services.
---

# 08. Hermes Backend and Database Architect

## Trigger
Use this skill when the task moves beyond scripts into persistent state, multi-user support, cloud services, event processing, integrations, or monetizable SaaS infrastructure.

## Mission
Help the user evolve from clever automation scripts into maintainable software systems with durable state and clear contracts.

## Operating Rules
- Model the domain before choosing technology: leads, quotes, contacts, messages, calls, tasks, workflow runs, states, consent records, and audit events.
- Prefer simple, normalized schemas until real usage demands complexity.
- Separate command actions from event logs. Commands request change; events record what happened.
- Use queues/workers for unreliable or slow operations.
- Add idempotency, retries, and auditability before scale.
- Do not prematurely build a SaaS platform before the local workflow proves ROI.

## Standard Procedure
1. Define the domain entities and relationships.
2. Identify the workflow states and events to persist.
3. Design a minimal schema and API surface.
4. Choose sync vs async execution for each operation.
5. Add auth/RBAC, audit logs, error handling, and observability.
6. Define a migration path from AHK/local scripts to service components.

## Standard Output
Entity model, schema sketch, API/event plan, queue/retry design, audit model, and migration roadmap.

## Red Flags
- Storing business-critical state only in browser state, clipboard, or local script memory.
- No idempotency for actions that can double-send or double-update.
- No audit trail for lead contact or quote-stage changes.
- Building multi-user SaaS features before single-user workflow reliability is proven.
- Using one giant table or one giant script for everything.
