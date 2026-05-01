# Blitz Page Status Contract

## Purpose

`blitz_page_status` is a read-only CRM/Blitz DevTools operator used to diagnose the current Blitz page shape before any workflow mutates the page.

It exists because a live manual scan showed a mixed page:

- top document: Blitz lead list
- accessible iframe: open Blitz lead log with actionable CRM controls

The status op preserves both facts instead of collapsing the page to only `lead-list`.

## Runtime Location

- JS operator: `assets/js/devtools_bridge/ops_result.js`
- AHK wrapper: `JS_GetBlitzPageStatus()` in `adapters/devtools_bridge.ahk`
- Op name: `blitz_page_status`
- Return transport: existing DevTools `copy(String(...))` bridge

`Ctrl+Alt+K` calls this op before mutating the current lead. `Ctrl+Alt+H` calls it before batch replay and before each lead mutation.

## Read-Only Guarantee

`blitz_page_status` must not:

- click
- focus
- type
- select dropdown values
- save history
- add appointments
- move to the next lead
- mutate fields

It only reads top-level and accessible iframe DOM state, then returns key=value diagnostics.

## Return Format

The op returns key=value lines.

Required top-level fields:

```text
result=READY|NOT_READY|WRONG_PAGE|UNKNOWN|ERROR
page=lead-list|lead-log|lead-list-with-open-lead-log|appointment-frame|unknown
topPage=lead-list|lead-log|unknown
actionPage=lead-log|appointment-frame|none
url=
title=
frameCount=
accessibleFrameCount=
actionFramePath=
actionFrameUrl=
actionFrameTitle=
evidence=
missing=
error=
```

Required capability fields:

```text
hasLeadListLinks=1|0
leadListLinkCount=
hasCurrentLeadTitle=1|0
currentLeadTitle=
hasNextLead=1|0
hasActionDropdown=1|0
hasHistorySave=1|0
hasAddAppointment=1|0
hasAppointmentDate=1|0
hasAppointmentSave=1|0
hasPhone=1|0
hasMobileOrIPhone=1|0
hasStatus=1|0
hasSaveButton=1|0
```

## Result Values

- `READY`: the detected page/action context has the required controls for that context.
- `NOT_READY`: Blitz page evidence exists, but required controls for the selected context are missing.
- `WRONG_PAGE`: no Blitz page evidence was found.
- `UNKNOWN`: some Blitz-like context may exist, but it could not be classified as a supported page.
- `ERROR`: the op caught an unexpected read error and returned diagnostics instead of throwing.

## Page Values

- `lead-list`: top/current context is a lead list and no actionable lead-log context was found.
- `lead-log`: the current/action context is a lead log.
- `lead-list-with-open-lead-log`: top document is a lead list and an accessible iframe contains a lead log with attempted-contact controls.
- `appointment-frame`: an accessible document contains appointment date/save controls.
- `unknown`: no supported page classification.

## topPage and actionPage

`topPage` describes the top document only.

`actionPage` describes the best actionable context:

- `appointment-frame` wins if appointment date and appointment save controls are present.
- `lead-log` wins over lead-list if attempted-contact controls are present.
- `none` means no actionable CRM context was found.

This allows a page to report:

```text
page=lead-list-with-open-lead-log
topPage=lead-list
actionPage=lead-log
actionFramePath=top/frame[0]
```

## Lead-List Detection

Lead-list evidence includes:

- URL containing `ProspectCompanies.aspx`
- title/body evidence suggesting `Lead List`
- visible lead-log links matching:
  - `a[id*='lnkProspectLog']`
  - `a[title*='View Lead Log']`

Lead-list readiness requires `leadListLinkCount > 0`.

## Lead-Log Detection

Lead-log evidence can be in the top document or an accessible iframe.

Controls:

- Next lead: `ctl00_ContentPlaceHolder1_lnkNext`
- Action dropdown: `ctl00_ContentPlaceHolder1_DDLogType_Input`
- History save: `ctl00_ContentPlaceHolder1_btnUpdate_input`
- Add appointment: `js-Lead-Log-Add-New-Appointment` or `AppointmentInserting()`
- Status: `ctl00_ContentPlaceHolder1_ddStatus_Input`

Lead-log attempted-contact readiness requires:

- action dropdown
- history save
- add appointment

Next lead is returned separately because it matters for `Ctrl+Alt+H` traversal but is not required for `Ctrl+Alt+K` current-lead mutation.

## Appointment-Frame Detection

Appointment evidence can be in an accessible nested iframe.

Controls:

- date/time: `ctl00_ContentPlaceHolder1_RadDateTimePicker1_dateInput`
- save: `ctl00_ContentPlaceHolder1_lnkSave_input`

Appointment-frame readiness requires both controls.

## Iframe Behavior

The op inspects:

- the top document
- accessible `iframe` and `frame` documents
- nested accessible frames recursively

Cross-origin or inaccessible frames are counted in `frameCount` but not in `accessibleFrameCount`. Inaccessible frames do not fail the op.

`actionFramePath` uses a stable diagnostic path such as:

```text
top
top/frame[0]
top/frame[0]/frame[0]
```

## Current Workflow Status

The current CRM workflows use this status as a mutation guard.

- `Ctrl+Alt+K` is the guarded current-lead attempted-contact primitive.
- `Ctrl+Alt+H` is the batch orchestrator and reuses the same guarded single-lead engine.
- `lead-list-with-open-lead-log` is a valid mutation context when `actionPage=lead-log` and attempted-contact controls are present.
- `lead-list` alone is valid only for finding/opening leads, not for mutation.

The shared AHK guard is `CrmRunAttemptedContactAppointmentGuarded()`.

## Frame-Aware CRM Actions

The read/write CRM DevTools ops now locate controls by searching accessible top/frame documents for the target control instead of assuming the first iframe:

- `focus_action_dropdown`
- `save_history_note`
- `add_new_appointment`
- `focus_date_time_field`
- `save_appointment`
- `get_blitz_current_lead_title`
- `open_blitz_lead_log_by_name`
- `click_blitz_next_lead`

Their existing return strings remain unchanged. Only target document resolution changed.

## Related Diagnostics

Generic DevTools bridge returns are logged to:

```text
logs/devtools_bridge_returns.log
```

Collect this log after `Ctrl+Alt+H` or `Ctrl+Alt+K` failures to see whether `blitz_page_status` or other CRM/Blitz JS ops returned empty, stale, timeout, error-shaped, or key=value payloads at the AHK bridge boundary.
