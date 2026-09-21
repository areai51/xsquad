# /xSq-code-review — thermo-nuclear review of the work product

A comprehensive security-and-correctness audit plus a strict maintainability audit of the
squad's work product, run as two parallel reviewer subagents, synthesized, and — during a
squad run — fixed by the implementer subagents in a loop until clean. The orchestrator
runs this automatically the moment every task is verified green (SKILL.md step 5); it also
runs standalone for `/xSq-code-review` on any branch or diff.

## 1. Scope the review

- **During a squad run:** the run's base is where the run started (`git stash create` or
  the recorded start commit in `plan.md`); the diff is everything the squad changed.
- **Standalone:** the checked-out branch's diff — `git merge-base <default-branch> HEAD`
  unless the user names a base.
- Gather `git diff <base>` (stat first, then full) and the full contents of changed files.
  Either run git directly or launch two read-only collector subagents in parallel (diff
  collector + file-contents collector) when the diff is large. Write the context to
  `.xsquad/runs/<run-id>/review-context/` (standalone: a temp dir) so reviewers read
  instead of re-collecting.

## 2. Launch both reviewers in parallel

In one message, start both as background subagents (`run_in_background: true`), using the
configured reviewer model:

- **Security/correctness reviewer** — prompt: `agents/reviewer-security.md`.
- **Code-quality reviewer** — prompt: `agents/reviewer-quality.md`.

Pass each the same scoped context: the goal, the diff, changed-file contents, and the
run's task/footprint map. Ask for prioritized findings with file:line evidence. Reviewers
never edit code and never spawn nested subagents.

## 3. Synthesize

After both finish, write `.xsquad/runs/<run-id>/review-findings.md`:

- Findings first, deduplicated across reviewers; weight overlapping findings more heavily
  (two independent reviewers found it → higher confidence), resolve disagreements with
  your own judgment after reading the code yourself.
- Before clustering fix briefs, run the classifier pre-pass over the combined findings
  (`references/classifier.md`): bucket each finding by task footprint (labels = task
  names from the plan + `unclear`) so footprint-disjoint grouping is mechanical, and
  cross-check each priority against the reviewer's (`high, medium, low` — a mismatch
  flags the finding for your own read). Findings landing in `unclear` are the only ones
  you must read in full to place.
- Each finding: priority (high/medium/low), file:line, one-paragraph description with
  evidence, and the fix direction. Attribute sourced items (e.g. PR-discussion findings).
- Keep summaries brief; a smaller number of high-conviction findings beats a long list of
  nits.

## 4. Fix loop — findings go back to the squad

The review's output is not a report to admire; it is input to the implementers:

1. Cluster findings into **footprint-disjoint fix briefs** (template:
   `references/brief-and-report.md`, section "Fix brief"). A brief states the finding,
   the required fix, the constraints, and which validators must pass afterwards.
2. Dispatch the fix briefs to implementer subagents (the same runner and model config).
3. Re-run the validators for each fixed footprint yourself (`/xSq-validator-run`,
   scoped), plus the core gates — a fix that breaks a validator is not a fix.
4. Re-run the review when fixes were substantial (structural changes, security fixes);
   a fresh reviewer pass with the same context confirms the fixes and catches regressions
   the fixes introduced. Small mechanical fixes need only a targeted re-check of the
   specific findings.
5. Loop until a review pass returns no medium-or-high findings, or the user explicitly
   accepts a finding (record the acceptance in `review-findings.md`).

Low findings may be listed as accepted-or-backlog in the final report rather than fixed,
at your judgment.

## 5. Verdict

End with the unified verdict: highest-signal findings and their resolution, what was
fixed with validator proof, anything remaining with severity, and remaining uncertainty.
During a squad run this feeds the final report (SKILL.md step 7); append one dated line
about the review round to `.xsquad/MEMORY.md`.