# classifier.md — feature validator (Jev classifier pre-pass, classify.sh)

## What it proves

The System One pre-pass works end to end: `classify.sh` buckets text lines into labels
with confidence, checks yes/no statements against a state, probes the backend, and
`--setup` stores a key in `./.env` (mode 600) and points `.xsquad/config.json` at the
backend. Covers any squad task touching `classify.py`/`classify.sh`, backend
selection, or the output contract (TSV).

Network budget: exactly **3 live calls** to `classifier.dev` (keyless, shared per-IP
rate limits) — probe, one classify batch, one check. All other cases are offline and
covered by `test.md`.

## Launch

No server. The script is stateless; CWD is its state (`.env`, `.xsquad/config.json`).
Run live calls from the repo root, where `.xsquad/config.json` pins
`"classifier": "classifier.dev"`:

```sh
SK=skills/xsquad/scripts/classify.sh   # shorthand used below
```

## Doctor

One read-only check that the setup is worth driving:

```sh
$SK --probe
# expect one line:  classifier.dev\tok\tP(yes)=<0..1>\t<n> ms
```

A 401 here means a wrong/other-route key is present (`CLASSIFIER_DEV_API_KEY` in env
or repo `.env`) — fix before driving. This call counts toward the network budget.

## Drive

Real inputs, real subcommands, in this order (2 more live calls):

```sh
# 1) label lines (the validator-failure triage use case)
printf 'npm ERR! Test failed. 5 tests failing\nAll 12 tests passed, lint clean\n' \
  | $SK fail,pass --full
# 2) check statements against a state (the report-verification use case).
#    One --check flag PER statement; a bare word after --check statements would be
#    parsed as an input file.
printf 'task 3 done: export button added; 41/42 tests pass\n' \
  | $SK --check "Does the report claim all tests pass?" \
        --check "Is an export button mentioned?"
```

Offline driving (no budget cost): `--tier smart` is classifier.dev-only, so on
`classifier.dev` it must NOT warn; on other backends it warns to stderr (case covered
in test.md). `--instructions` must appear in the question, observable via a label
change — do not assert on a specific label flip, just that the call succeeds and emits
one TSV row per input line.

## Pass criteria

- Probe: `classifier.dev<tab>ok<tab>P(yes)=<x.xx><tab><n> ms` with 0 <= x <= 1.
- Classify: exactly 2 TSV rows, in input order, each `<label><tab><conf><tab><line>`;
  labels drawn from {fail, pass}; the failing-test line labeled `fail` and the
  passing line labeled `pass` with confidence >= 0.5.
- Check: exactly 2 rows `<yes|no><tab><P(yes)><tab><statement>`; "Does the report
  claim all tests pass?" must be `no` (41/42 is not all) — that distinction is the
  whole point of the pre-pass.
- No key material in any stdout/stderr/evidence: `classify.sh` must never echo the
  key from `--setup` (asserted offline in test.md case 6).

## Evidence

Save all three live outputs (probe, classify, check) as one transcript:
`.xsquad/runs/<run-id>/evidence/classifier/transcript.txt`, plus the command lines
used. Evidence must contain no key values.

## Cleanup

Nothing to tear down — no processes, no files written by the live calls (`.env` and
config are only written by `--setup`, which validators exercise in temp dirs only, per
test.md). Delete any temp dirs created; evidence survives.

## Gotchas

- classifier.dev is keyless with shared per-IP limits: a 429 is rate limiting, not a
  bug. Retry once after ~30 s; if it persists, mark the validator `blocked: rate limit`
  rather than loosening pass criteria.
- Backend selection order: `--backend` > `XSQ_CLASSIFIER_BACKEND` env > config.json
  `classifier` > which key exists. The repo `.env` (gitignored, real keys) is loaded
  automatically — never run live classify from a directory holding an unrelated
  `.env`; if `XSQ_CLASSIFIER_BACKEND` is set in the shell, it overrides config.json
  and can silently switch the route being proven.
- Jev confidence can be `None` → printed as `-`; treat `-` on a check as `no` (the
  script does: p >= 0.5 else no) but flag it in evidence.
- Arg parsing: `--check` takes exactly one statement per flag. A bare positional
  after checks is an input file, and a missing one crashes with a Python
  `FileNotFoundError` traceback rather than classify.sh's usual clean `die()` message
  (observed 2026-09-23; cosmetic, network untouched). Pass every statement via its
  own `--check`.