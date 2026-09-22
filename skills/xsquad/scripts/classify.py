#!/usr/bin/env python3
"""classify.sh — xSquad's System One pre-pass on Jev (TypeSafe AI).

Buckets raw text (validator output, subagent logs, review findings) into labels with
calibrated confidence, and checks yes/no statements against a report or log, so agents
read only what needs judgment instead of pulling large raw output into context.

Usage:
  classify.sh <labels-csv> [file ...]              # one classification per non-empty line (or stdin)
  classify.sh --check "<statement>" [--check ...] [file ...]
                                                   # whole input is one state; P(yes) per statement
  classify.sh --probe                              # one tiny call: prove the backend + key work
  classify.sh --setup typesafe|gateway|classifier.dev
                                                   # store the key in ./.env (read hidden from the
                                                   # TTY, or from stdin: `pbpaste | classify.sh --setup typesafe`)
Options:
  --backend typesafe|gateway|classifier.dev        # override backend selection (see below)
  --instructions "judge only the validator output" # extra criteria for every question
  --tier smart                                     # classifier.dev only: reasoning re-ask below 0.7
  --full                                           # print the full line, not an 80-char prefix

Output (TSV, input order):  labels: <label>\t<confidence>\t<text prefix>
                             check:  <yes|no>\t<P(yes)>\t<statement>
Backends (first match wins): --backend, XSQ_CLASSIFIER_BACKEND, "classifier" in
.xsquad/config.json, then whichever key exists: TYPESAFE_API_KEY -> typesafe (direct),
AI_GATEWAY_API_KEY / VERCEL_OIDC_TOKEN -> gateway (Vercel AI Gateway, typesafe-ai/jev),
else classifier.dev (keyless Jev proxy; CLASSIFIER_DEV_API_KEY optional).
Keys come from the environment or the project-root .env.local / .env. Never classify secrets.
"""

import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BACKENDS = ("typesafe", "gateway", "classifier.dev")
KEY_VARS = {
    "typesafe": "TYPESAFE_API_KEY",
    "gateway": "AI_GATEWAY_API_KEY",
    "classifier.dev": "CLASSIFIER_DEV_API_KEY",
}
TYPESAFE_URL = "https://api.typesafe.ai/v1/systemone"
CLASSIFIER_DEV_URL = "https://classifier.dev"
GATEWAY_URL = "https://ai-gateway.vercel.sh/v4/ai/evaluation-model"
GATEWAY_MODEL = "typesafe-ai/jev"
TYPESAFE_MODEL = "jev-latest"
MAX_STATE_CHARS = 90_000  # Jev caps state at 32k tokens; keep the tail, where verdicts live
MAX_LINES = 1_000
WORKERS = 8  # Jev is ~200 ms/request; 1,200 requests/min cap
UA = "xsquad-classify/2.0"


def die(msg, code=1):
    print(f"classify.sh: {msg}", file=sys.stderr)
    sys.exit(code)


def load_dotenv():
    """Project-root .env.local then .env (vercel env pull writes .env.local); the real
    environment always wins."""
    for path in (".env.local", ".env"):
        if os.path.isfile(path):
            load_env_file(path)


def load_env_file(path):
    with open(path) as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k = k.strip().removeprefix("export ").strip()
            v = v.strip().strip("'\"")
            if k and v and not os.environ.get(k):
                os.environ[k] = v


def pick_backend(flag):
    choice = flag or os.environ.get("XSQ_CLASSIFIER_BACKEND", "")
    if not choice and os.path.isfile(".xsquad/config.json"):
        try:
            with open(".xsquad/config.json") as fh:
                choice = json.load(fh).get("classifier", "") or ""
        except (OSError, ValueError):
            pass
    if choice and choice != "auto":
        if choice not in BACKENDS:
            die(f"unknown backend {choice!r}; use one of: {', '.join(BACKENDS)}", 2)
        return choice
    if os.environ.get("TYPESAFE_API_KEY"):
        return "typesafe"
    if os.environ.get("AI_GATEWAY_API_KEY") or os.environ.get("VERCEL_OIDC_TOKEN"):
        return "gateway"
    return "classifier.dev"


def post(url, payload, headers):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers=headers)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < 2:
                time.sleep(2 ** attempt * 5)
                continue
            body = e.read()[:300].decode(errors="replace")
            hint = " (check the API key: classify.sh --setup ...)" if e.code in (401, 403) else ""
            die(f"{url} returned HTTP {e.code}{hint}: {body}")
        except urllib.error.URLError as e:
            die(f"cannot reach {url}: {e.reason}")


