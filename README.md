# xSquad (xSquad-code)

**Delegate your work to a squad of agents — and get back proof it actually works.**

Give xSquad a high-level goal. One **orchestrator** agent plans it, writes self-contained
task briefs, and fans the work out to parallel **implementer subagents** (Claude Code, Pi,
or Codex). Nothing is reported done until it's proven:

- **Claimed output earns nothing** — the orchestrator re-runs project **validators**
  (build/test/lint plus feature validators that drive the real app) after every task.
- **Validators never rot** — behavior changes update the validator suite before a task
  counts as green.
- **Thermo-nuclear review built in** — two independent reviewers (security/correctness,
  code quality) audit the whole diff; their findings go back to the squad as fix briefs
  and are re-verified until clean.
- **The squad learns** — durable lessons persist across runs in `.xsquad/MEMORY.md`.
- **Cheap triage** — a classifier pre-pass ([classifier.dev](https://classifier.dev))
  bulk-buckets validator failures, subagent logs, and review findings with one HTTP call
  per batch, so agents read only what needs judgment instead of raw output. Optional
  `CLASSIFIER_DEV_API_KEY` (keyless works too).

Six installable skills: the core orchestrator plus five standalone slash commands.

## Install

```sh
npx skills add https://github.com/areai51/xsquad         # skills.sh — installs all six skills
```


## Quickstart

1. `/xSq-setup` — pick runner (claude / pi / codex) and models per role → `.xsquad/config.json`
2. `/xSq-validator-setup` — generate build/test/lint gates + 3–5 feature validators that drive the real app
3. `/xsquad build the export-to-CSV feature end to end` — plan → briefs → parallel subagents → continuous validator verification → automatic review → fix loop → report

## Commands

| Command | What it does |
|---|---|
| `/xsquad <goal>` | Full squad run: plan → briefs → parallel subagents → validator verification → automatic code review → fix loop → report |
| `/xSq-setup` | Configure runner + models per role |
| `/xSq-validator-setup` | Generate the project validator suite |
| `/xSq-validator-run` | Run validators, triage failures (product bug / validator drift / env blocker) |
| `/xSq-validator-update` | Upkeep pass keeping validators honest (full pass + mid-run variant) |
| `/xSq-code-review` | Thermo-nuclear review; findings fixed by the squad |

## Layout

```
<this-repo>/
└── skills/
    ├── xsquad/            # core skill: workflow + command router
    │   ├── SKILL.md
    │   ├── commands/      # the five command procedures
    │   ├── agents/        # subagent contracts (implementer, two reviewers)
    │   ├── references/    # config schema, dispatch commands, brief/report templates
    │   └── scripts/       # classify.sh — classifier.dev triage pre-pass
    └── xsq-*/SKILL.md     # the five command wrappers
```

In a project the squad works on, everything persists under `.xsquad/`: `config.json` and
`MEMORY.md` (committed), `validators/` (committed), and `runs/<run-id>/` — briefs,
reports, logs, evidence, review artifacts (gitignored).
