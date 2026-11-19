#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CHECK_SCRIPT="${REPO_ROOT}/scripts/check_rendered_powershell_scripts.sh"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  MOCK_REPO_ROOT="${TEST_TMPDIR}/repo"
  mkdir -p "${MOCK_BIN_DIR}" \
    "${MOCK_REPO_ROOT}/home/.chezmoiscripts/windows" \
    "${MOCK_REPO_ROOT}/home/Documents/PowerShell" \
    "${MOCK_REPO_ROOT}/home/Documents/WindowsPowerShell"

  printf '%s\n' 'Write-Output a' >"${MOCK_REPO_ROOT}/home/.chezmoiscripts/windows/a.ps1.tmpl"
  printf '%s\n' 'Write-Output b' >"${MOCK_REPO_ROOT}/home/.chezmoiscripts/windows/b.ps1"
  # Both profiles share a basename; the checker must keep both renders.
  printf '%s\n' 'Write-Output core' >"${MOCK_REPO_ROOT}/home/Documents/PowerShell/profile.ps1.tmpl"
  printf '%s\n' 'Write-Output desktop' >"${MOCK_REPO_ROOT}/home/Documents/WindowsPowerShell/profile.ps1.tmpl"

  cat >"${MOCK_BIN_DIR}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
  printf '%s\n' "${MOCK_REPO_ROOT:?}"
  exit 0
fi

if [[ "${1:-}" == "diff" && "${2:-}" == "--cached" ]]; then
  if [[ -n "${MOCK_GIT_DIFF_FAIL:-}" ]]; then
    exit 1
  fi
  printf '%s' "${MOCK_STAGED_PATHS:-}"
  exit 0
fi

if [[ "${1:-}" == "ls-files" ]]; then
  printf '%s\n' 'home/.chezmoiscripts/windows/a.ps1.tmpl'
  printf '%s\n' 'home/.chezmoiscripts/windows/b.ps1'
  printf '%s\n' 'home/Documents/PowerShell/profile.ps1.tmpl'
  printf '%s\n' 'home/Documents/WindowsPowerShell/profile.ps1.tmpl'
  printf '%s\n' 'home/.chezmoiscripts/macOS/c.sh.tmpl'
  exit 0
fi

exit 1
EOF

  cat >"${MOCK_BIN_DIR}/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${MOCK_CHEZMOI_RENDER_FAIL:-}" ]]; then
  exit 1
fi
cat
EOF

  # Records each analyzer run's rendered files; the module probe and the
  # analyzer exit with the codes the test sets.
  cat >"${MOCK_BIN_DIR}/pwsh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command="${!#}"
if [[ "${command}" == *"Get-Module"* ]]; then
  exit "${MOCK_PWSH_MODULE_EXIT:-0}"
fi
if [[ "${command}" == *"Invoke-ScriptAnalyzer"* ]]; then
  dir="${command#*-Path \'}"
  dir="${dir%%\'*}"
  ls "${dir}" >>"${MOCK_ANALYZER_CALLS_FILE:?}"
  exit "${MOCK_ANALYZER_EXIT:-0}"
fi
exit 1
EOF

  # Keep the POSIX temp path, so the pwsh mock can list it on any host.
  cat >"${MOCK_BIN_DIR}/cygpath" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${!#}"
EOF

  chmod +x "${MOCK_BIN_DIR}/git" "${MOCK_BIN_DIR}/chezmoi" "${MOCK_BIN_DIR}/pwsh" "${MOCK_BIN_DIR}/cygpath"

  export MOCK_REPO_ROOT
  export MOCK_ANALYZER_CALLS_FILE="${TEST_TMPDIR}/analyzer.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN no staged Windows scripts EXPECT checker exits without analyzer runs" {
  export MOCK_STAGED_PATHS=$'README.md\nhome/.chezmoiscripts/macOS/c.sh.tmpl'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ ! -f "${MOCK_ANALYZER_CALLS_FILE}" ]
}

@test "GIVEN staged Windows script EXPECT only that script is analyzed" {
  export MOCK_STAGED_PATHS='home/.chezmoiscripts/windows/a.ps1.tmpl'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ "$(cat "${MOCK_ANALYZER_CALLS_FILE}")" == "home__.chezmoiscripts__windows__a.ps1" ]
}

@test "GIVEN staged shared template EXPECT every Windows script and both profiles analyzed" {
  export MOCK_STAGED_PATHS='home/.chezmoitemplates/functions.tmpl'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ "$(wc -l <"${MOCK_ANALYZER_CALLS_FILE}" | tr -d ' ')" -eq 4 ]
  grep -qx 'home__Documents__PowerShell__profile.ps1' "${MOCK_ANALYZER_CALLS_FILE}"
  grep -qx 'home__Documents__WindowsPowerShell__profile.ps1' "${MOCK_ANALYZER_CALLS_FILE}"
}

@test "GIVEN analyzer findings EXPECT checker exits non-zero" {
  export MOCK_STAGED_PATHS='home/.chezmoiscripts/windows/b.ps1'
  export MOCK_ANALYZER_EXIT=1

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"PSScriptAnalyzer found issues in rendered Windows scripts."* ]]
}

@test "GIVEN template render failure EXPECT checker exits non-zero" {
  export MOCK_STAGED_PATHS='home/.chezmoiscripts/windows/a.ps1.tmpl'
  export MOCK_CHEZMOI_RENDER_FAIL=1

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Failed to render template: home/.chezmoiscripts/windows/a.ps1.tmpl"* ]]
}

@test "GIVEN git staged-files lookup failure EXPECT checker exits non-zero" {
  export MOCK_GIT_DIFF_FAIL=1

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 1 ]
}

@test "GIVEN PSScriptAnalyzer missing EXPECT checker skips without analyzer runs" {
  export MOCK_STAGED_PATHS='home/.chezmoiscripts/windows/a.ps1.tmpl'
  export MOCK_PWSH_MODULE_EXIT=3

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipping PowerShell lint: PSScriptAnalyzer is not installed"* ]]
  [ ! -f "${MOCK_ANALYZER_CALLS_FILE}" ]
}

@test "GIVEN PowerShell missing EXPECT checker skips" {
  export MOCK_STAGED_PATHS='home/.chezmoiscripts/windows/a.ps1.tmpl'
  rm -f "${MOCK_BIN_DIR}/pwsh"
  restricted_path="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin"
  if PATH="${restricted_path}" command -v pwsh >/dev/null 2>&1 ||
    PATH="${restricted_path}" command -v powershell.exe >/dev/null 2>&1; then
    skip "PowerShell is installed in a system bin directory"
  fi

  run env PATH="${restricted_path}" /bin/bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipping PowerShell lint: pwsh is not installed."* ]]
}
