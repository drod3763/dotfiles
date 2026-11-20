#!/usr/bin/env bash
set -euo pipefail

# Runs the Pester tests under tests/pester when a Windows chezmoi script or a
# Pester test is staged.
# Skips (exit 0) when pwsh 7 or Pester 5 is missing, so machines without them
# (macOS/Linux, or Windows before setup) are not blocked.

if ! staged_paths="$(git diff --cached --name-only --diff-filter=ACMR)"; then
  echo "Failed to read staged files." >&2
  exit 1
fi

run=0
while IFS= read -r path; do
  case "${path}" in
  home/.chezmoiscripts/windows/* | tests/pester/*)
    run=1
    ;;
  *) ;;
  esac
done <<<"${staged_paths}"

if [[ ${run} -eq 0 ]]; then
  exit 0
fi

if ! command -v pwsh >/dev/null 2>&1; then
  echo "Skipping Pester tests: pwsh is not installed." >&2
  exit 0
fi

if ! pwsh -NoProfile -NonInteractive -Command \
  'if (-not (Get-Module -ListAvailable Pester | Where-Object Version -ge ([version]"5.0.0"))) { exit 3 }'; then
  echo "Skipping Pester tests: Pester 5 is not installed (Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser)." >&2
  exit 0
fi

tests_dir="$(git rev-parse --show-toplevel)/tests/pester"
# pwsh on Windows needs a native path; Git Bash's cygpath provides one.
if command -v cygpath >/dev/null 2>&1; then
  tests_dir="$(cygpath -w "${tests_dir}")"
fi

# The path goes through the environment, so quotes in it cannot break the command.
# shellcheck disable=SC2016 # $ is PowerShell syntax, expanded by pwsh, not bash.
if ! PESTER_TESTS_DIR="${tests_dir}" pwsh -NoProfile -NonInteractive -Command \
  '$ErrorActionPreference = "Stop"; Import-Module Pester -MinimumVersion 5.0.0; $config = New-PesterConfiguration; $config.Run.Path = $env:PESTER_TESTS_DIR; $config.Run.Exit = $true; $config.Output.Verbosity = "Normal"; Invoke-Pester -Configuration $config'; then
  echo "Pester tests failed." >&2
  exit 1
fi
