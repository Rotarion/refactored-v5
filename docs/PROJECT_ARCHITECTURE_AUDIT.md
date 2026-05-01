# Project Architecture Audit

Audit target: `Final_V5.5_refactored`  
Audit date: `2026-04-24`  
Audit mode: static inspection only  

## Scope And Safety Notes

- `AGENTS.md` status: missing for this project path. No project-local or ancestor `AGENTS.md` was found under `C:\Users\sflzsl7k\Documents\Codex\Final_V5.5_refactored`, so this repo currently has no project rule file.
- AutoHotkey execution in this audit: not run.
- AutoHotkey scripts executed directly: no.
- `AutoHotkeyUX.exe /?`: not run.
- `Ahk2Exe.exe /?`: not run.
- Toolchain checker: inspected, not run in this audit.
- Shell activity in this audit: bounded PowerShell inspection commands only (`Get-ChildItem`, `Get-Content`, `Select-String`).

## 1. Full Project Tree

Legend:

- `[ENTRY]` likely executable entry point
- `[HOTKEY]` hotkey registration module
- `[TEST]` test or diagnostic harness
- `[RUNTIME]` generated or runtime artifact

### Source, config, docs, and tool tree

```text
Final_V5.5_refactored/
  [ENTRY] main.ahk
  [TEST] _advisor_helper_check.ahk
  [TEST] _syntax_check.ahk
  ADVISOR_PRO_SCAN_WORKFLOW.md
  COMPATIBILITY_NOTE.md
  DEAD_CODE_REPORT.md
  MIGRATION_PLAN.md
  NEXT_SPRINT_RECOMMENDATIONS.md
  PROJECT_TREE.md
  RESPONSIBILITY_MAP.md
  RISK_LOG.md
  adapters/
    browser_focus_adapter.ahk
    clipboard_adapter.ahk
    crm_adapter.ahk
    devtools_bridge.ahk
    quo_adapter.ahk
    tag_selector_adapter.ahk
  assets/
    js/
      advisor_quote/
        ops_result.js
      devtools_bridge/
        ops_result.js
      participant_input_focus.js
      quo/
        ops_result.js
      tag_selector.js
  config/
    holidays_2026.ini
    settings.ini
    templates.ini
    timings.ini
  docs/
    AHK_TOOLCHAIN_CHECKS.md
    PROJECT_ARCHITECTURE_AUDIT.md
  domain/
    advisor_quote_db.ahk
    batch_rules.ahk
    date_rules.ahk
    lead_normalizer.ahk
    lead_parser.ahk
    message_templates.ahk
    pricing_rules.ahk
  hotkeys/
    [HOTKEY] crm_hotkeys.ahk
    [HOTKEY] debug_hotkeys.ahk
    [HOTKEY] lead_hotkeys.ahk
    [HOTKEY] schedule_hotkeys.ahk
  tests/
    [TEST] advisor_quote_helper_tests.ahk
    [TEST] date_tests.ahk
    [TEST] message_tests.ahk
    [TEST] parser_fixtures.ahk
    [TEST] pricing_tests.ahk
    [TEST] workflow_dryrun_tests.ahk
  tools/
    Invoke-AhkChecked.ps1
    Test-AhkToolchain.ps1
  workflows/
    advisor_quote_workflow.ahk
    batch_run.ahk
    config_ui.ahk
    crm_activity.ahk
    message_schedule.ahk
    prospect_fill.ahk
    single_lead_create.ahk
```

### Generated / runtime artifacts observed

```text
logs/
  [RUNTIME] _syntax_stderr.txt
  [RUNTIME] _syntax_stdout.txt
  [RUNTIME] advisor_quote_trace.log
  [RUNTIME] advisor_scan_latest.json
  [RUNTIME] batch_lead_log.csv
  [RUNTIME] latest_batch_ok_leads.txt
  [RUNTIME] run_state.json
  syntax_probe/
    [RUNTIME] probe_01.ahk
    [RUNTIME] probe_02.ahk
  toolchain_checks/
    20260424_143848/
      [RUNTIME] main_guard_wrapper.ahk
      [RUNTIME] smoke_guard_wrapper.ahk
      [RUNTIME] smoke_validate.ahk
    20260424_143902/
      [RUNTIME] fallback-main-load.json
      [RUNTIME] fallback-smoke-load.json
      [RUNTIME] main_guard_wrapper.ahk
      [RUNTIME] smoke_guard_wrapper.ahk
      [RUNTIME] smoke_validate.ahk
      [RUNTIME] validate-smoke-probe.json
    20260424_143951/
      [RUNTIME] main_guard_wrapper.ahk
      [RUNTIME] smoke_guard_wrapper.ahk
      [RUNTIME] smoke_validate.ahk
      [RUNTIME] validate-main.json
      [RUNTIME] validate-smoke-probe.json
```

Observations:

- `main.ahk` is the only production bootstrap entry point.
- `_syntax_check.ahk` and `_advisor_helper_check.ahk` are diagnostic/test harnesses, not user-facing workflow entries.
- Runtime output is already separated into `logs/`, which helps keep generated wrappers and validation artifacts out of source folders.

## 2. Entry Point Analysis

### Main production entry point

File: `main.ahk`

Bootstrap behavior:

1. Declares AHK v2, single instance, and `SendMode "Input"`.
2. Defines project-global paths:
   - `projectRoot`, `configRoot`, `logsRoot`, `assetsRoot`
   - `settingsFile`, `timingsFile`, `templatesFile`, `holidaysFile`
   - `batchLogFile`, `latestBatchOkFile`, `runStateFile`, `advisorQuoteTraceFile`
3. Declares runtime globals for holidays, batch state, stop flag, and Advisor Quote step tracking.
4. Calls `InitializeApplication()`.
5. Calls `PersistRunState("startup")`.
6. Includes modules in this order:
   - domain
   - adapters
   - workflows
   - hotkeys
7. Ends auto-execute section with `Return`.

### What `InitializeApplication()` does

`InitializeApplication()` in `main.ahk`:

