---
name: xsquad
description: Orchestrator/squad workflow (xSquad-code) — one orchestrator takes a high-level goal, plans it, writes self-contained task briefs, spawns parallel implementer subagents via Claude Code, Pi, or Codex, verifies every task continuously with project validators (and keeps those validators up to date), then runs an automatic thermo-nuclear code review whose findings are fixed by the subagents before any report. Use for /xsquad <goal>, "run the xsquad", "fan this out to the squad", "build this with the squad", or any high-level goal that should be delegated to parallel agents and verified. Also routes its commands /xSq-setup, /xSq-validator-setup, /xSq-validator-run, /xSq-validator-update, /xSq-code-review (standalone wrappers under skills/).
---

# xSquad — orchestrator + verified subagent squad

Give this skill a high-level goal. One **orchestrator** agent (you, the agent running this
skill) plans the work, writes self-contained task briefs, and spawns parallel
**implementer subagents** through Claude Code, Pi, or Codex. The orchestrator owns the
quality gate: it re-runs project **validators** after every task (and keeps those
validators up to date as behavior changes), then automatically runs a two-reviewer
**thermo-nuclear code review** whose findings go back to the subagents as fix briefs.
Nothing is reported done until validators and review are green.

## Roles

- **Orchestrator** — the agent running this skill. Plans, writes briefs, dispatches,
  verifies, reviews, reports. It never implements product code itself and it fixes only
  what no brief can own (a finding touching a shared file).
- **Implementer subagents** — parallel, one brief each; they write code and nothing else,
  never edit architecture/contract docs, never edit validators. Contract:
  `agents/implementer.md`.
- **Reviewer subagents** — two, launched in parallel for the thermo-nuclear review:
  security/correctness and code quality. Rubrics:
  `agents/reviewer-security.md`, `agents/reviewer-quality.md`.
- **Validators:** project-local, deterministic checks in `.xsquad/validators/` that prove a
  task done — fast build/test/lint gates plus feature validators that drive the
  real app. Specs: `commands/validator-setup.md`.

## Commands

| Command | Procedure | What it does |
|---|---|---|
| `/xSq-setup` | `commands/setup.md` | Pick runner + models for orchestrator, subagents, reviewers |
| `/xSq-validator-setup` | `commands/validator-setup.md` | Create the project validator suite |
| `/xSq-validator-run` | `commands/validator-run.md` | Run validators, triage failures |
| `/xSq-validator-update` | `commands/validator-update.md` | Upkeep pass keeping validators honest |
| `/xSq-code-review` | `commands/code-review.md` | Thermo-nuclear review of the work product |

Invoking `/xsquad` and naming a command routes to that procedure with no extra setup;
each command also works standalone via its wrapper skill under `skills/` in the package
repo (see README).

The package (this SKILL.md, `commands/`, `agents/`, `references/`) lives: project
`.claude/skills/xsquad/`, `~/.claude/skills/xsquad/`, or `~/.agents/skills/xsquad/`.
Config and on-disk layout: `references/config.md`.

## Workflow

### 1. Ground

- Read `.xsquad/config.json`. Missing → stop and offer `/xSq-setup` (it takes one pass and
  every dispatch decision depends on it). Do not guess models or runners.
- Read `.xsquad/MEMORY.md` if it exists — learnings from past runs in this project
  (brief lessons, quirks, verify gotchas) apply to this run's plan and briefs.

### 2. Plan

Decompose the goal into tasks whose footprints (files each touches) are disjoint — shared
files are sequenced, never parallelized. For each task, name the validators from
`.xsquad/validators/README.md` that prove it done. No validator suite yet → stop and offer
`/xSq-validator-setup` once. Record the plan in `.xsquad/runs/<run-id>/plan.md`: tasks,
footprints, validators per task, parallel groups. Run ids are `<YYYYMMDD-HHMM-slug>`.

### 3. Brief

One brief per task: `.xsquad/runs/<run-id>/brief-<task>.md`. Template and rules:
`references/brief-and-report.md`. Each brief is **self-contained**: goal, exact changes,
constraints (allowed/forbidden paths), the validators that must pass, and the report
contract. The subagent has never seen the goal, the repo, or the plan — write for that
reader. Parallel briefs' footprints stay disjoint.

### 4. Dispatch and verify continuously

Launch one implementer subagent per brief via the dispatch wrapper and commands in
`references/config.md` (runner and models from config; background, one process per brief,
log to `log-<task>.txt`). As each report lands, re-run that task's validators yourself —
scoped `/xSq-validator-run` (per-task variant) — plus the core gates when the footprint
warrants. Claimed test output earns nothing; the diff is re-proven by the validators.
Triage every failure as product bug (new fix brief), validator drift (fix the validator,
with evidence — mid-run variant of `commands/validator-update.md`), or environment blocker
(report the concrete prerequisite). A subagent with no report file has failed; re-dispatch
with a sharper `brief-<task>-r2.md` folded from its log. Gate large artifacts through the
Jev pre-pass (`references/classifier.md`) — never read a `log-<task>.txt` you can check
first. As each report lands, run one `--check` call over it with a statement per brief
acceptance criterion plus the standard deviation/validators-claimed statements: settled
answers tell you which reports need a full read and which failures to expect; they never
replace re-running the validators.

### 5. Thermo-nuclear review

The moment every task is verified green, run `commands/code-review.md` — automatically,
not on request: two parallel reviewer subagents over the whole run diff, synthesized
prioritized findings, footprint-disjoint fix briefs back to the implementers, re-verified,
looping until the review is clean or the user explicitly accepts a finding. Bucket the
synthesized findings by task footprint with the classifier pre-pass before clustering
fix briefs.

### 6. Keep validators honest

Any task that changed behavior updates the validators covering it before the task counts
as green — the mid-run variant in `commands/validator-update.md` — and never weakens pass
criteria to accommodate a subagent's shortcuts. A behavior regression is a product bug:
fix brief, not spec edit.

### 7. Report

When validators and review are clean, write the final report: what was built, per-task
outcomes with validator proof, the review's verdict, anything remaining with severity, and
remaining uncertainty (template: `references/brief-and-report.md`). Append one dated line
of durable learnings to `.xsquad/MEMORY.md`. Run artifacts stay in the run directory
(gitignored); evidence survives cleanup.