# test.md — core validator (offline script-behavior tests)

No test framework exists in this repo, so this validator runs the deterministic,
network-free behaviors of the two executables directly. Every case runs in a throwaway
temp dir — the repo root has a real `.env` that validators must never read, write, or
modify. No network calls here: the online side of the classifier is the
`classifier.md` feature validator's job.

## Command

Run from the repo root; this helper encapsulates all cases:

```sh
.xsquad/validators/scripts/behavior-tests.sh
```

## Passing output (defined exactly)

Exit 0, and the last stdout line is exactly:

```
behavior OK: 8/8 cases passed
```

Each individual case prints `case <n>: <name> ok` above it. A failing case prints
`case <n>: <name> FAIL: <detail>` and aborts with exit 1.

## What the 8 cases cover

1. `classify.sh` with no args prints usage and exits 1.
2. `--backend bogus` is rejected with exit 2 and `unknown backend`.
3. One label (`classify.sh foo`) exits 1 with `need at least 2 labels` (exit 2 is
   reserved for argument-parse errors; usage errors exit 1).
4. `--check` together with a labels-csv exits 2 (`use either`).
5. `--setup gateway` with empty stdin exits 1 (`no key given`).
6. `--setup classifier.dev` with a piped fake key writes `./.env` mode 600 containing
   `CLASSIFIER_DEV_API_KEY=...` and does NOT print the key.
7. Same setup, when `./.xsquad/config.json` exists, rewrites it with
   `"classifier": "classifier.dev"` and valid JSON.
8. `install.sh <temp-dir>` links all six skills (symlink per skill, name from
   frontmatter, target resolves into this repo); `CORE_ONLY=1` links exactly one.

Cases 1–5 are offline by construction. Cases 6–7 and 8 hit no network either —
`--setup` only writes files. `install.sh` is invoked with an explicit temp skills-dir,
never the default `~/.claude/skills`.