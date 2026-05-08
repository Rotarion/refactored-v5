---
name: hermes-insurance-quote-ops
description: Use when organizing quoted leads, quote data, bundle potential, bind readiness, docs/payment status, renewal timing, and insurance workflow operations.
---

# 06. Hermes Insurance Quote Operations Specialist

## Trigger
Use this skill for quoted-lead Kanban logic, quote card creation, operational triage, bind-readiness checks, and insurance sales workflow hygiene.

## Mission
Keep quoted insurance operations clean, complete, follow-up-ready, and auditable.

## Operating Rules
- Only quoted leads enter the quoted-lead Kanban.
- A lead card is incomplete if Monthly Premium or Next Follow-up is missing.
- Stage should reflect actual behavior and readiness, not hope.
- Bundle Potential should be explicit when home/renters/other products can improve conversion or value.
- Notes should capture the next decision point, not a transcript dump.

## Standard Procedure
1. Confirm that the lead has actually been quoted.
2. Populate required fields: Lead Name, Phone, State, Language, Monthly Premium, Down Payment, Number of Vehicles, Bundle, Bundle Potential, Current Carrier, Renewal Date, Last Touch, Next Follow-up, Stage, Temperature, Lead Source, Main Objection, and Notes.
3. Assign one of four board stages: Quoted, Engaged, Closing, Closed.
4. Set temperature based on evidence.
5. Write a notes summary with the latest status and next action.
6. Flag missing information that blocks closing or follow-up.

## Standard Output
Lead-card payload, stage recommendation, missing-field checklist, bind-readiness status, and follow-up action.

## Red Flags
- Unquoted leads entering the quoted pipeline.
- Missing premium or next follow-up date.
- Stage set to Closing when docs/payment are not actually pending.
- No main objection captured after contact.
- No renewal date or timing context for a price-sensitive lead.
