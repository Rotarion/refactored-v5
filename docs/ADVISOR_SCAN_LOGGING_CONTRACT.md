# Advisor Scan Logging Contract

This document describes how Advisor Pro page scan diagnostics are written by `workflows/advisor_quote_workflow.ahk`.

## Old Behavior

Each call to `AdvisorQuoteScanCurrentPage()` wrote two files:

- `logs/advisor_scan_latest.json`
- one timestamped archive file such as `logs/advisor_scan_<timestamp>_<label>_<reason>.json`

A single Advisor workflow run can scan many times, so one run could create 5-12 separate archived scan files.

## New Behavior

Each Advisor workflow run initializes one scan run bundle when `AdvisorQuoteInitTrace()` runs.

The latest single-scan file is still written:

```text
logs/advisor_scan_latest.json
```

All scans for the run are also appended to one run-level bundle:

```text
logs/advisor_scans/advisor_scan_run_<runId>.json
```

The run id is generated once per Advisor workflow run from the run start timestamp and reused for every scan in that run.

## Bundle Shape

The bundle JSON contains:

- `runId`
- `startedAt`
- `updatedAt`
- `scanCount`
- `scans`

Each `scans` entry contains:

- `sequence`
- `capturedAt`
- `label`
- `reason`
- `state`
- `url`
- `payload`

`payload` is the original JSON object returned by the existing `scan_current_page` JavaScript op. No JS operator behavior, op names, return values, selectors, or wait logic were changed.

## Individual Scan Archives

Per-scan archived files are disabled by default.

There is a code-level opt-in flag:

```ahk
advisorQuoteWriteIndividualScanArchives := false
```

If explicitly set to `true`, the old timestamped individual archive files can still be written. No config file setting was added because there was no existing low-risk config pattern for this diagnostic toggle.

## Atomic Writes

Both `advisor_scan_latest.json` and the run bundle are written through a temporary file first, then moved into place. This reduces the chance of a corrupt JSON file if the automation is stopped while a write is in progress.

## Failure Behavior

Scan write failures are non-fatal.

If writing the latest scan, the run bundle, or an optional individual archive fails, the workflow logs `SCAN_WRITE_FAILED` through the existing Advisor quote trace mechanism and returns control to the workflow. Bundle write failure does not change page automation behavior.

## How To Find A Run's Scans

For the current or most recent page snapshot, use:

```text
logs/advisor_scan_latest.json
```

For all scans from one Advisor workflow run, open:

```text
logs/advisor_scans/advisor_scan_run_<runId>.json
```

Inside that bundle, `scanCount` gives the total number of snapshots written so far, and `scans[n].sequence` preserves capture order.

## Known Limitations

- The bundle is maintained in memory during a single AutoHotkey process run and atomically rewritten after each scan.
- If AutoHotkey exits mid-run, the last successful bundle write remains valid, but scans after that write are naturally absent.
- `state` currently mirrors the AHK scan label when provided; the JS scan payload itself does not return a formal state field.
- The scan payload may already contain page body samples. The bundle metadata does not add raw clipboard text, phone, DOB, email, VIN, or address fields.

## Validation

Approved validation command run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

Result summary:

- `SMOKE_VALIDATE=pass`
- `MAIN_VALIDATE=pass`
- `COMPILER_CHECK=skipped`

Artifact root:

```text
logs/toolchain_checks/20260427_122710
```