- reads active operator/config values from `config/settings.ini`
- reads timing values from `config/timings.ini`
- loads holiday dates from `config/holidays_2026.ini`
- derives runtime defaults for pricing, follow-up cadence, CRM timings, and batch timings
- validates `Schedule Days` and rewrites defaults if invalid
- ensures the batch CSV header exists by calling `EnsureBatchLogHeader()`

### Config/bootstrap files read at startup

- `config/settings.ini`
- `config/timings.ini`
- `config/holidays_2026.ini`

`config/templates.ini` is not eagerly parsed during bootstrap, but is used by `message_templates.ahk` on demand for quote/follow-up/CRM note text.

### Include / load order from `main.ahk`

Domain:

- `domain/lead_normalizer.ahk`
- `domain/lead_parser.ahk`
- `domain/advisor_quote_db.ahk`
- `domain/pricing_rules.ahk`
- `domain/date_rules.ahk`
- `domain/batch_rules.ahk`
- `domain/message_templates.ahk`

Adapters:

- `adapters/clipboard_adapter.ahk`
- `adapters/browser_focus_adapter.ahk`
- `adapters/devtools_bridge.ahk`
- `adapters/quo_adapter.ahk`
- `adapters/crm_adapter.ahk`
- `adapters/tag_selector_adapter.ahk`

Workflows:

- `workflows/single_lead_create.ahk`
- `workflows/batch_run.ahk`
- `workflows/message_schedule.ahk`
- `workflows/prospect_fill.ahk`
- `workflows/advisor_quote_workflow.ahk`
- `workflows/crm_activity.ahk`
- `workflows/config_ui.ahk`

Hotkeys:

- `hotkeys/lead_hotkeys.ahk`
- `hotkeys/schedule_hotkeys.ahk`
- `hotkeys/crm_hotkeys.ahk`
- `hotkeys/debug_hotkeys.ahk`

### Other entry-like files

- `_syntax_check.ahk`
  - diagnostic loader only
  - includes core domain/adapters plus `workflows/advisor_quote_workflow.ahk`
  - exits immediately with `ExitApp(0)`
- `_advisor_helper_check.ahk`
  - standalone helper assertions for `BuildAdvisorQuoteLeadProfile()`
  - uses sample input and hard-coded `AssertEqual()` checks

### Startup notes

- `main.ahk` defines `legacyMonolithFile := projectRoot "\..\Final_V5.5.ahk"`, but no runtime caller was detected. This looks like migration residue rather than an active dependency.
- `PersistRunState()` writes `logs/run_state.json` and is reused by stop/config/batch operations.

## 3. Hotkey Map

| Hotkey | File | Function / registration target | Workflow reached | Adapter dependencies | Classification |
| --- | --- | --- | --- | --- | --- |
| `^!u` | `hotkeys/lead_hotkeys.ahk` | inline parse, then `RunQuickLeadCreateAndTag()` | single lead create + holder select + tag | `clipboard_adapter`, `browser_focus_adapter`, `quo_adapter`, `tag_selector_adapter` | production-critical, legacy-style inline |
| `^!1` | `hotkeys/lead_hotkeys.ahk` | inline `BuildMessage()` and direct paste | quote message compose only | no adapter wrapper for final paste; direct clipboard/send in hotkey | production utility, legacy-style |
| `^!b` | `hotkeys/lead_hotkeys.ahk` | `RunBatchFromClipboard("stable")` | stable batch quote/follow-up/tag flow | `browser_focus_adapter`, `clipboard_adapter`, `quo_adapter`, `tag_selector_adapter` | production-critical, refactored |
| `^!n` | `hotkeys/lead_hotkeys.ahk` | `RunBatchFromClipboard("fast")` | fast batch quote/follow-up/tag flow | `browser_focus_adapter`, `clipboard_adapter`, `quo_adapter`, `tag_selector_adapter` | production-critical, refactored |
| `^!-` | `hotkeys/lead_hotkeys.ahk` | `RunAdvisorQuoteWorkflowFromClipboard()` | Advisor Pro quote state machine | `browser_focus_adapter`, `clipboard_adapter`, `devtools_bridge`, `crm_adapter`, `assets/js/advisor_quote/ops_result.js` | production-critical, refactored |
| `^!r` | `hotkeys/schedule_hotkeys.ahk` | inline `Reload()` | reload running AutoHotkey script | none | production utility |
| `^!6` | `hotkeys/schedule_hotkeys.ahk` | `ScheduleLeadFollowupsByClipboard(false)` | follow-up scheduling, paste mode | `browser_focus_adapter`, `clipboard_adapter`, `quo_adapter` | production-critical |
| `^!7` | `hotkeys/schedule_hotkeys.ahk` | `ScheduleLeadFollowupsByClipboard(true)` | follow-up scheduling, typed/stable mode | `browser_focus_adapter`, `clipboard_adapter`, `quo_adapter` | production-critical |
| `^!8` | `hotkeys/schedule_hotkeys.ahk` | `ShowFollowupBatchPickerFromClipboard()` | selective follow-up GUI + send | `browser_focus_adapter`, `clipboard_adapter`, `quo_adapter` | production utility |
| `^!d` | `hotkeys/schedule_hotkeys.ahk` | inline business-date preview | schedule preview only | none | diagnostic / ops utility |
| `^!0` | `hotkeys/crm_hotkeys.ahk` | `RunNationalGeneralProspectFillFromClipboard()` | National General form fill | `browser_focus_adapter`, `clipboard_adapter`, `crm_adapter` | production-critical |
| `^!9` | `hotkeys/crm_hotkeys.ahk` | `RunNewProspectFillFromClipboard()` | new prospect form fill in Edge | `browser_focus_adapter`, `clipboard_adapter`, `crm_adapter` | production-critical |
| `^!t` | `hotkeys/crm_hotkeys.ahk` | `RunPasteLastConfiguredDatePreset()` | CRM date preset paste | `clipboard_adapter`, `crm_adapter` | production utility |
| `^!y` | `hotkeys/crm_hotkeys.ahk` | `RunPasteTomorrowPhonePreset()` | CRM phone/date preset paste | `clipboard_adapter`, `crm_adapter` | production utility |
| `^!k` | `hotkeys/crm_hotkeys.ahk` | `RunCrmAttemptedContactWorkflow()` | CRM attempted-contact workflow | `browser_focus_adapter`, `clipboard_adapter`, `devtools_bridge`, `crm_adapter` | production-critical |
| `^!j` | `hotkeys/crm_hotkeys.ahk` | `RunCrmQuoteCallWorkflow()` | CRM quote-call workflow | `browser_focus_adapter`, `clipboard_adapter`, `devtools_bridge`, `crm_adapter` | production-critical |
| `^!h` | `hotkeys/crm_hotkeys.ahk` | `RunCrmAttemptedContactForLatestBatchOkLeads()` | latest-batch-ok CRM replay | `browser_focus_adapter`, `clipboard_adapter`, `devtools_bridge`, `crm_adapter`, `batch_run` log files | production-critical |
| `Esc` | `hotkeys/debug_hotkeys.ahk` | inline stop handler | global stop flag + quote stop logging | `clipboard_adapter`, `advisor_quote_workflow`, `main` state persistence | production-critical safety |
| `F1` | `hotkeys/debug_hotkeys.ahk` | `ExitApp` | hard exit | none | debug / safety |
| `^!g` | `hotkeys/debug_hotkeys.ahk` | inline `RunQuoTagSelector()` + `HandleQuoTagSelectorResult()` | tag-selector diagnostics | `browser_focus_adapter`, `clipboard_adapter`, `devtools_bridge`, `tag_selector_adapter`, `quo_adapter` | debug |
| `^!c` | `hotkeys/debug_hotkeys.ahk` | inline control dump | Win control inspection only | none | debug |
| `^!\`` | `hotkeys/debug_hotkeys.ahk` | `OpenConfigEditor(1)` | config GUI | none direct | admin / debug |
| `^!m` | `hotkeys/debug_hotkeys.ahk` | inline parser debug | DOB/ZIP normalization inspection | none | debug |
| `^!p` | `hotkeys/debug_hotkeys.ahk` | inline parser debug | normalized prospect preview | none | debug |
| `^!]` | `hotkeys/debug_hotkeys.ahk` | inline raw parse debug | labeled-lead map preview | none | debug |
| `^!l` | `hotkeys/debug_hotkeys.ahk` | inline batch preview | parsed batch holder + price preview | none direct | debug / support |
| `^!s` | `hotkeys/debug_hotkeys.ahk` | inline `AdvisorQuoteScanCurrentPage()` | Advisor page scanner | `browser_focus_adapter`, `devtools_bridge`, `advisor_quote_workflow` | debug, refactored |
| `F8` | `hotkeys/debug_hotkeys.ahk` | inline `SpamLoop()` toggle | repeated click + Enter loop | no adapter abstraction; direct click/send | debug, high-risk |

