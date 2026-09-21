# Classifier pre-pass — bulk triage without reading raw output

classifier.dev is a zero-shot classification API. Its whole point for xSquad: when
**reading the input is the expensive part**, bucket it with one cheap HTTP call and read
only what survives. The orchestrator and every subagent can run it.

## The rule

Classify when you'd otherwise read **more than ~5 items** of raw output into context.
Below that, judge it yourself — the classifier call costs more attention than reading
three lines. Classification never replaces judgment: it decides *what to read*, never
*what to conclude*. You still read anything you must quote, fix, or act on in detail.

## How to run it

```sh
# from the project root; script ships with the skill (next to SKILL.md: scripts/)
skills-path/xsquad/scripts/classify.sh "product bug, validator drift, environment blocker, unclear" \
  .xsquad/runs/<run-id>/evidence/core/test-tail.txt
```

- Input: one classification per non-empty line — `cat`/pipe files, or pass them as args.
- Output: TSV, input order — `<label>\t<confidence>\t<text prefix>`.
- Options: `--tier smart` (reasoning re-ask below 0.7 confidence; slower), `--instructions`
  (extra criteria, e.g. "judge only the validator's own error text"), `--full` (no prefix
  truncation), `--help`.
- Auth: `CLASSIFIER_DEV_API_KEY` from the environment or the project-root `.env` —
  optional; keyless traffic works. Don't classify secrets. Text is never stored by
  classifier.dev; 1,000 inputs/call, 32k chars each; fast tier 3,000/min, 20,000/day.
- Custom calls without the script:
  `curl -X POST https://classifier.dev/v1/classify -H "Content-Type: application/json" \
  -d '{"labels":[...],"inputs":[...],"tier":"fast"}'` (set a real `User-Agent` header).

## Confidence policy

Confidence is calibrated accuracy *among the supplied labels* — it says which label is
right, not whether any label applies.

- **≥ 0.9** — act on the bucket without reading further (measured ~82% correct at ≥0.9).
- **0.5–0.9** — re-ask those lines with `--tier smart` when few, or read them yourself.
- **< 0.5** — the label is a coin flip; read the line yourself.

Every call returns *one of your labels* — there is no implicit "none of the above".
When a line might fit no bucket, add an explicit escape label (`unclear`, `none`).
Use descriptive label names ("validator drift" beats "drift"); they're read
semantically.

## Where it plugs in

| Step | Labels | What it saves |
|---|---|---|
| Validator failure triage (`validator-run.md` §3) | `product bug, validator drift, environment blocker, unclear` | Read failure tails in bulk, act on settled buckets, read only `unclear`/low-confidence |
| Subagent log gate (SKILL.md §4) | `finished successfully, failed, ambiguous` | Skip reading `log-<task>.txt` entirely when the tail classifies cleanly |
| Report ingestion (SKILL.md §4) | `clean, deviations, hidden gap, unclear` | Rank which reports need scrutiny first |
| Review synthesis (`code-review.md` §3) | task names from the plan + `unclear` | Mechanically bucket findings per footprint for fix briefs; also cross-check priority (`high, medium, low`) |
| Validator-update triage (`validator-update.md`) | `spec drift, harness gap, product gap, unclear` | Bucket mid-run drift findings before reconciling |
| MEMORY.md candidates (SKILL.md §7) | `durable lesson, one-off, unclear` | Filter learnings worth persisting |

Standard label sets live in the table — reuse them verbatim so results stay comparable
across runs.

## Never classify

- Fewer than ~5 items (decide yourself).
- Text you must quote or reason about in depth anyway (e.g. a finding you're about to
  write a fix brief for) — classify the *rest* of the batch, read that one.
- Secrets, credentials, tokens (the key itself included).