#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

secret_pattern='-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}'
secret_matches=$(git grep -l -I -E -e "$secret_pattern" -- . || true)
if [ -n "$secret_matches" ]; then
    echo "Security scan failed: possible secret material in tracked files:" >&2
    echo "$secret_matches" >&2
    exit 1
fi

tracked_signing_files=$(git ls-files | grep -E '(^|/)(\.env$|\.env\.[^/]+$|.*\.(p8|pem|key|mobileprovision|provisionprofile|cer)$)' | grep -Ev '(\.example|\.sample|\.template)$' || true)
if [ -n "$tracked_signing_files" ]; then
    echo "Security scan failed: signing or environment files are tracked:" >&2
    echo "$tracked_signing_files" >&2
    exit 1
fi

git diff --check
echo "Security scan passed."
