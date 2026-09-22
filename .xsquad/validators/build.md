# build.md — core validator (structural build gate)

This repo is a docs/skill package: six Claude Code skills in `skills/`, two executable
surfaces (`install.sh`, `skills/xsquad/scripts/classify.sh`), no compiler, no bundler.
The compile-analog gate is a **structural build**: required files exist, SKILL.md
frontmatter is consistent, the Python and shell sources compile/parse, and every
cross-reference inside the core skill resolves to a real file.

## Command

From the repo root:

```sh
.xsquad/validators/scripts/structure-check.sh
```

## Passing output (defined exactly)

Exit code 0 and stdout ending in exactly one line of this shape (numbers may grow as
the package grows):

```
structure OK: 6 skills, 5 commands, 3 agents, 3 references, N cross-refs resolved
```

Any `structure FAIL: <reason>` line on stderr with exit 1 = failing.

## Notes

- Runs in well under a second; fully offline; writes only `__pycache__` next to
  `classify.py` (gitignored via `__pycache__/`).
- Covers: every task that adds, renames, or moves files under `skills/`, or edits
  `classify.py` / the shell scripts. If a new support file is added to
  `skills/xsquad/`, add it to the `required` list in `structure-check.sh` in the same
  task — that is validator upkeep, not scope creep.