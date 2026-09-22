# Classifier pre-pass — System One triage and checks on Jev

Jev (TypeSafe AI) is a *System One* model: it takes a state plus typed questions and
returns calibrated answers in ~200 ms, with no text generation. Its whole point for
xSquad: when **reading the input is the expensive part**, let Jev decide what's worth
reading. Two modes:

- **Bucket** — many short items (failure lines, findings) → one label + confidence each.
- **Check** — one large artifact (a report, a log tail) → P(yes) for each statement you
  would otherwise verify by reading it. This is the fast verify gate for subagent work.

The orchestrator and every subagent can run it.

## The rule

Use it when you'd otherwise read **more than ~5 items** of raw output, or a report/log
longer than a screen, into context. Below that, judge it yourself. Classification never
replaces judgment or validators: it decides *what to read*, never *what to conclude*, and
a check never turns a validator failure into a pass. You still read anything you must
quote, fix, or act on in detail.

## How to run it

```sh
# from the project root; script ships with the skill (next to SKILL.md: scripts/)
S=<skills-path>/xsquad/scripts/classify.sh

# bucket: one classification per non-empty line
$S "product bug, validator drift, environment blocker, unclear" \
  .xsquad/runs/<run-id>/evidence/core/test-tail.txt

# check: the whole input is one state; every --check is answered in one call
tail -c 60000 .xsquad/runs/<run-id>/log-<task>.txt | $S \
  --check "The agent finished and wrote its report file" \
  --check "The log shows an unresolved error or crash"
```

- Output (TSV, input order) — bucket: `<label>\t<confidence>\t<text prefix>`;
  check: `<yes|no>\t<P(yes)>\t<statement>`.
- Options: `--instructions` (extra criteria, e.g. "judge only the validator's own error
  text"), `--full` (no prefix truncation), `--backend` (override), `--tier smart`
  (classifier.dev only: reasoning re-ask below 0.7), `--probe`, `--help`.
- Limits: ≤1,000 lines per bucket call; a check's input is capped at the last ~90k chars
  (Jev's state cap is 32k tokens) — the verdict usually lives at the end.

## Backends and keys

Set once in `/xSq-setup` (`commands/setup.md` step 4e); stored as `"classifier"` in
`.xsquad/config.json`, keys in the project-root `.env` (gitignored).

| Backend | Key | Route |
|---|---|---|
| `typesafe` | `TYPESAFE_API_KEY` ([console.typesafe.ai/keys](https://console.typesafe.ai/keys)) | `POST api.typesafe.ai/v1/systemone`, model `jev-latest` |
| `gateway` | `AI_GATEWAY_API_KEY` (or `VERCEL_OIDC_TOKEN` via `vercel env pull`) | Vercel AI Gateway, model `typesafe-ai/jev` — billed through your Vercel team |
| `classifier.dev` | none (`CLASSIFIER_DEV_API_KEY` optional) | keyless Jev proxy; rate-limited per IP — fallback |

Selection: `--backend` > `XSQ_CLASSIFIER_BACKEND` > config `classifier` > whichever key is
present (TypeSafe, then Gateway) > classifier.dev. Store a key without it ever entering
the transcript: `pbpaste | $S --setup typesafe` (or `--setup gateway`), or run
`$S --setup typesafe` in a real terminal for a hidden prompt. Prove it with `$S --probe`.

## Confidence policy

Bucket confidence is calibrated accuracy *among the supplied labels* — it says which
label is right, not whether any label applies.

- **≥ 0.9** — act on the bucket without reading further.
- **0.5–0.9** — read those lines yourself (or `--tier smart` on classifier.dev).
- **< 0.5** — the label is a coin flip; read the line yourself.

Check P(yes) is a probability, not a confidence:

- **≥ 0.9 or ≤ 0.1** — settled; act on it.
- **Between** — Jev is unsure; read the artifact (or the relevant part) yourself.

Every bucket call returns *one of your labels* — there is no implicit "none of the
above". When a line might fit no bucket, add an explicit escape label (`unclear`, `none`).
Use descriptive label names and full-sentence check statements; both are read
semantically. One fact per `--check` — "tests passed and lint is clean" is two checks.

## Where it plugs in

| Step | Mode | Labels / statements | What it saves |
|---|---|---|---|
| Validator failure triage (`validator-run.md` §3) | bucket | `product bug, validator drift, environment blocker, unclear` | Read failure tails in bulk, act on settled buckets, read only `unclear`/low-confidence |
| Subagent log gate (SKILL.md §4) | check | "The agent finished and wrote its report file"; "The log shows an unresolved error or crash" | Skip reading `log-<task>.txt` entirely when both settle |
| Report verify gate (SKILL.md §4) | check | one statement per brief acceptance criterion + "The report states a deviation from the brief" + "The report claims validators passed" | Decide which reports need a full read before re-running validators |
| Review synthesis (`code-review.md` §3) | bucket | task names from the plan + `unclear` | Mechanically bucket findings per footprint for fix briefs; also cross-check priority (`high, medium, low`) |
| Validator-update triage (`validator-update.md`) | bucket | `spec drift, harness gap, product gap, unclear` | Bucket mid-run drift findings before reconciling |
| MEMORY.md candidates (SKILL.md §7) | bucket | `durable lesson, one-off, unclear` | Filter learnings worth persisting |

Standard label sets and statements live in the table — reuse them verbatim so results
stay comparable across runs.

## Never classify

- Fewer than ~5 items (decide yourself).
- Text you must quote or reason about in depth anyway (e.g. a finding you're about to
  write a fix brief for) — classify the *rest* of the batch, read that one.
- Secrets, credentials, tokens (the key itself included).
