#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

# Install 1Password CLI if not present.
if ! command -v op >/dev/null 2>&1; then
  echo "Installing 1Password CLI..." >&2
  brew install --cask 1password-cli
  echo "1Password CLI installed." >&2
fi

# Install age if not present (required for chezmoi decryption when builtin age is disabled).
if ! command -v age >/dev/null 2>&1 && ! command -v rage >/dev/null 2>&1; then
  echo "Installing age..." >&2
  brew install age
  echo "age installed." >&2
fi

# Set up 1Password CLI service account token.
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  if [[ -t 0 ]]; then
    echo "Enter 1Password service account token (or press Enter to skip):" >&2
    read -s -r op_token
    echo "" >&2
    if [[ -n "${op_token}" ]]; then
      export OP_SERVICE_ACCOUNT_TOKEN="${op_token}"
      echo "1Password service account token set." >&2
    else
      echo "Skipping 1Password service account setup." >&2
    fi
  else
    echo "Skipping 1Password service account setup (no interactive terminal)." >&2
  fi
fi