class Jev:
    """One System One evaluation: a state plus typed questions -> typed answers."""

    def __init__(self, backend):
        self.backend = backend
        headers = {"Content-Type": "application/json", "User-Agent": UA}
        if backend == "gateway":
            token = os.environ.get("AI_GATEWAY_API_KEY")
            method = "api-key"
            if not token:
                token, method = os.environ.get("VERCEL_OIDC_TOKEN"), "oidc"
            if not token:
                die("gateway backend needs AI_GATEWAY_API_KEY (or VERCEL_OIDC_TOKEN); "
                    "run: classify.sh --setup gateway")
            headers.update({
                "Authorization": f"Bearer {token}",
                "ai-gateway-protocol-version": "0.0.1",
                "ai-gateway-auth-method": method,
                "ai-evaluation-model-specification-version": "4",
                "ai-model-id": GATEWAY_MODEL,
            })
            self.url = GATEWAY_URL
        elif backend == "typesafe":
            key = os.environ.get("TYPESAFE_API_KEY")
            if not key:
                die("typesafe backend needs TYPESAFE_API_KEY; run: classify.sh --setup typesafe")
            headers["Authorization"] = f"Bearer {key}"
            self.url = TYPESAFE_URL
        else:  # classifier.dev serves TypeSafe's wire contract at the same path, keyless
            headers["Authorization"] = f"Bearer {os.environ.get('CLASSIFIER_DEV_API_KEY') or 'unused'}"
            self.url = CLASSIFIER_DEV_URL + "/v1/systemone"
        self.headers = headers

    def yes_no(self, instructions):
        # TypeSafe calls the yes/no primitive "noul"; the AI SDK / Gateway calls it "boolean".
        return {"type": "boolean" if self.backend == "gateway" else "noul",
                "instructions": instructions}

    def evaluate(self, state, questions):
        payload = {"state": state, "questions": questions}
        if self.backend != "gateway":
            payload["model"] = TYPESAFE_MODEL
        resp = post(self.url, payload, self.headers)
        meta_conf = ((resp.get("providerMetadata") or {}).get("typesafe") or {}).get("confidence") or {}
        out = {}
        for qid, ans in (resp.get("answers") or {}).items():
            kind = ans.get("type")
            if kind in ("noul", "boolean"):
                out[qid] = ("yes/no", ans.get("noul", ans.get("probability")))
            else:
                conf = ans.get("confidence", meta_conf.get(qid))
                probs = ans.get("probabilities") or {}
                if conf is None and len(probs) > 1:  # TypeSafe's definition, from the distribution
                    n, peak = len(probs), max(probs.values())
                    conf = max(0.0, min(1.0, (n * peak - 1) / (n - 1)))
                out[qid] = (ans.get("choice"), conf)
        return out


def classify_lines_jev(jev, lines, labels, instructions):
    ask = "Which label best describes this text?"
    if instructions:
        ask += " " + instructions
    question = {"type": "choice", "instructions": ask, "criteria": {lb: None for lb in labels}}

    def one(line):
        return jev.evaluate(line, {"label": question})["label"]

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        return list(pool.map(one, lines))


def classify_lines_classifier_dev(lines, labels, tier, instructions):
    payload = {"labels": labels, "tier": tier}
    if instructions:
        payload["instructions"] = instructions
    headers = {"Content-Type": "application/json", "User-Agent": UA}
    key = os.environ.get("CLASSIFIER_DEV_API_KEY")
    if key:
        headers["Authorization"] = f"Bearer {key}"
    results = []
    for i in range(0, len(lines), 500):  # well under the 1,000-input cap
        payload["inputs"] = lines[i:i + 500]
        results.extend(post(CLASSIFIER_DEV_URL + "/v1/classify", payload, headers)["results"])
    return [(r["label"], r.get("confidence")) for r in results]


def fmt(conf):
    return "-" if conf is None else f"{conf:.2f}"


