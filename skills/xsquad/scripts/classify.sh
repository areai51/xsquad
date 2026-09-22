#!/bin/sh
# classify.sh — xSquad's System One pre-pass on Jev (TypeSafe AI); see classify.py or --help.
# Backends: TypeSafe direct (TYPESAFE_API_KEY), Vercel AI Gateway (AI_GATEWAY_API_KEY),
# or the keyless classifier.dev proxy. Run from the project root so .env and
# .xsquad/config.json are found.
exec python3 "$(dirname "$0")/classify.py" "$@"
