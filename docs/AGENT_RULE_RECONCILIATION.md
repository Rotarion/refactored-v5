# Agent Rule Reconciliation

Audit date: `2026-04-24`  
Scope: reconcile copied Everything-Claude guidance with this repository's AutoHotkey safety rules before any workflow repair work begins.

## What Was Found

Repo-local instruction and safety files:

- `AGENTS.md`: missing before this reconciliation, now added at repo root
- `docs/AHK_TOOLCHAIN_CHECKS.md`: present
- `docs/PROJECT_ARCHITECTURE_AUDIT.md`: present
- `ADVISOR_PRO_SCAN_WORKFLOW.md`: present

Copied agent material:

- `agents/`: present
- `.claude/`: not present in this repo
- `.codex/`: not present in this repo
- copied Everything-Claude-style material found under `agents/skills/`

Copied material inventory:

- `29` skill directories under `agents/skills/`
- `29` `SKILL.md` files
- `27` `agents/openai.yaml` metadata files

Representative copied skill folders:

- `agents/skills/everything-claude-code/`
- `agents/skills/coding-standards/`
- `agents/skills/security-review/`
- `agents/skills/verification-loop/`
- `agents/skills/documentation-lookup/`
- `agents/skills/deep-research/`
- `agents/skills/mcp-server-patterns/`
- `agents/skills/dmux-workflows/`
- `agents/skills/e2e-testing/`
- `agents/skills/tdd-workflow/`

## Reconciliation Outcome

### Useful For This AHK Repo

Allowed only as optional, human-reviewed support:

- `agents/skills/everything-claude-code/SKILL.md`
  - useful only for understanding where the copied material came from
- `agents/skills/coding-standards/SKILL.md`
  - may provide general writing or organization ideas for documentation and reviews
- `agents/skills/security-review/SKILL.md`
  - may provide optional review prompts when manually auditing safety-sensitive changes
- `agents/skills/verification-loop/SKILL.md`
  - may provide optional verification framing after the checker is proven safe

These files are inspiration only. They do not define executable policy in this repository.

### Ignored Or Downgraded

The following copied material is downgraded to non-authoritative reference only or fully ignored for this repo:

- all `agents/*/agents/openai.yaml` files
  - metadata only, not repo policy
- any copied skill that assumes hooks, cross-platform mirror workflows, releases, package managers, or JS framework conventions
- any copied skill that assumes MCP configuration, including:
  - `deep-research`
  - `documentation-lookup`
  - `mcp-server-patterns`
  - any file mentioning `~/.claude.json` or `~/.codex/config.toml`
- any copied skill that assumes multi-pane or delegated automation, including:
  - `dmux-workflows`
  - workflow/delegation patterns in imported skill docs
- any copied skill that implies broad testing or coverage mandates unrelated to this AHK repo, including:
  - `e2e-testing`
  - `tdd-workflow`
  - `eval-harness`
  - runtime-specific JS/TS skills such as `bun-runtime`, `nextjs-turbopack`, `frontend-patterns`, `backend-patterns`

### Explicitly Prohibited Without Later Approval

No copied agent or rule material may authorize any of the following in this repository unless the user explicitly approves it later:

- hook execution
- MCP setup or use
- external automation
- broad agent delegation
- generic test or coverage mandates
- raw AutoHotkey diagnostics
- raw compiler diagnostics

## Project-Specific Rules That Override Copied Material

The following project-specific rules override all copied Everything-Claude material:

1. direct user instructions for the active task
2. root `AGENTS.md`
3. `docs/AHK_TOOLCHAIN_CHECKS.md`
4. `docs/PROJECT_ARCHITECTURE_AUDIT.md`
5. `ADVISOR_PRO_SCAN_WORKFLOW.md`

Key override points:

- AutoHotkey diagnostics must stay bounded and timeout-backed.
- `AutoHotkeyUX.exe /?` and `Ahk2Exe.exe /?` remain banned.
- No workflow or business logic edits are allowed until the bounded checker produces a structured result.
- Scan-backed Advisor Pro selectors and anchors remain the source of truth for later workflow work.

## Final Instruction Priority Order

1. Direct instructions in the active user prompt.
2. Root `AGENTS.md` for this repo.
3. `docs/AHK_TOOLCHAIN_CHECKS.md`.
4. `docs/PROJECT_ARCHITECTURE_AUDIT.md`.
5. `ADVISOR_PRO_SCAN_WORKFLOW.md`.
6. Copied Everything-Claude material under `agents/` as optional support only.

## Operational Guardrail

The copied `agents/` tree is retained as optional reference material only. It does not change execution policy, does not install repo rules by itself, and must not trigger hooks, MCP, external automation, or raw AHK diagnostics in this repository.