Notes:

- The active Advisor Pro quote hotkey is `Ctrl+Alt+-` -> `^!-`.
- `hotkeys/lead_hotkeys.ahk` still contains meaningful business/workflow decisions inline instead of only delegating.
- Debug hotkeys are concentrated in one module, but `Esc` doubles as a real production safety stop.

## 4. Include / Dependency Graph

Caller detection below is approximate and based on explicit symbol references found in source.

### Root / bootstrap

- `main.ahk`
  - Includes: all domain, adapter, workflow, and hotkey modules
  - Exposes: bootstrap/config/state helpers (`InitializeApplication`, `PersistRunState`, `ResetRotationOffset`, batch resume helpers, UTF-8/json helpers)
  - Detected callers: `adapters/clipboard_adapter.ahk`, `domain/date_rules.ahk`, `hotkeys/debug_hotkeys.ahk`, `hotkeys/schedule_hotkeys.ahk`, `workflows/advisor_quote_workflow.ahk`, `workflows/batch_run.ahk`, `workflows/config_ui.ahk`

- `_syntax_check.ahk`
  - Includes: core domain/adapters plus `workflows/advisor_quote_workflow.ahk`
  - Exposes: none
  - Detected callers: none

- `_advisor_helper_check.ahk`
  - Includes: `domain/lead_normalizer.ahk`, `domain/advisor_quote_db.ahk`, `domain/lead_parser.ahk`, `domain/batch_rules.ahk`
  - Exposes: `AssertEqual`
  - Detected callers: none meaningful outside test-only duplicate assertion names

### Domain layer

- `domain/lead_normalizer.ahk`
  - Includes: none
  - Exposes: string/name/address/contact normalization helpers, `NewProspectFields()`, DOB/gender/state/zip normalization, array helpers
  - Detected callers: `adapters/crm_adapter.ahk`, `adapters/devtools_bridge.ahk`, `domain/advisor_quote_db.ahk`, `domain/batch_rules.ahk`, `domain/lead_parser.ahk`, `domain/message_templates.ahk`, `hotkeys/debug_hotkeys.ahk`, `hotkeys/lead_hotkeys.ahk`, `workflows/advisor_quote_workflow.ahk`, `workflows/config_ui.ahk`, `workflows/crm_activity.ahk`, `workflows/message_schedule.ahk`, `workflows/prospect_fill.ahk`

- `domain/lead_parser.ahk`
  - Includes: none
  - Exposes: prospect parsing, batch-grid parsing, labeled-lead parsing, `BuildAdvisorQuoteLeadProfile()`
  - Detected callers: `_advisor_helper_check.ahk`, `domain/batch_rules.ahk`, `hotkeys/debug_hotkeys.ahk`, `tests/advisor_quote_helper_tests.ahk`, `tests/parser_fixtures.ahk`, `workflows/advisor_quote_workflow.ahk`, `workflows/prospect_fill.ahk`

- `domain/advisor_quote_db.ahk`
  - Includes: none
  - Exposes: Advisor Quote selectors/defaults/timeouts/text anchors plus vehicle/address duplicate-match helpers
  - Detected callers: `domain/lead_parser.ahk`, `tests/advisor_quote_helper_tests.ahk`, `workflows/advisor_quote_workflow.ahk`

- `domain/pricing_rules.ahk`
  - Includes: none
  - Exposes: quote pricing resolution and vehicle-year extraction
  - Detected callers: `domain/message_templates.ahk`, `hotkeys/debug_hotkeys.ahk`, `hotkeys/lead_hotkeys.ahk`, `tests/pricing_tests.ahk`

