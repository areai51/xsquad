#!/bin/sh
# structure-check.sh — xSquad repo's "build" gate (docs package, no compiler).
# Proves the six-skill package is structurally sound: every required file exists,
# every SKILL.md has frontmatter whose name matches its directory, and every
# relative path cited inside skills/xsquad/** resolves to a real file.
# Usage: .xsquad/validators/scripts/structure-check.sh   (run from repo root)
# Exit 0 + "structure OK: ..." on pass; exit 1 with a listed failure otherwise.
set -eu
cd "$(dirname "$0")/../../.."   # repo root

fail() { echo "structure FAIL: $1" >&2; exit 1; }

# 1. Required files (six skills + all support files of the core skill)
required="skills/xsq-setup/SKILL.md skills/xsquad/SKILL.md skills/xsq-code-review/SKILL.md
skills/xsq-validator-setup/SKILL.md skills/xsq-validator-run/SKILL.md
skills/xsq-validator-update/SKILL.md
skills/xsquad/commands/setup.md skills/xsquad/commands/validator-setup.md
skills/xsquad/commands/validator-run.md skills/xsquad/commands/validator-update.md
skills/xsquad/commands/code-review.md
skills/xsquad/agents/implementer.md skills/xsquad/agents/reviewer-security.md
skills/xsquad/agents/reviewer-quality.md
skills/xsquad/references/config.md skills/xsquad/references/classifier.md
skills/xsquad/references/brief-and-report.md
skills/xsquad/scripts/classify.sh skills/xsquad/scripts/classify.py
install.sh README.md"
for f in $required; do [ -f "$f" ] || fail "missing file: $f"; done

# 2. Frontmatter: name matches directory, description present
for skill in skills/*/SKILL.md; do
  dir=$(basename "$(dirname "$skill")")
  name=$(sed -n 's/^name: *//p' "$skill" | head -1 | tr -d ' ')
  [ "$name" = "$dir" ] || fail "SKILL.md name '$name' != dir '$dir'"
  grep -q '^description:' "$skill" || fail "$skill: no description"
done

# 3. Compilable: python compiles, shell scripts parse
python3 -m py_compile skills/xsquad/scripts/classify.py || fail "classify.py does not compile"
sh -n skills/xsquad/scripts/classify.sh || fail "classify.sh: syntax error"
sh -n install.sh || fail "install.sh: syntax error"

# 4. Cross-references inside skills/xsquad/** resolve (path-start boundary so
#    mentions like ~/.agents/skills/xsquad/ are not mistaken for repo-relative refs)
refs=$(grep -rhoE '(^|[^A-Za-z0-9._~-])(references|commands|agents|scripts)/[A-Za-z0-9._/-]+' skills/xsquad --include='*.md' \
  | sed -E 's/^([^A-Za-z0-9])//' | sort -u)
[ -n "$refs" ] || fail "no cross-references found (extraction broken?)"
for ref in $refs; do
  [ -f "skills/xsquad/$ref" ] || fail "broken reference: $ref"
done
count=$(echo "$refs" | wc -l | tr -d ' ')

echo "structure OK: 6 skills, 5 commands, 3 agents, 3 references, $count cross-refs resolved"