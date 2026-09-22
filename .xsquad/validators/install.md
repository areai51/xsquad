# install.md — feature validator (install.sh skill linking)

## What it proves

A user can install the six xSquad skills for discovery by Claude Code: `install.sh`
symlinks every skill in `skills/` into a chosen skills dir, naming each link from the
SKILL.md frontmatter, and `CORE_ONLY=1` links just the core `xsquad` skill. Covers any
squad task touching `install.sh`, `skills/*/SKILL.md` frontmatter, or the skills/
directory layout.

## Launch

No server exists — "launch" means running the installer against an isolated target.
Run from the repo root:

```sh
X=$(mktemp -d)
./install.sh "$X/skills"          # full install into an explicit temp dir
```

Ready immediately after exit 0. **Never** run it with no argument in a validator: the
default target is the real `~/.claude/skills`, and `ln -sfn` would overwrite the
user's installed links.

## Doctor

Read-only sanity before driving:

```sh
head -4 skills/xsq-setup/SKILL.md   # name: and description: lines present
ls skills/                          # six skill dirs visible
```

If frontmatter `name:` lines are missing, `install.sh` silently skips that skill — fix
before driving.

## Drive

```sh
./install.sh "$X/skills"                      # full: expect 6 "linked <name>" lines
CORE_ONLY=1 ./install.sh "$X/skills-core"     # core: expect exactly "linked xsquad"
for link in "$X/skills"/*; do readlink "$link"; done   # each resolves into this repo
```

## Pass criteria

- Full install: exit 0; exactly 6 entries in `$X/skills`; each entry's basename equals
  the `name:` in the SKILL.md it points to; `$link/SKILL.md` is readable through the
  symlink (target resolves).
- Core-only: exit 0; exactly 1 entry named `xsquad`; `$X/skills-core/xsquad/SKILL.md`
  readable.
- The user's real `~/.claude/skills` is untouched (compare `ls ~/.claude/skills` before
  and after if in doubt — validators never invoke install.sh without an explicit dir).

## Evidence

Save the install transcript to
`.xsquad/runs/<run-id>/evidence/install/transcript.txt` — the `linked ...` lines plus
`ls -l` of the temp skills dir. Also capture `readlink` output for the six links.

## Cleanup

```sh
rm -rf "$X"
```

Temp dirs are self-contained (symlinks point into the repo, deleting the dir deletes
only the links). Nothing else to stop — no daemons, no ports.

## Gotchas

- `ln -sfn` silently replaces existing links — safe in temp dirs, destructive against
  `~/.claude/skills`. The doctor note about frontmatter matters: a skill whose
  frontmatter `name:` is empty is skipped with no error, so "exit 0" alone proves
  nothing; count the links.
- If the repo was renamed/moved, old symlinks in `~/.claude/skills` dangle — the
  doctor-style check `for l in ~/.claude/skills/xsq*; do readlink -f "$l"; done`
  distinguishes user-install health from repo health, but that's a human concern,
  not this validator's pass criteria.