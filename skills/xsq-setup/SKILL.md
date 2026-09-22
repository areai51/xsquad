---
name: xsq-setup
description: Configure xSquad squad models per role (orchestrator, implementer subagents, reviewers) from the model lists of Claude Code, Pi, or Codex, write .xsquad/config.json, then automatically set up the validator suite (/xSq-validator-setup) in the same pass when none exists yet. Use for /xSq-setup, /xsq-setup, "configure xsquad models", "pick squad models", "set up xsquad".
---

# /xSq-setup

This is the model-configuration command of the **xSquad** skill. This file lives inside
the xSquad package (the sibling `xsquad/` skill folder, which holds `SKILL.md`, `commands/`, `agents/`, `references/`).

Read `../xsquad/commands/setup.md` from the sibling `xsquad` skill folder — one level up from this file
(`xsquad/commands/setup.md`) — and follow that procedure exactly. It detects installed
runners, enumerates each one's model list (pi: `pi --list-models`; codex: config.toml +
docs + probe; claude: aliases + probe), asks for the per-role models and the Jev classifier
backend (TypeSafe API key, Vercel AI Gateway, or keyless), validates every slug and the
classifier key, and writes `.xsquad/config.json`. As its final phase it chains
`commands/validator-setup.md` — if the project has no validator suite yet, the same pass
generates and proves it (no second invocation needed).

If the package cannot be located from this file's own path, ask the user for the xSquad
package path; do not improvise the procedure.