- `domain/date_rules.ahk`
  - Includes: none
  - Exposes: business-day math, rotation offsets, follow-up date/time helpers
  - Detected callers: `domain/message_templates.ahk`, `hotkeys/schedule_hotkeys.ahk`, `main.ahk`, `tests/date_tests.ahk`, `workflows/batch_run.ahk`, `workflows/config_ui.ahk`, `workflows/crm_activity.ahk`, `workflows/message_schedule.ahk`

- `domain/batch_rules.ahk`
  - Includes: none
  - Exposes: batch row parsing, vehicle extraction, `BuildBatchLeadRecord()`, `BuildBatchLeadHolder()`
  - Detected callers: `domain/lead_parser.ahk`, `hotkeys/debug_hotkeys.ahk`, `hotkeys/lead_hotkeys.ahk`, `tests/parser_fixtures.ahk`, `tests/workflow_dryrun_tests.ahk`, `workflows/batch_run.ahk`

- `domain/message_templates.ahk`
  - Includes: none
  - Exposes: template read/write, token expansion, quote message build, follow-up queue build
  - Detected callers: `adapters/crm_adapter.ahk`, `hotkeys/lead_hotkeys.ahk`, `tests/message_tests.ahk`, `workflows/batch_run.ahk`, `workflows/config_ui.ahk`, `workflows/crm_activity.ahk`, `workflows/message_schedule.ahk`

### Adapter layer

- `adapters/browser_focus_adapter.ahk`
  - Includes: none
  - Exposes: `FocusEdge()`, `FocusChrome()`, `FocusWorkBrowser()`
  - Detected callers: `adapters/crm_adapter.ahk`, `adapters/devtools_bridge.ahk`, `adapters/quo_adapter.ahk`, `adapters/tag_selector_adapter.ahk`, `hotkeys/debug_hotkeys.ahk`, `workflows/advisor_quote_workflow.ahk`, `workflows/batch_run.ahk`, `workflows/crm_activity.ahk`, `workflows/message_schedule.ahk`, `workflows/prospect_fill.ahk`, `workflows/single_lead_create.ahk`

- `adapters/clipboard_adapter.ahk`
  - Includes: none
  - Exposes: run-start/stop helpers, bounded sleep, clipboard set/paste helpers, tab send helper, sort helper
  - Detected callers: `adapters/crm_adapter.ahk`, `adapters/devtools_bridge.ahk`, `adapters/quo_adapter.ahk`, `adapters/tag_selector_adapter.ahk`, `hotkeys/debug_hotkeys.ahk`, `hotkeys/lead_hotkeys.ahk`, `workflows/advisor_quote_workflow.ahk`, `workflows/batch_run.ahk`, `workflows/crm_activity.ahk`, `workflows/message_schedule.ahk`, `workflows/prospect_fill.ahk`, `workflows/single_lead_create.ahk`

- `adapters/devtools_bridge.ahk`
  - Includes: none
  - Exposes: DevTools execution wrappers, JS asset loading/template rendering, CRM Blitz JS bridge helpers
  - Detected callers: `adapters/crm_adapter.ahk`, `adapters/quo_adapter.ahk`, `adapters/tag_selector_adapter.ahk`

- `adapters/quo_adapter.ahk`
  - Includes: none
  - Exposes: Quo composer focus/ready helpers, new-conversation priming, holder selection, message scheduling
  - Detected callers: `adapters/tag_selector_adapter.ahk`, `workflows/batch_run.ahk`, `workflows/message_schedule.ahk`, `workflows/single_lead_create.ahk`

- `adapters/tag_selector_adapter.ahk`
  - Includes: none
  - Exposes: tag-selector asset load, selector result handling, tag apply sequences
  - Detected callers: `hotkeys/debug_hotkeys.ahk`, `workflows/batch_run.ahk`, `workflows/single_lead_create.ahk`

- `adapters/crm_adapter.ahk`
  - Includes: none
  - Exposes: prospect fill routines, CRM appointment sequences, Blitz lead navigation helpers
  - Detected callers: `hotkeys/crm_hotkeys.ahk`, `workflows/advisor_quote_workflow.ahk`, `workflows/crm_activity.ahk`, `workflows/prospect_fill.ahk`

### Workflow layer

- `workflows/single_lead_create.ahk`
  - Includes: none
  - Exposes: `RunQuickLeadCreateAndTag()`
  - Detected callers: `hotkeys/lead_hotkeys.ahk`

- `workflows/batch_run.ahk`
  - Includes: none
  - Exposes: batch CSV/log helpers, batch resume helpers, `RunBatchFromClipboard()`, `RunBatchLeadFlow()`, `TraceBatchLeadPlan()`
  - Detected callers: `adapters/crm_adapter.ahk`, `hotkeys/lead_hotkeys.ahk`, `main.ahk`, `tests/workflow_dryrun_tests.ahk`

- `workflows/message_schedule.ahk`
  - Includes: none
  - Exposes: follow-up scheduling, batch picker GUI, send-selected logic
  - Detected callers: `hotkeys/schedule_hotkeys.ahk`, `workflows/batch_run.ahk`

- `workflows/prospect_fill.ahk`
  - Includes: none
  - Exposes: `RunNationalGeneralProspectFillFromClipboard()`, `RunNewProspectFillFromClipboard()`
  - Detected callers: `hotkeys/crm_hotkeys.ahk`

- `workflows/crm_activity.ahk`
  - Includes: none
  - Exposes: CRM preset builders and CRM attempted-contact / quote-call workflows
  - Detected callers: `adapters/crm_adapter.ahk`, `hotkeys/crm_hotkeys.ahk`

- `workflows/config_ui.ahk`
  - Includes: none
  - Exposes: config editor GUI, config snapshot/read/validate/write helpers
  - Detected callers: `hotkeys/debug_hotkeys.ahk`

- `workflows/advisor_quote_workflow.ahk`
  - Includes: none
  - Exposes: full Advisor Quote state machine, state handlers, DOM-op wrappers, scan/log helpers
  - Detected callers: `hotkeys/lead_hotkeys.ahk`, `hotkeys/debug_hotkeys.ahk`

