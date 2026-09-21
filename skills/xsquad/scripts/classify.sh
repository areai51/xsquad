#!/bin/sh
# classify.sh — xSquad's bulk triage pre-pass via classifier.dev.
#
# Classifies raw text (validator output, subagent logs, review findings) into labels
# with calibrated confidence, so the orchestrator reads only what needs judgment
# instead of pulling large raw output into context.
#
# Usage:
#   classify.sh <labels-csv> [file ...]          # one classification per non-empty line (or stdin)
#   classify.sh <labels-csv> --tier smart ...    # reasoning-model re-ask below 0.7 confidence (slower)
#   classify.sh <labels-csv> --instructions "judge only the validator output" ...
#   classify.sh <labels-csv> --full ...          # print the full line, not an 80-char prefix
#
# Output: one TSV row per input, input order:  <label>\t<confidence>\t<text prefix>
# Auth: CLASSIFIER_DEV_API_KEY from the environment or the project-root .env — optional;
# classifier.dev also serves keyless traffic. Never pass secrets in classified text.
# Limits: 1,000 inputs/call, 32k chars/input; fast tier 3,000/min and 20,000/day per IP.
# Text is never stored or logged by classifier.dev.

set -eu

if [ "$#" -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  [ "$#" -lt 1 ] && exit 1 || exit 0
fi

LABELS=""
TIER=fast
INSTRUCTIONS=""
FULL=0
while [ "$#" -gt 0 ]; do
  case $1 in
    --tier) TIER=$2; shift 2 ;;
    --instructions) INSTRUCTIONS=$2; shift 2 ;;
    --full) FULL=1; shift ;;
    --) shift; break ;;
    -*) echo "classify.sh: unknown option: $1" >&2; exit 2 ;;
    *) if [ -z "$LABELS" ]; then LABELS=$1; else break; fi; shift ;;
  esac
done
[ -n "$LABELS" ] || { echo "classify.sh: missing labels" >&2; exit 2; }

# Load the key from the project-root .env when the environment doesn't have it.
if [ -z "${CLASSIFIER_DEV_API_KEY:-}" ] && [ -f .env ]; then
  KEY=$(sed -n 's/^CLASSIFIER_DEV_API_KEY=//p' .env | head -1 | tr -d '\r')
  [ -n "$KEY" ] && export CLASSIFIER_DEV_API_KEY="$KEY"
fi

TMP=$(mktemp "${TMPDIR:-/tmp}/xsq-classify.XXXXXX")
trap 'rm -f "$TMP"' EXIT

# argv for python: labels, tier, instructions, full-flag — then the text on stdin/files.
{
  printf '%s\n%s\n%s\n%s\n' "$LABELS" "$TIER" "$INSTRUCTIONS" "$FULL"
  cat "$@"
} > "$TMP"

python3 - "$TMP" <<'PY'
import json, os, sys, time, urllib.request

URL = "https://classifier.dev/v1/classify"
CHUNK = 500  # stay well under the 1,000-input cap and be polite on rate limits

with open(sys.argv[1]) as fh:
    labels = fh.readline().rstrip("\n")
    tier = fh.readline().rstrip("\n") or "fast"
    instructions = fh.readline().rstrip("\n")
    full = fh.readline().rstrip("\n") == "1"
    text = fh.read()

lines = [ln for ln in text.splitlines() if ln.strip()]
if not lines:
    sys.exit("classify.sh: no non-empty input lines to classify")
if len(lines) > 1_000:
    sys.exit("classify.sh: over 1,000 inputs; split into several calls")

labels_list = [lb.strip() for lb in labels.split(",") if lb.strip()]
if len(labels_list) < 2:
    sys.exit("classify.sh: need at least 2 labels (comma-separated)")

payload = {"labels": labels_list, "inputs": [], "tier": tier}
if instructions:
    payload["instructions"] = instructions

headers = {"Content-Type": "application/json", "User-Agent": "xsquad-classify/1.0"}
key = os.environ.get("CLASSIFIER_DEV_API_KEY")
if key:
    headers["Authorization"] = f"Bearer {key}"

def post(chunk):
    payload["inputs"] = chunk
    data = json.dumps(payload).encode()
    req = urllib.request.Request(URL, data=data, headers=headers)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.load(resp)["results"]
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < 2:
                time.sleep(2 ** attempt * 5)
                continue
            sys.exit(f"classify.sh: classifier.dev returned HTTP {e.code}: {e.read()[:200]!r}")
        except urllib.error.URLError as e:
            sys.exit(f"classify.sh: cannot reach classifier.dev: {e.reason}")

results = []
for i in range(0, len(lines), CHUNK):
    results.extend(post(lines[i:i + CHUNK]))

if len(results) != len(lines):
    sys.exit(f"classify.sh: expected {len(lines)} results, got {len(results)}")

for line, res in zip(lines, results):
    conf = res.get("confidence")
    conf = "-" if conf is None else f"{conf:.2f}"
    shown = line if full else (line[:77] + "..." if len(line) > 80 else line)
    print(f"{res['label']}\t{conf}\t{shown}")
PY