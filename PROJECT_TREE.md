# Actual Project Structure

This is the current on-disk structure of `Final_V5.5_refactored` as of `2026-04-27`.
It replaces the older tree that no longer matched the repo.

```text
Final_V5.5_refactored/
  main.ahk
  AGENTS.md
  ADVISOR_PRO_SCAN_WORKFLOW.md

  adapters/                      AHK integration layer for browser, clipboard, CRM, and QUO
    browser_focus_adapter.ahk
    clipboard_adapter.ahk
    crm_adapter.ahk
    devtools_bridge.ahk
    quo_adapter.ahk
    tag_selector_adapter.ahk

  workflows/                     End-to-end automation flows
    advisor_quote_workflow.ahk   Advisor Pro quote workflow
    batch_run.ahk
    config_ui.ahk
    crm_activity.ahk
    message_schedule.ahk
    prospect_fill.ahk
    single_lead_create.ahk

  domain/                        Shared parsing, normalization, rules, and workflow data helpers
    advisor_quote_db.ahk
    batch_rules.ahk
    date_rules.ahk
    lead_normalizer.ahk
    lead_parser.ahk
    message_templates.ahk
    pricing_rules.ahk

  assets/
    js/                          Injected JavaScript helpers
      advisor_quote/
        ops_result.js            Main Advisor Pro JS operator
      devtools_bridge/
        ops_result.js
      quo/
        ops_result.js
      participant_input_focus.js
      tag_selector.js

  hotkeys/                       Top-level hotkey bindings
    crm_hotkeys.ahk
    debug_hotkeys.ahk
    lead_hotkeys.ahk
    schedule_hotkeys.ahk

  config/                        INI configuration
    holidays_2026.ini
    settings.ini
    templates.ini
    timings.ini

  docs/                          Repo guidance and audits
    AGENT_RULE_RECONCILIATION.md
    AHK_TOOLCHAIN_CHECKS.md
    PROJECT_ARCHITECTURE_AUDIT.md

  tests/                         AHK tests and JS smoke tests
    advisor_quote_helper_tests.ahk
    advisor_quote_ops_smoke.js
    date_tests.ahk
    message_tests.ahk
    parser_fixtures.ahk
    pricing_tests.ahk
    workflow_dryrun_tests.ahk

  tools/                         Approved validation helpers
    Invoke-AhkChecked.ps1
    Test-AhkToolchain.ps1

  logs/                          Runtime traces, scans, and validation output

  agents/
    skills/                      Local agent skill library; not part of the AHK runtime path
```

## What matters most

- `main.ahk` is the app entry point.
- `workflows/advisor_quote_workflow.ahk` is the main Advisor Pro AHK workflow.
- `assets/js/advisor_quote/ops_result.js` is the injected Advisor Pro JavaScript operator.
- `adapters/devtools_bridge.ahk` is the AHK side of the JS injection bridge.
- `domain/advisor_quote_db.ahk` holds Advisor Pro quote data shaping helpers.
- `tools/Test-AhkToolchain.ps1` is the bounded toolchain check required before workflow/business-logic edits.

## Notes

- `PROJECT_TREE.md` is now the simple source of truth for the repo layout.
- `logs/` is intentionally noisy and changes often; it is runtime output, not source structure.
- `agents/skills/` exists in the repo, but it supports agent workflows rather than the shipped AHK automation itself.