### Hotkey registration modules

- `hotkeys/lead_hotkeys.ahk`
  - Includes: none
  - Exposes: hotkey registrations only
  - Detected callers: none

- `hotkeys/schedule_hotkeys.ahk`
  - Includes: none
  - Exposes: hotkey registrations only
  - Detected callers: none

- `hotkeys/crm_hotkeys.ahk`
  - Includes: none
  - Exposes: hotkey registrations only
  - Detected callers: none

- `hotkeys/debug_hotkeys.ahk`
  - Includes: none
  - Exposes: hotkeys plus `SpamLoop()`
  - Detected callers: none

### Tests

- `tests/advisor_quote_helper_tests.ahk`
  - Includes: `..\domain\lead_normalizer.ahk`, `..\domain\advisor_quote_db.ahk`, `..\domain\lead_parser.ahk`, `..\domain\batch_rules.ahk`
  - Exposes: local `AssertEqual`, `AssertTrue`
  - Detected callers: none meaningful outside repeated test helper names

- `tests/date_tests.ahk`
  - Includes: `..\domain\date_rules.ahk`
  - Exposes: local `AssertEqual`
  - Detected callers: none meaningful outside repeated test helper names

- `tests/message_tests.ahk`
  - Includes: `..\domain\lead_normalizer.ahk`, `..\domain\pricing_rules.ahk`, `..\domain\date_rules.ahk`, `..\domain\message_templates.ahk`
  - Exposes: local `AssertEqual`, `AssertTrue`
  - Detected callers: none meaningful outside repeated test helper names

- `tests/parser_fixtures.ahk`
  - Includes: `..\domain\lead_normalizer.ahk`, `..\domain\lead_parser.ahk`, `..\domain\batch_rules.ahk`
  - Exposes: local `AssertEqual`
  - Detected callers: none meaningful outside repeated test helper names

- `tests/pricing_tests.ahk`
  - Includes: `..\domain\pricing_rules.ahk`
  - Exposes: local `AssertEqual`
  - Detected callers: none meaningful outside repeated test helper names

- `tests/workflow_dryrun_tests.ahk`
  - Includes: `..\domain\lead_normalizer.ahk`, `..\domain\lead_parser.ahk`, `..\domain\pricing_rules.ahk`, `..\domain\date_rules.ahk`, `..\domain\message_templates.ahk`, `..\domain\batch_rules.ahk`, `..\workflows\batch_run.ahk`
  - Exposes: local `AssertEqual`, `AssertTrue`
  - Detected callers: none meaningful outside repeated test helper names

## 5. Layer Ownership Check

Target layers requested:

- `hotkeys/`
- `workflows/`
- `domain/`
- `adapters/`
- `config/`
- `assets/js/`
- `tests/`

### File-by-file ownership assessment

| File | Expected owner/layer | Status | Notes |
| --- | --- | --- | --- |
| `main.ahk` | bootstrap root (outside target layers) | exception | valid bootstrap, but not part of listed layer taxonomy |
| `_syntax_check.ahk` | diagnostics root (outside target layers) | exception | safe loader harness |
| `_advisor_helper_check.ahk` | tests/diagnostics root | mild drift | test-like helper stored at repo root |
| `domain/lead_normalizer.ahk` | domain | fits | pure parsing/normalization helpers |
| `domain/lead_parser.ahk` | domain | fits | parsing/composition of normalized lead fields |
| `domain/batch_rules.ahk` | domain | fits | batch lead parsing and vehicle extraction |
| `domain/pricing_rules.ahk` | domain | fits | pricing rules only |
| `domain/date_rules.ahk` | domain | fits | date/rotation business rules |
| `domain/message_templates.ahk` | domain | mild drift | business templates plus direct config file IO (`templates.ini`) |
| `domain/advisor_quote_db.ahk` | config or workflow config, not domain | violation | stores selectors, defaults, timeouts, and text anchors; more config than domain |
| `adapters/browser_focus_adapter.ahk` | adapters | fits | browser/window activation only |
| `adapters/clipboard_adapter.ahk` | adapters | fits | clipboard/send utility primitives |
| `adapters/devtools_bridge.ahk` | adapters | fits | browser DevTools bridge and JS asset runner |
| `adapters/quo_adapter.ahk` | adapters | mild violation | contains multi-step QUO workflow sequences, not only primitive adapter calls |
| `adapters/tag_selector_adapter.ahk` | adapters | mild violation | includes selector result branching and recovery workflow logic |
| `adapters/crm_adapter.ahk` | adapters | violation | mixes UI adapter primitives with full CRM business workflows and Blitz traversal |
| `workflows/single_lead_create.ahk` | workflows | fits | orchestration only |
| `workflows/batch_run.ahk` | workflows | fits | orchestration, logging, resume state |
| `workflows/message_schedule.ahk` | workflows | fits | orchestration + GUI picker |
| `workflows/prospect_fill.ahk` | workflows | fits | thin orchestration over parser + CRM adapter |
| `workflows/crm_activity.ahk` | workflows | fits | workflow composition only |
| `workflows/advisor_quote_workflow.ahk` | workflows | mild violation | active refactored state machine plus dormant alternative helper path in same file |
| `workflows/config_ui.ahk` | config UI more than workflow | mild drift | lives under workflows but functionally belongs near config/ui |
| `hotkeys/lead_hotkeys.ahk` | hotkeys | mild violation | contains inline parsing/message logic instead of pure dispatch |
| `hotkeys/schedule_hotkeys.ahk` | hotkeys | fits | mostly dispatch plus light preview |
| `hotkeys/crm_hotkeys.ahk` | hotkeys | fits | clean dispatch |
| `hotkeys/debug_hotkeys.ahk` | hotkeys | fits with caution | debug-only logic and direct send spam loop |
| `assets/js/advisor_quote/ops_result.js` | assets/js | fits | Advisor DOM ops only |
| `assets/js/devtools_bridge/ops_result.js` | assets/js | fits | CRM/Blitz DOM ops only |
| `assets/js/participant_input_focus.js` | assets/js | fits | QUO participant-field helper |
| `assets/js/quo/ops_result.js` | assets/js | fits | QUO composer helper |
| `assets/js/tag_selector.js` | assets/js | fits | tag target discovery asset |
| `config/settings.ini` | config | fits | runtime config |
| `config/timings.ini` | config | fits | timing config |
| `config/templates.ini` | config | fits | message/note templates |
| `config/holidays_2026.ini` | config | fits | holiday schedule |
| `tests/*.ahk` | tests | fits | test and dry-run assets |

