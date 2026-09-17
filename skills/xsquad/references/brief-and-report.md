# Brief, report, and fix-brief contracts

Canonical templates for everything the orchestrator writes and reads during a run. All
files live in `.xsquad/runs/<run-id>/`. The subagent-facing rules of engagement are in
`agents/implementer.md`; this file is the orchestrator's authoring spec.

## Dispatch wrapper (the only free text sent to a subagent)

```text
You are an xSquad implementer subagent. Read <run-dir>/brief-<task>.md and complete that
task exactly. Stay within the files and directories it names. Follow its Constraints
section literally. When finished, write <run-dir>/report-<task>.md per the brief's Report
section — that report is the only way the orchestrator learns you finished. Do not
commit, do not install dependencies, do not deploy, do not touch secrets, and do not edit
files outside your footprint (that includes architecture docs, validators, other tasks'
files, and .xsquad/). Do not spawn further agents.
```

The wrapper is the CLI prompt argument (or stdin); the brief carries all task detail so
the prompt stays short and shell-safe.

## Task brief (`brief-<task>.md`)

Self-contained — the subagent has never seen the goal, the repo, or the plan.

```markdown
# Brief: <task-name>

## Goal
What done looks like, in one paragraph, from the user's point of view.

## Context
Everything the agent cannot discover from the repo itself: the architecture-doc pointer,
cross-task contracts it must honor, exact model/API shapes it must match, gotchas from
.xsquad/MEMORY.md that apply here.

## Exact changes
File-level: which files to create/edit and what goes in them.

## Constraints
- Allowed: <paths>
- Forbidden: <shared files, lockfiles, root config, architecture docs, validators, .xsquad/>
- No dependency installs, no git commits, no deploys, no secrets.
- If the brief turns out to be wrong or impossible, stop and say so in the report —
  do not improvise a different task.

## Verify
Validators that must pass, by name (see .xsquad/validators/README.md), plus any
task-specific command and what output counts as passing. Run them and record the real
output — the orchestrator re-runs everything; claimed output earns nothing.

## Report
When finished, write <report path>: what changed (file:line level), validator commands
run with actual results, anything skipped or uncertain, and any surprise that affects
other tasks.
```

Rules: reference the architecture doc instead of restating it; include what the agent
can't discover; footprints of parallel briefs must be disjoint; shared files are never in
a brief.

## Report (`report-<task>.md`)

```markdown
# Report: <task-name>

## What changed
File by file, what was done and why (one line each).

## Validator results
Command, exit code, and a short output tail for each validator run.

## Deviations
Anything that differs from the brief, anything skipped, anything uncertain, and any
file touched outside the named set (this should be empty).
```

No report file → the task failed; read `log-<task>.txt` and re-dispatch with a sharper
brief (`brief-<task>-r2.md`), folding in what the log revealed.

## Fix brief (`brief-<task>-r2.md`, or review fix briefs)

Same five sections as a task brief, plus:

- **Source** — where the work comes from: round-2 of task `<task>`, or review finding
  `<id>` from `review-findings.md` (quote the finding verbatim: priority, file:line,
  description).
- **Required fix** — the concrete fix direction from the reviewer/synthesis, as a
  directive, not a suggestion. If you disagree with the finding, argue it in the report
  with evidence — do not silently ignore it.
- **Verification** — the validators that must pass afterwards, named; plus "the fix must
  not regress any other validator" and, for review fixes, "the change must resolve the
  finding without introducing a new one."

Review fix briefs stay footprint-disjoint like task briefs; a finding that touches a
shared file is fixed by the orchestrator itself, not dispatched.