def setup(backend):
    if backend not in BACKENDS:
        die(f"--setup takes one of: {', '.join(BACKENDS)}", 2)
    var = KEY_VARS[backend]
    if sys.stdin.isatty():
        key = getpass.getpass(f"{var} (input hidden; empty to skip): ").strip()
    else:
        key = sys.stdin.read().strip()
    if key:
        lines = []
        if os.path.isfile(".env"):
            with open(".env") as fh:
                lines = [ln for ln in fh.read().splitlines() if not ln.startswith(f"{var}=")]
        lines.append(f"{var}={key}")
        fd = os.open(".env", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as fh:
            fh.write("\n".join(lines) + "\n")
        print(f"wrote {var} to ./.env (mode 600)")
        ignored = os.path.isfile(".gitignore") and any(
            ln.strip() in (".env", "/.env", ".env*") for ln in open(".gitignore"))
        if not ignored:
            with open(".gitignore", "a") as fh:
                fh.write(".env\n")
            print("added .env to .gitignore")
    elif backend != "classifier.dev":
        die(f"no key given; {backend} needs {var}")
    config = ".xsquad/config.json"
    if os.path.isfile(config):
        with open(config) as fh:
            data = json.load(fh)
        data["classifier"] = backend
        with open(config, "w") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        print(f'set "classifier": "{backend}" in {config}')
    else:
        print(f"no {config} yet; pass --backend {backend} or rerun after /xSq-setup")


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        sys.exit(0 if argv else 1)

    labels_csv, checks, files = None, [], []
    backend_flag, instructions, tier, full, probe = "", "", "fast", False, False
    it = iter(argv)
    for arg in it:
        try:
            if arg == "--backend":
                backend_flag = next(it)
            elif arg == "--instructions":
                instructions = next(it)
            elif arg == "--tier":
                tier = next(it)
            elif arg == "--check":
                checks.append(next(it))
            elif arg == "--full":
                full = True
            elif arg == "--probe":
                probe = True
            elif arg == "--setup":
                load_dotenv()
                return setup(next(it))
            elif arg == "--":
                files.extend(it)
            elif arg.startswith("-") and arg != "-":
                die(f"unknown option: {arg}", 2)
            elif labels_csv is None and not checks:
                labels_csv = arg
            else:
                files.append(arg)
        except StopIteration:
            die(f"{arg} needs a value", 2)

    load_dotenv()
    backend = pick_backend(backend_flag)

    if probe:
        jev = Jev(backend)
        t0 = time.monotonic()
        ans = jev.evaluate("All 42 tests passed.", {"ok": jev.yes_no("Did the tests pass?")})
        ms = (time.monotonic() - t0) * 1000
        print(f"{backend}\tok\tP(yes)={fmt(ans['ok'][1])}\t{ms:.0f} ms")
        return

    if labels_csv is not None and checks:
        die("use either <labels-csv> or --check, not both", 2)
    if labels_csv is None and not checks:
        die("missing labels (or --check)", 2)

    text = ""
    for f in files or ["-"]:
        if f == "-":
            text += sys.stdin.read()
        else:
            with open(f, errors="replace") as fh:
                text += fh.read()

    if checks:
        if not text.strip():
            die("no input to check")
        if len(text) > MAX_STATE_CHARS:
            print(f"classify.sh: input is {len(text)} chars; checking the last {MAX_STATE_CHARS}",
                  file=sys.stderr)
            text = text[-MAX_STATE_CHARS:]
        jev = Jev(backend)
        suffix = f" {instructions}" if instructions else ""
        questions = {f"c{i}": jev.yes_no(s + suffix) for i, s in enumerate(checks)}
        answers = jev.evaluate(text, questions)
        for i, s in enumerate(checks):
            p = answers[f"c{i}"][1]
            verdict = "yes" if p is not None and p >= 0.5 else "no"
            print(f"{verdict}\t{fmt(p)}\t{s}")
        return

    lines = [ln for ln in text.splitlines() if ln.strip()]
    if not lines:
        die("no non-empty input lines to classify")
    if len(lines) > MAX_LINES:
        die(f"over {MAX_LINES} inputs; split into several calls")
    labels = [lb.strip() for lb in labels_csv.split(",") if lb.strip()]
    if len(labels) < 2:
        die("need at least 2 labels (comma-separated)")

    if backend == "classifier.dev":
        results = classify_lines_classifier_dev(lines, labels, tier, instructions)
    else:
        if tier != "fast":
            print(f"classify.sh: --tier is classifier.dev-only; {backend} always runs Jev",
                  file=sys.stderr)
        results = classify_lines_jev(Jev(backend), lines, labels, instructions)
    if len(results) != len(lines):
        die(f"expected {len(lines)} results, got {len(results)}")

    for line, (label, conf) in zip(lines, results):
        shown = line if full else (line[:77] + "..." if len(line) > 80 else line)
        print(f"{label}\t{fmt(conf)}\t{shown}")


if __name__ == "__main__":
    main(sys.argv[1:])
