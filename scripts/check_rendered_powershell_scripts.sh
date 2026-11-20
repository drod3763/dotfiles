#!/usr/bin/env bash
set -euo pipefail

# Lints Windows chezmoi scripts and PowerShell profiles with PSScriptAnalyzer
# after rendering templates.
# Skips (exit 0) when PowerShell or the module is missing, so machines without
# them are not blocked.

repo_root="$(git rev-parse --show-toplevel)"

declare -a candidates=()
check_all=0

if ! staged_paths="$(git diff --cached --name-only --diff-filter=ACMR)"; then
  echo "Failed to read staged files." >&2
  exit 1
fi

add_candidate() {
  local candidate="$1"
  local existing

  if [[ ${#candidates[@]} -gt 0 ]]; then
    for existing in "${candidates[@]}"; do
      if [[ ${existing} == "${candidate}" ]]; then
        return
      fi
    done
  fi

  candidates+=("${candidate}")
}

while IFS= read -r path; do
  [[ -n ${path} ]] || continue

  case "${path}" in
  home/.chezmoitemplates/*)
    check_all=1
    ;;
  home/.chezmoiscripts/windows/*.ps1 | home/.chezmoiscripts/windows/*.ps1.tmpl | home/Documents/*/*.ps1.tmpl)
    add_candidate "${path}"
    ;;
  *) ;;
  esac
done <<<"${staged_paths}"

if [[ ${check_all} -eq 1 ]]; then
  if ! tracked_paths="$(git ls-files)"; then
    echo "Failed to list tracked files." >&2
    exit 1
  fi

  while IFS= read -r rel_path; do
    case "${rel_path}" in
    home/.chezmoiscripts/windows/*.ps1 | home/.chezmoiscripts/windows/*.ps1.tmpl | home/Documents/*/*.ps1.tmpl)
      add_candidate "${rel_path}"
      ;;
    *) ;;
    esac
  done <<<"${tracked_paths}"
fi

if [[ ${#candidates[@]} -eq 0 ]]; then
  exit 0
fi

pwsh_cmd=""
if command -v pwsh >/dev/null 2>&1; then
  pwsh_cmd="pwsh"
elif command -v powershell.exe >/dev/null 2>&1; then
  pwsh_cmd="powershell.exe"
else
  echo "Skipping PowerShell lint: pwsh is not installed." >&2
  exit 0
fi

if ! "${pwsh_cmd}" -NoProfile -NonInteractive -Command \
  'if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { exit 3 }'; then
  echo "Skipping PowerShell lint: PSScriptAnalyzer is not installed (Install-Module PSScriptAnalyzer -Scope CurrentUser)." >&2
  exit 0
fi

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi is required to render script templates." >&2
  exit 1
fi

out_dir="$(mktemp -d "${TMPDIR:-/tmp}/rendered-ps.XXXXXX")"
trap 'rm -rf "${out_dir}"' EXIT

status=0
for script in "${candidates[@]}"; do
  src="${repo_root}/${script}"
  # Both PowerShell profiles share a basename, so name renders by source path.
  name="${script%.tmpl}"
  name="${name//\//__}"

  if [[ ${script} == *.tmpl ]]; then
    if ! chezmoi execute-template <"${src}" >"${out_dir}/${name}"; then
      echo "Failed to render template: ${script}" >&2
      status=1
    fi
  else
    cp "${src}" "${out_dir}/${name}"
  fi
done

# Windows PowerShell needs a native path; Git Bash's cygpath provides one.
analyze_dir="${out_dir}"
if command -v cygpath >/dev/null 2>&1; then
  analyze_dir="$(cygpath -w "${out_dir}")"
fi

# Pass the path through the environment, so quotes in it (e.g. a profile
# named O'Brien) cannot break the command.
if ! PS_ANALYZE_DIR="${analyze_dir}" "${pwsh_cmd}" -NoProfile -NonInteractive -Command \
  "\$ErrorActionPreference = 'Stop'; \$results = Invoke-ScriptAnalyzer -Path \$env:PS_ANALYZE_DIR -Severity Error,Warning; if (\$results) { \$results | Format-Table ScriptName, Line, Severity, RuleName, Message -AutoSize -Wrap | Out-String -Width 200 | Write-Host; exit 1 }"; then
  echo "PSScriptAnalyzer found issues in rendered Windows scripts." >&2
  status=1
fi

exit "${status}"