### Layering findings

#### Violations / drifts worth flagging

- Business logic inside adapters:
  - `adapters/crm_adapter.ahk`
  - `adapters/quo_adapter.ahk`
  - `adapters/tag_selector_adapter.ahk`
- Config/selectors inside domain:
  - `domain/advisor_quote_db.ahk`
- Hotkeys directly doing complex logic:
  - `hotkeys/lead_hotkeys.ahk` (`^!u`, `^!1`)
- Duplicate logic across workflows:
  - `workflows/single_lead_create.ahk` overlaps the QUO prime/select/tag tail already embedded in `workflows/batch_run.ahk`
- Legacy/refactored path mixing:
  - `main.ahk` still declares `legacyMonolithFile`
  - `workflows/advisor_quote_workflow.ahk` still contains older alternative helpers (`AdvisorQuoteOpenEntryFlow`, `AdvisorQuoteOpenCreateNewProspectFromSearch`, `AdvisorQuoteEnsureEdgeAndDetectState`, `AdvisorQuoteHandleProspect`) that are not part of the active state-machine path

#### Clean separations observed

- No browser automation was found in `domain/`.
- JS browser automation is concentrated under `assets/js/` and `adapters/devtools_bridge.ahk`.
- Tests are kept under `tests/`, with runtime-generated AHK wrappers kept under `logs/`.

## 6. Advisor Pro Quote Workflow Map

Starting hotkey: `Ctrl+Alt+-` (`^!-`)  
Hotkey file: `hotkeys/lead_hotkeys.ahk`  
Entry function: `RunAdvisorQuoteWorkflowFromClipboard()`  
Core workflow file: `workflows/advisor_quote_workflow.ahk`  
Selector/default DB: `domain/advisor_quote_db.ahk`  
DOM automation asset: `assets/js/advisor_quote/ops_result.js`

### State machine overview

```mermaid
stateDiagram-v2
    [*] --> "Ctrl+Alt+-"
    "Ctrl+Alt+-" --> "Clipboard Parse"
    "Clipboard Parse" --> "EDGE_ACTIVATION"
    "EDGE_ACTIVATION" --> "ENTRY_SEARCH"
    "ENTRY_SEARCH" --> "ENTRY_CREATE_FORM"
    "ENTRY_CREATE_FORM" --> "DUPLICATE"
    "ENTRY_CREATE_FORM" --> "RAPPORT"
    "ENTRY_CREATE_FORM" --> "SELECT_PRODUCT"
    "DUPLICATE" --> "RAPPORT"
    "DUPLICATE" --> "SELECT_PRODUCT"
    "RAPPORT" --> "SELECT_PRODUCT"
    "SELECT_PRODUCT" --> "CONSUMER_REPORTS"
    "CONSUMER_REPORTS" --> "DRIVERS_VEHICLES"
    "CONSUMER_REPORTS" --> "INCIDENTS"
    "DRIVERS_VEHICLES" --> "INCIDENTS"
    "INCIDENTS" --> "QUOTE_LANDING"
    "QUOTE_LANDING" --> "DONE"
```

### Workflow runtime controls

Defaults from `domain/advisor_quote_db.ahk`:

- rating state: `FL`
- current insured: `YES`
- own/rent: `OWN`
- consumer reports consent: `yes`
- age first licensed: `16`
- military: `false`
- violations: `false`
- defensive driving: `false`
- remove-driver reason: `0006`
- incident reason text: `Accident caused by being hit by animal or road debris`
- finance threshold year: `2015`

Timeouts from `domain/advisor_quote_db.ahk`:

- `shortMs = 1200`
- `actionMs = 4000`
- `pageMs = 25000` (defined, not obviously used by the current state machine)
- `transitionMs = 35000`
- `pollMs = 350`
- `maxRetries = 3`

### Stage-by-stage map

