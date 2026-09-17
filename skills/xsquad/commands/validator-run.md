# /xSq-validator-run — run the validator suite

Execute the project's validators in `.xsquad/validators/` and report PASS/FAIL per
validator with evidence paths. This command runs standalone, and it is also the
orchestrator's verification gate: during a squad run the orchestrator invokes this
procedure continuously — per task as reports land, and again after every fix round — and
keeps validators up to date as behavior changes (mid-run variant in
`commands/validator-update.md`).

## Modes

- **Full suite** (standalone `/xSq-validator-run`): run everything.
- **Scoped** (orchestrator mid-run): run only the validators named by the task's brief.
  Say which mode you are in.

## 0. Locate the target

Read `.xsquad/validators/README.md` and glob its sibling specs. No index or no validators →
stop and point at `/xSq-validator-setup` instead of inventing checks on the spot.

## 1. Core wave — fast gates first

Run build, then test, then lint specs in order (a broken build invalidates everything
downstream; stop there and report). Each is a plain command from the spec — no app to
launch. Capture exit codes and tails of output as evidence under
`.xsquad/runs/<run-id>/evidence/core/` when running inside a squad run; standalone runs
report inline.

## 2. Feature wave — drive the real app

For each feature validator (serially unless specs say instances are isolated):

1. **Launch** exactly as the spec says; wait for its readiness signal.
2. **Doctor** before the first drive. Doctor again after any drive that failed or did
   something surprising; if doctor can't see the failure (a wedged UI state on a healthy
   process), reset to a known state or relaunch rather than hoping. A doctor failure
   caused by skill drift is drift — note it for triage, don't force the drive.
3. **Drive** the recipe and judge against the **Pass criteria** — the observable end
   state, side effects included.
4. **Capture evidence** at the spec's named location.
5. **Clean up** what this drive started; evidence survives.

Hold three invariants the whole wave, whatever the failure:

1. never drive an instance you haven't health-checked since it last did something
   surprising;
2. evidence captured so far survives every cleanup, checked at its named location, not
   assumed;
3. nothing a drive started outlives its usefulness — failed-iteration residue is cleaned
   whether the session is stuck, exited, or shared (for a shared instance, clean the
   residue, not the instance).

## 3. Triage every failure

- **Product bug** — the app doesn't do what the spec says it should. Record precisely:
  what was driven, what was expected, what happened, with evidence paths. During a squad
  run this becomes a fix brief for an implementer subagent; standalone, hand it to the
  user.
- **Validator drift** — the app changed and the spec no longer describes it (wrong
  selector, moved route, renamed command). Verify against source that the app is right
  and the spec is stale, fix the spec (and any helper script), re-drive once, and mark
  the correction in `.xsquad/validators/README.md`. Standalone: only fix drift you can
  prove; anything uncertain goes to `/xSq-validator-update`.
- **Environment blocker** — auth, entitlement, port conflict, missing external state.
  Report the concrete prerequisite; don't guess a workaround that fakes a pass.

Never weaken a validator to make it green. A passing validator must still prove the
original user-POV behavior.

## 4. Report

One line per validator — `PASS` / `FAIL (product)` / `FAIL (drift, fixed)` /
`FAIL (env)` / `SKIP (unproven prerequisite: …)` — plus evidence paths, triage notes, and
the outcome:

- **clean** — everything passed.
- **changed** — fixes shipped (validator drift corrected); list them.
- **blocked** — coverage could not finish; say exactly what blocked it.