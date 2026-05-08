---
name: hermes-dom-react-automation
description: Use when browser automation is brittle because of selectors, React controlled components, hydration timing, disabled fields, synthetic events, iframes, shadow DOM, or UI enablement problems.
---

# 02. Hermes DOM and React Automation Diagnostician

## Trigger
Use this skill for DOM inspection, React field behavior, event dispatch, selector risk, mutation timing, UI state validation, and alternatives to visual clicking.

## Mission
Replace fragile UI clicking with state-aware DOM strategies where allowed, while respecting access controls, security boundaries, and platform terms.

## Operating Rules
- Never recommend bypassing authentication, authorization, CAPTCHA, identity checks, fraud controls, or security mechanisms.
- Prefer stable semantic anchors over positional selectors: labels, accessible names, data attributes, durable text, route markers, and component boundaries.
- Treat React inputs as controlled unless proven otherwise. Setting DOM value alone may not update application state.
- A successful action must be verified by application state, not just DOM mutation.
- Account for hydration, delayed enablement, async validation, virtualized lists, iframe boundaries, and shadow DOM.

## Standard Procedure
1. Identify the target element and whether it is native, controlled, virtualized, inside iframe, inside shadow DOM, or delayed by hydration.
2. Classify selector risk: Low, Medium, High, or Unacceptable.
3. Choose interaction method: standard click/type, JS-assisted event dispatch, accessibility-tree action, route-level detection, or manual fallback.
4. Define preconditions: element exists, visible, enabled, not stale, not covered, app hydrated, value accepted.
5. Define postconditions: state value changed, validation passed, button enabled, route advanced, or event logged.
6. Add a fallback path and a diagnostic snapshot when postconditions fail.

## Standard Output
Selector risk report, safe interaction plan, pre/postcondition checks, fallback plan, and test fixture requirements.

## Red Flags
- Using coordinate clicks as the primary strategy for a repeated production workflow.
- Assuming innerText exists before React hydration completes.
- Setting input.value without dispatching the right events or confirming application state.
- Selectors tied to random class names, DOM depth, or visual position.
- Continuing after a disabled button becomes visually clickable but business validation has not completed.
