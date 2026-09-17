#!/bin/sh
# Install the xSquad skills for discovery by Claude Code / DSH-style agents.
#
# Usage:
#   ./install.sh                 # link all six skills into ~/.claude/skills
#   ./install.sh <skills-dir>    # link into a custom skills directory
#   CORE_ONLY=1 ./install.sh     # link only the core xsquad skill, skip the command wrappers
#
# The package folder itself stays where it is; this only creates symlinks. Re-run after
# moving the package. (Prefer `npx skills add <owner>/<repo>` for skills.sh installs —
# it discovers all six skills from the repo layout directly.)
set -eu

SKILLS_DIR="${1:-$HOME/.claude/skills}"
PKG="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$SKILLS_DIR"

# Every skill in skills/ — the core xsquad skill plus the command wrapper skills.
if [ "${CORE_ONLY:-0}" != "1" ]; then
  targets="$PKG"/skills/*/SKILL.md
else
  targets="$PKG"/skills/xsquad/SKILL.md
fi

for skill in $targets; do
  skill_dir="$(cd "$(dirname "$skill")" && pwd)"
  name="$(sed -n 's/^name: *//p' "$skill" | head -1)"
  [ -n "$name" ] || continue
  ln -sfn "$skill_dir" "$SKILLS_DIR/$name"
  echo "linked $name"
done

echo "Installed xSquad skills into $SKILLS_DIR. Restart the session so the skill catalog picks them up."