| Stage | Entry function | Page / stage names | Expected selectors / scan anchors | Readiness checks | Timeout / fallback behavior |
| --- | --- | --- | --- | --- | --- |
| `INIT` | `RunAdvisorQuoteWorkflowFromClipboard()` | clipboard input only | non-empty clipboard; `BuildAdvisorQuoteLeadProfile()` must produce first + last name | `AdvisorQuoteProfileLooksUsable()` | hard fail if clipboard empty or profile unusable |
| `EDGE_ACTIVATION` | `AdvisorQuoteStateEdgeActivation()` | Edge with Advisor Pro/Gateway context | Edge window, URL/text detection via JS `detect_state` | `FocusEdge()` then `AdvisorQuoteDetectState()` | no-edge = fail; unknown state = retryable fail |
| `ENTRY_SEARCH` | `AdvisorQuoteStateEntrySearch()` | Advisor home / gateway to Begin Quoting | `group2_Quoting_button`, text `Quoting` | accepted states include `BEGIN_QUOTING_SEARCH`, `BEGIN_QUOTING_FORM`, `DUPLICATE`, `RAPPORT`, `SELECT_PRODUCT`, `ASC_PRODUCT`, `INCIDENTS` | click by id then text fallback; wait for observed state up to `35000ms`; capture scan on failure |
| `ENTRY_CREATE_FORM` | `AdvisorQuoteStateEntryCreateForm()` | Begin Quoting Search / Create New Prospect form | `outOfLocationCreateNewProspectButton`, `PrimaryApplicant-Continue-button`, prospect input ids from DB | `prospect_form_ready`, `focus_prospect_first_input`, `prospect_form_status`, second fill pass if validation fails | two-pass fill; click submit by id/text fallback; waits `35000ms`; scan and structured failure detail on form mismatch |
| `DUPLICATE` | `AdvisorQuoteStateDuplicate()` | `This Prospect May Already Exist` | duplicate heading text; radio candidates under `.sfmOption/.l-tile/[role=row]/div`; buttons by text (`Continue`, `Use Existing`, `Create New Prospect`) | duplicate page detection via text; candidate scoring on last name + street number + street token + zip, with first name and DOB as supporting evidence | retryable state; wait for transition to Rapport/Select Product/ASC/Incidents |
| `RAPPORT` / `GATHER_DATA` | `AdvisorQuoteStateRapport()` -> `AdvisorQuoteHandleGatherData()` | Gather Data / Rapport | URL contains `/rapport`; text `gather data`; vehicle ids `ConsumerData.Assets.Vehicles[n].*`; add-product ids `quotesButton` / `addProduct` | `wait_condition("gather_data")`; `fill_gather_defaults`; vehicle-added tile check; auto-start quoting state set | each vehicle addition is bounded by select-enabled waits and add confirmation wait; transition to Select Product bounded by `35000ms` |
| `SELECT_PRODUCT` | `AdvisorQuoteStateSelectProduct()` -> `AdvisorQuoteHandleSelectProduct()` | Select Product | `SelectProduct.RatingState`, `SelectProduct.Product`, `selectProductContinue` | `wait_condition("on_select_product")`; select/radio defaults pushed by JS | Continue click uses id then text fallback; waits for ASC/consumer page |
| `CONSUMER_REPORTS` | `AdvisorQuoteStateConsumerReports()` -> `AdvisorQuoteHandleConsumerReports()` | consumer reports on ASC | `orderReportsConsent-yes-btn`; text `order consumer reports` | `wait_condition("consumer_reports_ready")`; then `drivers_or_incidents` | click yes by id then text fallback; bounded by `transitionMs` |
| `DRIVERS_VEHICLES` | `AdvisorQuoteStateDriversVehicles()` -> `AdvisorQuoteHandleDriversVehicles()` | Drivers and vehicles | heading text `Drivers and vehicles`; driver ids `slug-add`, `slug-addToQuote`, `slug-remove`; continue id `profile-summary-submitBtn` | `drivers_or_incidents`; resolve driver slugs; detect vehicle add buttons from id pattern; wait for continue enabled | handles participant/remove/add-asset modals; continues to incidents after bounded wait |
| `INCIDENTS` | `AdvisorQuoteStateIncidents()` -> `AdvisorQuoteHandleIncidentsIfPresent()` | Incidents | heading `Incidents`; continue id `CONTINUE_OFFER-btn`; reason text match | `is_incidents`; `handle_incidents`; `incidents_done` | if incidents page absent, stage is skipped; otherwise bounded checkbox match and continue |
| `QUOTE_LANDING` | `AdvisorQuoteStateQuoteLanding()` | first quote page after ASC path | still under `ASCPRODUCT/110/`, but body text must no longer show Drivers, Incidents, or Consumer Reports | `wait_condition("quote_landing")` | bounded by `transitionMs`; scan on failure |

### Page-state detection model

The active state detector lives in `assets/js/advisor_quote/ops_result.js` under operation `detect_state`.

Primary anchors:

- `RAPPORT`
  - URL contains `/rapport`
  - or body text contains `gather data`
- `SELECT_PRODUCT`
  - URL contains `/selectProduct`
  - or body text contains `select product`
- `INCIDENTS`
  - `ASCPRODUCT/110/` URL and body text contains `incidents`
- `ASC_PRODUCT`
  - `ASCPRODUCT/110/` URL
  - or body text contains `drivers and vehicles`
  - or body text contains `order consumer reports`
- `DUPLICATE`
  - body text contains `This Prospect May Already Exist`
- `BEGIN_QUOTING_SEARCH`
  - selector `outOfLocationCreateNewProspectButton`
- `BEGIN_QUOTING_FORM`
  - selector `PrimaryApplicant-Continue-button`
- `ADVISOR_HOME`
  - selector `group2_Quoting_button`
- `ADVISOR_OTHER`
  - URL contains `advisorpro.allstate.com`
- `GATEWAY`
  - page text contains `allstate advisor pro`
- else `NO_CONTEXT`

### Scan snapshot behavior

The workflow can capture scan snapshots through `AdvisorQuoteScanCurrentPage()`:

- latest scan saved to `logs/advisor_scan_latest.json`
- archived scans saved as `logs/advisor_scan_<timestamp>_<label>_<reason>.json`
- scans include heading, body sample, visible fields, buttons, radios, alerts, and dialog text

### Known gaps in the current quote workflow

1. `AdvisorQuoteHandleOpenModals()` returns `true` even after its timeout loop expires (`workflows/advisor_quote_workflow.ahk:1181-1221`), so a stalled modal can be treated as success.
2. `detect_state` is heuristic and text-driven. It intentionally groups Consumer Reports and Drivers/Vehicles under the broader ASC context before later checks separate them.
3. The file still contains dormant alternate helper functions not used by the active state-machine path:
   - `AdvisorQuoteOpenEntryFlow()`
   - `AdvisorQuoteOpenCreateNewProspectFromSearch()`
   - `AdvisorQuoteEnsureEdgeAndDetectState()`
   - `AdvisorQuoteHandleProspect()`
4. The workflow assumes the active Edge window is the correct Advisor Pro tab; it does not verify tab identity beyond DOM/URL heuristics.
5. Duplicate resolution still relies on text scoring and generic button text, not a fully stable duplicate-row/page object model.
6. `pageMs` exists in the quote DB but the active state machine appears to standardize on `transitionMs`, `actionMs`, and `pollMs`.

## 7. Toolchain Safety Check

### Required file presence

| Item | Exists | Notes |
| --- | --- | --- |
| `AGENTS.md` | no | missing project rule file |
| `docs/AHK_TOOLCHAIN_CHECKS.md` | yes | documents banned checks and safe checker command |
| `tools/Invoke-AhkChecked.ps1` | yes | bounded timeout wrapper, kills process tree on timeout |
| `tools/Test-AhkToolchain.ps1` | yes | safe checker that uses the wrapper and writes JSON artifacts |

### Execution status in this audit

- Safe bounded checker run status: not run
- Exact safe command documented by the repo, but not executed here:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

- Result: not run
- Stdout: not run
- Stderr: not run

