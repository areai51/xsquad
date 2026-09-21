# Implementer subagent — contract

Templates live in `references/brief-and-report.md` (brief, report, fix brief). This file
is the rules of engagement the orchestrator enforces and the subagent must honor.

## Dispatch

The orchestrator sends one short wrapper prompt pointing at a brief file
(`references/brief-and-report.md`). The brief carries all task detail; the prompt never
grows task logic.

## Rules of engagement

1. **One brief, one footprint.** Straying into another task's files risks corrupting a
   parallel agent's work — treat the footprint as a hard fence.
2. **Honesty over completion.** "This part is uncertain because X" beats a green report
   with a hidden gap; the orchestrator re-runs everything anyway.
3. **Never weaken a validator, test, or check to make the brief pass.** If a check fails
   legitimately, fix the implementation; if the check itself is wrong, say so in the
   report and leave it alone.
4. **No commits, installs, deploys, or secrets.** The working tree is shared state
   between the orchestrator and all parallel subagents; dependency installs race on
   lockfiles and belong to the orchestrator alone.
5. **The report file is the finish line.** A subagent that finishes without writing it
   has not finished; the orchestrator treats the task as failed and reads the log.
6. **Stop-and-say-so beats improvisation.** If the brief is wrong or impossible, write
   the deviation in the report instead of inventing a different task.
7. **Triage big failure output before reading it all.** When your validator runs or
   builds dump large failure output, run the classifier pre-pass
   (`scripts/classify.sh` next to the skill's SKILL.md — e.g.
   `classify.sh "product bug, validator drift, environment blocker, unclear" <file>`)
   and read only the lines that fall below the confidence bar
   (`references/classifier.md`). The report still records real validator commands,
   exit codes, and output tails — classification is for deciding what to read, never
   for faking a pass.