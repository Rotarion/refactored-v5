# Hermes Skills Pack - Start Here

This pack gives Hermes a concrete operating system tailored to your actual workflow: Allstate quoting, sales follow-up, AHK/browser automation, Notion lead management, compliance risk, and long-term SaaS architecture.

## How to use this pack

### If Hermes is a Custom GPT or similar agent
1. Paste `HERMES_CUSTOM_INSTRUCTIONS_COPY_PASTE.txt` into the main instructions field.
2. Upload `HERMES_MASTER_SKILLS_PACK.docx` as a knowledge document.
3. Upload the individual `skills/*/SKILL.md` files as separate skill/reference docs if your platform supports it.
4. Add `HERMES_MEMORY_SEED.md` to memory or persistent profile notes.

### If Hermes is a Claude Project, Claude Code setup, or local agent folder
1. Put `AGENTS.md` at the project root.
2. Add each folder under `skills/` to your agent skills directory.
3. Keep `templates/` available for repeated workflows.
4. Use `manifest/hermes_skill_manifest.json` as the index.

### Recommended add order
1. `HERMES_CUSTOM_INSTRUCTIONS_COPY_PASTE.txt`
2. `HERMES_MEMORY_SEED.md`
3. `AGENTS.md`
4. Skills 01 through 12
5. Templates

## The design principle
Hermes should not become another chatbot. Hermes should act as your technical chief of staff: it diagnoses state, chooses the highest-leverage move, protects you from compliance and architecture mistakes, and forces execution discipline.