### What the inspected tool scripts do

- `tools/Invoke-AhkChecked.ps1`
  - requires `ExePath`
  - defaults to `TimeoutSeconds = 5`
  - uses `System.Diagnostics.ProcessStartInfo`
  - captures stdout/stderr
  - kills the full child process tree on timeout

- `tools/Test-AhkToolchain.ps1`
  - discovers local AutoHotkey interpreter/compiler candidates
  - prefers a v2 interpreter
  - probes `/Validate` support using the bounded wrapper
  - falls back to guarded wrapper scripts if `/Validate` is unsupported
  - does not use banned raw `AutoHotkeyUX.exe /?` or `Ahk2Exe.exe /?` checks
  - writes per-run artifacts under `logs/toolchain_checks/<timestamp>/`

### Pre-existing artifacts observed

The repo already contains prior toolchain-check artifacts under:

- `logs/toolchain_checks/20260424_143848/`
- `logs/toolchain_checks/20260424_143902/`
- `logs/toolchain_checks/20260424_143951/`

Those were not produced by this audit and are treated only as existing runtime artifacts.

## 8. Risk List

### Ranked risk register

| Severity | Risk | Evidence | Notes |
| --- | --- | --- | --- |
| critical | Modal timeout can be misreported as success in the quote flow | `workflows/advisor_quote_workflow.ahk:1181-1221` | `AdvisorQuoteHandleOpenModals()` exits `true` after timeout expiration instead of failing closed |
| high | Wrong-window / wrong-tab key-send risk | `adapters/browser_focus_adapter.ahk:1-19`, `adapters/quo_adapter.ahk`, `adapters/tag_selector_adapter.ahk`, `adapters/crm_adapter.ahk`, `adapters/devtools_bridge.ahk` | focus checks only verify browser process/window, not exact tab or field identity before `Send`/`Enter` |
| high | Clipboard-destructive behavior | `adapters/clipboard_adapter.ahk`, `hotkeys/lead_hotkeys.ahk`, `adapters/devtools_bridge.ahk` | many flows clear or replace clipboard content; only the DevTools bridge restores prior clipboard content |
| high | Unbounded manual wait in QUO recovery paths | `adapters/quo_adapter.ahk:40-46`, `adapters/quo_adapter.ahk:59-65` | `KeyWait` handoff has no timeout and can hang indefinitely waiting for a user click |
| medium | Mixed legacy/refactored quote paths in one workflow file | `main.ahk:21`, `workflows/advisor_quote_workflow.ahk:514-706` | inactive alternate entry/prospect helpers remain beside the active state machine |
| medium | Adapter layer owns business workflow decisions | `adapters/crm_adapter.ahk`, `adapters/quo_adapter.ahk`, `adapters/tag_selector_adapter.ahk` | raises maintenance and regression risk when workflows evolve |
| medium | Duplicate logic across single-lead and batch QUO paths | `workflows/single_lead_create.ahk`, `workflows/batch_run.ahk` | prime/select holder/apply tag tail is duplicated rather than shared |
| low | Duplicate function names exist only in tests | `AssertEqual`, `AssertTrue` repeated in test files | runtime namespace collision not observed in production modules |
| low | No unused JS assets detected in the active project tree | references found for all files under `assets/js/` | previously reported dead-code docs are stale relative to current references |
| low | No raw shell AHK calls detected | no `Run` / `RunWait` AHK shell invocations found in runtime `.ahk` files | good from a safety standpoint |

### Required checklist findings

| Item checked | Result |
| --- | --- |
| raw shell AHK calls | not found in current runtime `.ahk` source |
| AutoHotkeyUX diagnostic calls | not found as executable invocations; only mentioned in docs/tool discovery |
| Ahk2Exe `/?` calls | not found as executable invocations; only mentioned in docs/tool discovery |
| unbounded waits | found: `KeyWait` handoff in `adapters/quo_adapter.ahk`; debug `F8` spam loop is intentionally open-ended |
| page readiness loops without timeout | not found in the main Advisor Quote path; quote waits are bounded by `actionMs`, `transitionMs`, `pollMs`, and `maxRetries` |
| mixed legacy/refactored quote paths | found |
| duplicate function names | found only in tests (`AssertEqual`, `AssertTrue`) |
| unused JS assets | not found |
| clipboard destructive behavior | found |
| accidental Enter/send risks | found |

### Additional notes on send/enter risk

Files with direct `Send "{Enter}"` or equivalent high-impact submit actions:

- `adapters/devtools_bridge.ahk`
- `adapters/quo_adapter.ahk`
- `adapters/tag_selector_adapter.ahk`
- `hotkeys/debug_hotkeys.ahk`

This is mitigated only partially by browser focus helpers and stop-flag checks.

## 9. Recommended Next Sprint

Strict sequence, each step independently verifiable:

1. Prove toolchain safety first by running only the bounded checker and capturing a fresh artifact set:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1`
2. Fix `AdvisorQuoteHandleOpenModals()` so timeout returns failure, then validate with a forced-stall dry run or mocked modal condition.
3. Add explicit timeout-backed escape paths to the `KeyWait` recovery branches in `adapters/quo_adapter.ahk`.
4. Add stronger active-context validation before any `Send "{Enter}"`, `Send "!n"`, or DevTools submit sequence.
5. Split quote selector/default/timeout data out of `domain/advisor_quote_db.ahk` into a config-owned module or file.
6. Remove or isolate dormant quote helper paths (`AdvisorQuoteOpenEntryFlow`, `AdvisorQuoteHandleProspect`, related helpers) so only one Advisor Quote control path remains active.
7. Extract the shared QUO prime/select-holder/tag tail into one reusable workflow helper, then validate both single-lead and batch callers against it.

## Summary

- Production runtime is centered on `main.ahk`, with a clear include order and a real folderized refactor.
- The refactored Advisor Quote path is now a bounded state machine with scans, retries, and DOM-asset helpers.
- The biggest remaining concerns are not missing files; they are behavioral safety issues:
  - timeout masking in modal handling
  - wrong-window key-send exposure
  - clipboard destruction
  - unbounded manual waits
  - leftover mixed-path quote logic
