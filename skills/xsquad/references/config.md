# Squad configuration & on-disk layout

Everything xSquad-code persists lives under `.xsquad/` at the project root:

```
.xsquad/
├── config.json            # runner + models per role (written by /xSq-setup)
├── MEMORY.md              # cross-run learnings (brief lessons, quirks, verify gotchas)
├── validators/
│   ├── README.md          # validator index: name, kind, proves, status, covers
│   ├── build.md           # core validators (build / test / lint)
│   ├── test.md
│   ├── lint.md
│   ├── <feature>.md       # feature validators (launch/doctor/drive/pass/evidence/cleanup)
│   └── scripts/           # executable helpers; invocation shown in the spec body
└── runs/
    └── <YYYYMMDD-HHMM-slug>/   # one directory per squad run
        ├── plan.md             # tasks, footprints, validators per task, parallel groups
        ├── brief-<task>.md     # task briefs (r2, r3… for fix rounds)
        ├── report-<task>.md    # subagent reports
        ├── log-<task>.txt      # raw subagent output
        ├── evidence/           # validator evidence; survives cleanup
        ├── review-context/     # diff + changed-file contents for reviewers
        └── review-findings.md  # synthesized review findings + resolution status
```

Git hygiene: commit `config.json`, `MEMORY.md`, and `validators/`; add `.xsquad/runs/`
to `.gitignore`. If the project already uses a `tasks/` directory from the legacy xsquad
skill, migrate it (briefs/reports → the run dir, MEMORY.md → `.xsquad/MEMORY.md`) or
symlink `tasks/MEMORY.md` → `.xsquad/MEMORY.md`; don't keep two memories.

## config.json

```json
{
  "runner": "claude",
  "orchestrator": "inherit",
  "subagent": "glm-5.2:cloud",
  "subagent_pool": [],
  "reviewer": "glm-5.2:cloud",
  "provider": "",
  "setup_probe": ["2026-01-15", "claude 2.1.271"]
}
```

- **runner** — `claude` | `pi` | `codex` | `ollama` | `native`. How implementer and
  reviewer subagents are launched. `native` = the host harness's own subagent mechanism
  (Claude Code Task tool, DSH `subagent` tool); the CLI model fields are then ignored
  except as advisory.
- **orchestrator** — `inherit` (the session agent running the skill) or a confirmed slug
  on the runner, enabling headless orchestration (dispatch table below).
- **subagent** — default implementer model. **subagent_pool** — optional list; one
  subagent per entry, so its length sets max parallel fan-out (briefs assigned by index
  or capability; empty list = unlimited single-model).
- **reviewer** — model(s) for the two review subagents.
- **provider** — pi only: default `--provider` for slugs that need it.
- **setup_probe** — date + runner version at last confirmed setup (diagnostics).

## Model lists per runner

- **pi** — `pi --list-models [search]` (authoritative; includes provider, context window,
  thinking, images). `llama-cpp … fetch failed` at the top is a benign local-provider
  notice. Dispatch uses `--provider <name> --model <id>`.
- **codex** — no list command: read `model` + `[model_providers.*]` from
  `~/.codex/config.toml`, then documented built-ins (`gpt-5.1-codex-max`,
  `gpt-5.1-codex`, `gpt-5.1-codex-mini`, `gpt-5.1`, `gpt-5.3-codex`, …). Probe anything
  not confirmed by config/docs.
- **claude** — aliases `fable`, `opus`, `sonnet`, `haiku` (latest of each family) plus
  full names (`claude-fable-5`, `claude-opus-4-5`, …). Probe anything not an alias.
- **ollama** — `ollama model list`; launch Claude Code on an ollama-hosted model with
  `ollama launch claude --model <slug> -- --dangerously-skip-permissions`.

Slug rule: never write a slug that wasn't listed by the runner or confirmed by probe
(one-token non-interactive call; see `commands/setup.md` step 5). `inherit` always passes.

## Dispatch commands (non-interactive, one background process per brief)

Run from the project root; redirect output to `log-<task>.txt`; launch each with the
host's background mechanism (`run_in_background: true`). The wrapper text is the CLI
prompt argument; when it contains characters the shell would eat, write it to a file and
pass that file's content via stdin (`claude -p`, `codex exec`, and `pi -p` all accept the
prompt on stdin).

```sh
# claude (Claude Code)
claude -p --model "<subagent>" --dangerously-skip-permissions \
  "<dispatch wrapper>" > log-<task>.txt 2>&1

# codex
codex exec --skip-git-repo-check -s workspace-write -m "<subagent>" \
  -o last-message-<task>.txt "<dispatch wrapper>" > log-<task>.txt 2>&1

# pi
pi -p --no-session --provider "<provider>" --model "<subagent>" \
  "<dispatch wrapper>" > log-<task>.txt 2>&1

# ollama (launches Claude Code on an ollama-hosted model)
ollama launch claude --model "<subagent>" -- --dangerously-skip-permissions \
  -p "<dispatch wrapper>" > log-<task>.txt 2>&1
```

- Sandbox choice: `-s workspace-write` is the safe default for codex;
  `--dangerously-bypass-approvals-and-sandbox` only in an externally sandboxed
  environment. For claude, `--permission-mode acceptEdits` is a softer alternative to
  `--dangerously-skip-permissions`.
- pi thinking level for heavy implementer tasks: `--thinking high` (off→xhigh ladder).
- **native** runner: use the host harness subagent mechanism, background mode, same
  dispatch wrapper, model override = the configured slug when the harness supports it.
- Collect results from the report file, not stdout; the log is for failures.

### Headless orchestrator (optional)

Run the whole squad non-interactively when `orchestrator` is a real slug:

```sh
claude -p --model "<orchestrator>" --dangerously-skip-permissions \
  "/xsquad <goal>" > orchestrator-log.txt 2>&1
```

## Reviewer dispatch

Same table, with the reviewer model and the prompt from
`agents/reviewer-security.md` / `agents/reviewer-quality.md`, each prefixed with the
labeled sections (`### Diff`, `### Changed file contents`, `### Goal & task map`) and
suffixed with "You never edit code and never spawn nested subagents."