---
name: xsq-validator-setup
description: Generate the project-local xSquad validator suite under .xsquad/validators/ — core build/test/lint gates plus feature validators that drive the real app with launch/doctor/drive/pass-criteria/evidence/cleanup sections. Use for /xSq-validator-setup, /xsq-validator-setup, "create xsquad validators", "set up the validator suite".
---

# /xSq-validator-setup

This is the validator-suite generator command of the **xSquad** skill. This file lives
inside the xSquad package (the sibling `xsquad/` skill folder, which holds `SKILL.md`, `commands/`, `agents/`,
`references/`).

Read `../xsquad/commands/validator-setup.md` from the sibling `xsquad` skill folder — one level up from this file
(`xsquad/commands/validator-setup.md`) — and follow that procedure exactly. It
interviews the repo (not the user), generates core validators (build/test/lint) and top
feature validators, proves every validator once before handover, and writes the
`.xsquad/validators/README.md` index.

If the package cannot be located from this file's own path, ask the user for the xSquad
package path; do not improvise the procedure.