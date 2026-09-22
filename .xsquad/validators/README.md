# Validator index — xSquad skill package

This repo is the xSquad skill source itself: a docs/skill package (six skills under
`skills/`) with two executable surfaces — `install.sh` and
`skills/xsquad/scripts/classify.sh`. There is no app, server, or port; validators are
shell-level and run in seconds. No lint tooling exists in the repo (no config for any
linter), so there is no `lint.md` — syntax-level checks (`py_compile`, `sh -n`) are
folded into `build.md`.

| Name | Kind | Proves | Status | Covers |
|---|---|---|---|---|
| build.md | core | Package structure: 6 skills + support files present, frontmatter name==dir, sources compile/parse, all cross-refs inside skills/xsquad resolve | proven 2026-09-23 | Any task adding/renaming/moving files under skills/, editing classify.py or shell scripts |
| test.md | core | Offline behavior of both executables: 8/8 arg/exit/setup/install cases in throwaway temp dirs (never touches repo .env, no network) | proven 2026-09-23 | classify.sh argument contract, --setup file effects, install.sh linking modes |
| install.md | feature | install.sh links all six skills into an explicit dir (and CORE_ONLY links one), links resolve into the repo | proven 2026-09-23 | install.sh, skills/*/SKILL.md frontmatter, skills/ layout |
| classifier.md | feature | classify.sh live on classifier.dev (3-call budget): probe ok, 2/2 triage labels correct, check verdicts correct ("41/42" ≠ all tests → no) | proven 2026-09-23 | classify.py/classify.sh, backend selection, TSV output contract |

Upkeep: `/xSq-validator-update` re-proves these when the package changes. If a new
support file lands under `skills/xsquad/`, add it to build.md's `required` list in the
same task.

Scratch evidence from the proving run lives in `runs/scratch/evidence/` (gitignored,
like all of `runs/`); real runs keep evidence under `runs/<run-id>/evidence/`.