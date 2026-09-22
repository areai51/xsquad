#!/bin/sh
# behavior-tests.sh — offline behavior tests for classify.sh and install.sh.
# Runs entirely in a throwaway temp dir; never touches the repo's real .env,
# never hits the network. See test.md for the case list and pass line.
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
CLASSIFY="$REPO/skills/xsquad/scripts/classify.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
n=0; failed=""

# --- case 1: no args -> usage on stdout/stderr, exit 1
n=$((n+1))
( cd "$TMP" && "$CLASSIFY" >"$TMP/o" 2>"$TMP/e" )
rc=$?
if [ $rc -eq 1 ] && grep -q "Usage:" "$TMP/o" "$TMP/e"; then echo "case $n: no-args-usage ok"
else echo "case $n: no-args-usage FAIL: rc=$rc" >&2; failed="$failed $n"; fi

# --- case 2: unknown backend -> exit 2, "unknown backend"
n=$((n+1))
( cd "$TMP" && "$CLASSIFY" --backend bogus a,b </dev/null >"$TMP/o" 2>"$TMP/e" )
rc=$?
if [ $rc -eq 2 ] && grep -q "unknown backend" "$TMP/e"; then echo "case $n: unknown-backend ok"
else echo "case $n: unknown-backend FAIL: rc=$rc $(cat "$TMP/e")" >&2; failed="$failed $n"; fi

# --- case 3: single label -> exit 1, "need at least 2 labels" (usage error, not arg-parse)
n=$((n+1))
( cd "$TMP" && printf 'hello world\n' | "$CLASSIFY" onlylabel >"$TMP/o" 2>"$TMP/e" )
rc=$?
if [ $rc -eq 1 ] && grep -q "need at least 2 labels" "$TMP/e"; then echo "case $n: single-label ok"
else echo "case $n: single-label FAIL: rc=$rc $(cat "$TMP/e")" >&2; failed="$failed $n"; fi

# --- case 4: labels + --check together -> exit 2, "use either"
n=$((n+1))
( cd "$TMP" && printf 'x\n' | "$CLASSIFY" a,b --check "is it x" >"$TMP/o" 2>"$TMP/e" )
rc=$?
if [ $rc -eq 2 ] && grep -q "use either" "$TMP/e"; then echo "case $n: labels-plus-check ok"
else echo "case $n: labels-plus-check FAIL: rc=$rc $(cat "$TMP/e")" >&2; failed="$failed $n"; fi

# --- case 5: --setup gateway with empty stdin -> exit 1, "no key given"
n=$((n+1))
( cd "$TMP" && "$CLASSIFY" --setup gateway </dev/null >"$TMP/o" 2>"$TMP/e" )
rc=$?
if [ $rc -eq 1 ] && grep -q "no key given" "$TMP/e"; then echo "case $n: setup-gateway-nokey ok"
else echo "case $n: setup-gateway-nokey FAIL: rc=$rc $(cat "$TMP/e")" >&2; failed="$failed $n"; fi

# --- case 6: --setup classifier.dev with piped key -> .env mode 600, key not echoed
n=$((n+1))
mkdir -p "$TMP/setup6" && cd "$TMP/setup6" &&
  printf 'fake-key-for-test-123\n' | "$CLASSIFY" --setup classifier.dev >"$TMP/o" 2>"$TMP/e"
rc=$?
keyfile="$TMP/setup6/.env"
perm=$(stat -f '%Lp' "$keyfile" 2>/dev/null || stat -c '%a' "$keyfile" 2>/dev/null)
if [ $rc -eq 0 ] && [ "$perm" = "600" ] \
   && grep -q '^CLASSIFIER_DEV_API_KEY=fake-key-for-test-123$' "$keyfile" \
   && ! grep -q 'fake-key-for-test-123' "$TMP/o" "$TMP/e"; then
  echo "case $n: setup-writes-env ok"
else
  echo "case $n: setup-writes-env FAIL: rc=$rc perm=$perm" >&2; failed="$failed $n"
fi

# --- case 7: setup rewrites existing .xsquad/config.json classifier field
n=$((n+1))
mkdir -p "$TMP/setup7/.xsquad" && cd "$TMP/setup7" &&
  printf '{"runner":"claude"}\n' > .xsquad/config.json &&
  printf 'fake-key-for-test-123\n' | "$CLASSIFY" --setup classifier.dev >"$TMP/o" 2>"$TMP/e"
rc=$?
if [ $rc -eq 0 ] && python3 -c '
import json,sys
d=json.load(open(".xsquad/config.json"))
sys.exit(0 if d.get("classifier")=="classifier.dev" and d.get("runner")=="claude" else 1)'
then echo "case $n: setup-updates-config ok"
else echo "case $n: setup-updates-config FAIL: rc=$rc" >&2; failed="$failed $n"; fi

# --- case 8: install.sh into temp dir (full = 6, CORE_ONLY = 1)
n=$((n+1))
mkdir -p "$TMP/skills-full" "$TMP/skills-core"
full_out=$(cd "$REPO" && ./install.sh "$TMP/skills-full")
core_out=$(cd "$REPO" && CORE_ONLY=1 ./install.sh "$TMP/skills-core")
full_n=$(ls "$TMP/skills-full" | wc -l | tr -d ' ')
core_n=$(ls "$TMP/skills-core" | wc -l | tr -d ' ')
resolved=yes
for link in "$TMP"/skills-full/*; do
  [ -e "$link" ] || resolved=no   # symlink target exists (resolves into repo)
done
if [ "$full_n" = "6" ] && [ "$core_n" = "1" ] && [ "$resolved" = "yes" ] \
   && [ -e "$TMP/skills-core/xsquad/SKILL.md" ]; then
  echo "case $n: install-links ok"
else
  echo "case $n: install-links FAIL: full=$full_n core=$core_n resolved=$resolved" >&2
  failed="$failed $n"
fi

# --- verdict
if [ -z "$failed" ]; then
  echo "behavior OK: 8/8 cases passed"
else
  echo "behavior FAIL: failed cases:$failed" >&2
  exit 1
fi