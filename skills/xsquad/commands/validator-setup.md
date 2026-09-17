# /xSq-validator-setup — create the project validator suite

Every squad project needs a scripted way to prove work is done: fast deterministic checks
(build, test, lint) plus feature validators that drive the real app the way a user would.
This command generates that suite as project-local files under `.xsquad/validators/`,
tailored to the repo. The orchestrator runs these validators after every task and keeps
them up to date; you write them for the next agent, not for a human — they will be read
cold, mid-task, by an agent that has never seen the app.

Validator specs, index shape, and mid-run upkeep: `commands/validator-update.md`.

## 1. Interview the repo, not the user

Answer these from the codebase and only ask the user what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop app, an
  API, a mobile app, a library? A repo can have several; pick the primary one and note
  the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command
  (package scripts, Makefile, README quickstart). Note ports, env vars, seed data, auth.
- **Drive:** how can an agent interact with it programmatically? Existing harnesses first —
  Playwright/Cypress specs, expect scripts, PTY helpers, curl-able endpoints, a debug port.
  Only then pick a generic recipe: browser/CDP for web and Electron, a tmux/PTY harness
  for CLI/TUI, plain HTTP for services.
- **Observe:** what evidence can be captured? Screenshots, terminal transcripts, response
  bodies, logs, exit codes, DB state.
- **Isolate:** can two instances run side by side (ports, data dirs, profiles)? If not,
  say so in the affected validators: refusing to double-drive a shared instance beats
  corrupting the user's session.

If the checkout doesn't build or start as-is, fix that first (or report it precisely)
before generating; validators written against a broken base teach wrong steps. When an
irrelevant missing asset blocks startup (a static dir the API never serves, a sample
config), a validator may create it, clearly marked as verification scaffolding, and remove
it in cleanup.

## 2. Generate core validators

Read the repo's canonical commands and write one spec each for the fast, deterministic
gates, in `.xsquad/validators/`:

- `build.md` — the compile/typecheck command; passing output defined exactly.
- `test.md` — the unit/integration test suite; expected suite count or exit criteria.
- `lint.md` — lint/format/type-check gates, if the repo has them.

Skip a kind only when the repo genuinely has none, and say so in the index.

## 3. Generate feature validators

Create one spec per user-facing feature you can identify (aim for the top 3–5 to start,
from routes, commands, menus, or docs). Each spec `.xsquad/validators/<feature>.md` is
grounded in what the interview actually found (no placeholders left) with these H2s:

- **What it proves** — the user-POV behavior this validator certifies, and which squad
  tasks it covers.
- **Launch** — the exact command that starts the app for verification, and how to tell
  it's ready (a log line, a port answering, a prompt). Include teardown. For a short-lived
  CLI/TUI there is no server to keep alive: launch means build the binary once, then start
  each drive in its own isolated PTY or tmux session.
- **Doctor** — one read-only check that answers "is this instance worth driving?" —
  process up, right version/build, port owned by us, auth valid. Run whenever anything
  looks off.
- **Drive** — the harness recipe with real selectors/commands from this repo, not
  examples. Prefer stable handles (ARIA labels, data attributes, prompt strings, route
  paths) over coordinates and tab order.
- **Pass criteria** — the observable end state that proves the feature works: exercise
  the real user path, not internal setters or test-only endpoints; capture the action and
  the resulting state, not just the final screen; verify side effects (files written, rows
  inserted, messages sent) alongside what's visible; mocks only where a production
  boundary already isolates the external system. When the safe path is a dry-run or test
  mode, verify what it actually skips by observing rather than trusting its name.
- **Evidence** — what to capture for a proof and where it goes
  (`.xsquad/runs/<run-id>/evidence/<feature>/`). Evidence survives cleanup, always.
- **Cleanup** — how to tear down instances the run created. Never kill by process name;
  kill what you started. Cleanup removes instances and scratch state, never the evidence.
- **Gotchas** — flakiness, ordering, shared-state traps observed while proving it.

Any helper script ships in `.xsquad/validators/scripts/`, is executable, and its
invocation is shown in the spec body. A helper the reader has to reverse-engineer is not
a helper.

## 4. Prove every validator before handing it over

Run each validator's own instructions once: launch, doctor, drive (for feature
validators), capture evidence, clean up. After cleanup, confirm the evidence still exists
at the named location — a cleanup that eats the proof fails this step. Fix what fails,
and run the cleanup after every failed iteration too, so broken attempts don't strand
processes and ports. A validator that was never executed is a draft, not a deliverable.

Core validators pass on a clean tree; if one fails on a clean tree, the tree is broken —
report it precisely instead of writing the validator around the breakage.

## 5. Write the index

Create `.xsquad/validators/README.md`: one line per validator — name, kind (core /
feature), what it proves in one sentence, status (`proven <date>` / `unproven` /
`blocked: <reason>`), and the surfaces/tasks it covers. This index is how the orchestrator
picks validators per task and how `/xSq-validator-update` finds drift.

## 6. Offer the upkeep loop

Point the user at `/xSq-validator-run` (run the suite now) and `/xSq-validator-update`
(keep the suite honest as the app changes). The orchestrator also calls both itself
during runs.