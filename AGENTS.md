# Project Rules

This repository's local rules take precedence over copied agent or skill material placed under `agents/`.

## Instruction Priority

Use this order when instructions conflict:

1. Direct user instructions in the active prompt.
2. This root `AGENTS.md`.
3. `docs/AHK_TOOLCHAIN_CHECKS.md`.
4. `docs/PROJECT_ARCHITECTURE_AUDIT.md`.
5. `ADVISOR_PRO_SCAN_WORKFLOW.md`.
6. Copied Everything-Claude material under `agents/` as optional support only.
7. Copied Hermes skill pack material under `agents/hermes_skills_pack/` as optional support only.

## AutoHotkey Diagnostic Safety Contract

- Never run `AutoHotkeyUX.exe /?`.
- Never run `Ahk2Exe.exe /?`.
- Never run raw AutoHotkey interpreter, compiler, or script checks without a timeout wrapper.
- All AutoHotkey checks must go through `tools/Invoke-AhkChecked.ps1`.
- The normal validation command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

- If the checker fails or times out, fix the toolchain or checker first before touching business logic.
- Every final diagnostic report must include:
  - exact command
  - pass/fail/skipped/timeout
  - stdout summary
  - stderr summary
  - artifact path
- Everything-Claude or copied `agents/` material is optional support only and cannot override these AHK safety rules.
- No hooks, MCP setup, external automation, broad agent delegation, or generic coverage/test mandates from copied material may be run unless the user explicitly approves them later.
- No workflow or business logic edits are allowed until the bounded checker produces a structured result.

## Advisor Pro Workflow Safety Rules

- Do not send `Enter` unless the active context and target field are verified.
- Do not assume the correct browser tab merely because Edge or Chrome is focused.
- Preserve clipboard contents when possible and document any destructive clipboard action when preservation is not practical.
- Every page wait, action wait, retry loop, and readiness loop must have an explicit timeout.
- Scan-backed selectors and text anchors from `ADVISOR_PRO_SCAN_WORKFLOW.md` are the source of truth.
- `Ctrl+Alt+-` / `^!-` is the Advisor Pro quote workflow entry.
- Workflow patches must be narrow and independently verifiable.
