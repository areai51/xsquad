# /xSq-setup — configure squad models

Configure which models the xSquad squad uses per role, choosing from the model lists
of the coding-agent CLIs installed on this machine: **Claude Code**, **Pi**, or **Codex**.
Writes `.xsquad/config.json`, which every squad run reads. Re-running updates it and stays
idempotent (full overwrite).

Config schema and on-disk layout: `references/config.md` (relative to the xSquad
SKILL.md).

## 1. Detect runners

```sh
command -v claude pi codex ollama
```

Record which are installed. All three are optional, but at least one of claude/pi/codex
must exist to run subagents (or the host harness must offer a native subagent tool).

## 2. Enumerate each runner's model list

Enumerate the model slugs you can actually run. Never write a slug you have not confirmed
is available — confirm by listing or by a live probe (step 5).

- **Pi** — `pi --list-models` prints provider, model id, context, max-out, thinking, images
  for every model pi can reach (the `llama-cpp ... fetch failed` line at the top, if any, is
  a benign local-provider notice). Fuzzy search: `pi --list-models sonnet`. This list is
  authoritative — every id in it counts as confirmed. Pi ids include the provider when
  dispatching: `--provider <p> --model <id>`.
- **Codex** — has no model-list command. Sources, in order: `model` and
  `[model_providers.*]` in `~/.codex/config.toml` (custom providers and the current
  default), then the documented built-ins (e.g. `gpt-5.1-codex-max`, `gpt-5.1-codex`,
  `gpt-5.1-codex-mini`, `gpt-5.1`, `gpt-5.3-codex` — check `codex --version` against the
  current docs). Any candidate not in config.toml must be probed (step 5) before use.
- **Claude Code** — model aliases and full names. Documented aliases include `fable`,
  `opus`, `sonnet`, `haiku` (latest of each family) plus full names like
  `claude-fable-5` / `claude-opus-4-5`. There is no list command: aliases and any full
  slug must be probed (step 5) before use. The special value `inherit` means "the model of
  the session running the orchestrator" and always passes.
- **Ollama-launch (optional, legacy xsquad path)** — if `ollama` is installed and the user
  uses it: `ollama launch claude --model <slug> -- --dangerously-skip-permissions -p "…"`
  launches a Claude Code instance on an ollama-hosted model. Enumerate with
  `ollama model list` if the user wants this path.
- **Native** — if the host harness (Claude Code Task tool, DSH subagent tool) can spawn
  subagents, its model override values (if any) are also candidates; `inherit` always works.

If you cannot detect any models, ask the user to paste the slugs they have access to.

## 3. Load current state

If `.xsquad/config.json` already exists, read it and treat its values as the current
choices. Otherwise start from the defaults in `references/config.md`
(`orchestrator: "inherit"`, `subagent` and `reviewer` unset — they must be chosen).

## 4. Ask, map, and confirm

Prefer structured multiple-choice questions over free text.

**(a) Runner.** One of the detected CLIs (claude / pi / codex — plus ollama-launch or
native when relevant). All subagents and reviewers are dispatched through this runner;
mixed-runner squads are out of scope. Name the current runner on a re-run.

**(b) Orchestrator model.** Default `inherit` — the orchestrator is the agent already
running the skill, so it keeps the session model. A CLI slug here means headless
orchestration is possible (e.g. `claude -p "/xsquad <goal>" --model <slug>`); the
slug must be in that runner's confirmed list.

**(c) Subagent model(s).** One slug for the default implementer, or a list — one subagent
per list entry, so list length sets parallel fan-out (matching briefs by index or
capability). Show only confirmed slugs. On a re-run, keep any entries the user chose before.

**(d) Reviewer model(s).** The model(s) for the two code-review subagents. Default: the
same as the subagent model; a stronger reasoning model is a common upgrade.

**(e) Classifier backend (Jev).** The squad's System One pre-pass
(`references/classifier.md`) runs on Jev, TypeSafe AI's ~200 ms decision model. Detect
what's already available — `TYPESAFE_API_KEY`, `AI_GATEWAY_API_KEY`, or
`VERCEL_OIDC_TOKEN` in the environment or the project-root `.env` / `.env.local` (check names only;
never print values) — and ask which route to use, preselecting a detected one:

- **TypeSafe API key** (`typesafe`) — Jev direct; key from
  [console.typesafe.ai/keys](https://console.typesafe.ai/keys).
- **Vercel AI Gateway** (`gateway`) — Jev as `typesafe-ai/jev`, billed through the
  user's Vercel team; key from the AI Gateway → API Keys page in the Vercel dashboard (or
  `vercel env pull` for a 12-hour `VERCEL_OIDC_TOKEN` in a linked project).
- **Keyless** (`classifier.dev`) — no signup, shared per-IP rate limits; fine to try.

If the chosen route has no key yet, have the user store it **without pasting it into the
chat**: copy the key, then run `! pbpaste | <skill-path>/scripts/classify.sh --setup
typesafe` (or `gateway`) from the project root — or run the same command without the
pipe in their own terminal for a hidden prompt, or add `TYPESAFE_API_KEY=…` /
`AI_GATEWAY_API_KEY=…` to `.env` by hand. `--setup` writes `.env` with mode 600 and adds
`.env` to `.gitignore`. If the user pastes a key into the chat anyway, store it the same
way (`printf '%s' '<key>' | classify.sh --setup …`), never echo it back, and suggest
rotating it.

**(f) Confirm the full table.** Show every role with its model, plus the classifier
backend, marking any real slug not in the detected set as needing a choice. Ask whether
to accept as-is or change specific roles, offering the detected models as options.

## 5. Validate

Every real slug written must be in the runner's confirmed list (or probed now). Probe with
a one-token non-interactive call and require the exact reply:

```sh
# claude
claude -p --model "<slug>" --max-turns 1 "Reply with exactly: OK"
# codex
codex exec --skip-git-repo-check -s read-only -m "<slug>" "Reply with exactly: OK"
# pi
pi -p --no-session --provider "<provider>" --model "<id>" "Reply with exactly: OK"
```

If a chosen slug fails the probe, stop and ask again — never save an unconfirmed slug.
`inherit` always passes.

Probe the classifier backend too:
`<skill-path>/scripts/classify.sh --backend <backend> --probe` must print
`<backend>\tok\t…`. On a 401, the key is wrong or for the other route — go back to (e).
A classifier failure never blocks the model config: offer `classifier.dev` (keyless) or
leave it `auto`, and say so.

## 6. Write the config

Overwrite `.xsquad/config.json` in full so re-runs stay idempotent (schema and a worked
example: `references/config.md`):

```json
{
  "runner": "claude",
  "orchestrator": "inherit",
  "subagent": "claude-sonnet-4-5",
  "subagent_pool": [],
  "reviewer": "claude-sonnet-4-5",
  "classifier": "typesafe",
  "setup_probe": ["2026-01-15", "claude 2.1.271"]
}
```

If `.xsquad/` was just created, add `.xsquad/runs/` to `.gitignore` (runs are scratch;
`config.json`, `MEMORY.md`, and `validators/` are project infrastructure and get committed).
Keys never go in `config.json` — only the backend name; keys live in the gitignored `.env`.

## 7. Confirm

Tell the user the config was written, that it applies to new runs, and that re-running
this command updates it. If the project has no validator suite yet (no
`.xsquad/validators/README.md`), offer `/xSq-validator-setup` once — the squad's verify
gate needs validators to check tasks against. On no, move on without pushing.