#!/usr/bin/env bash
set -euo pipefail

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks is not installed. Install it first (for example: brew install gitleaks)." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  echo "Not inside a git repository." >&2
  exit 1
fi

cd "${repo_root}"

echo "Running gitleaks on staged changes..."
gitleaks protect --staged --redact --no-banner

echo "Running gitleaks on working tree..."
gitleaks detect --source . --no-git --redact --no-banner

echo "No leaks found."
