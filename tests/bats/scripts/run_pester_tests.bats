#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CHECK_SCRIPT="${REPO_ROOT}/scripts/run_pester_tests.sh"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  MOCK_REPO_ROOT="${TEST_TMPDIR}/repo"
  mkdir -p "${MOCK_BIN_DIR}" "${MOCK_REPO_ROOT}/tests/pester"

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

exit 1
EOF

  # Records each Pester run's test folder; the module probe and the run exit
  # with the codes the test sets.
  cat >"${MOCK_BIN_DIR}/pwsh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command="${!#}"
if [[ "${command}" == *"Get-Module"* ]]; then
  exit "${MOCK_PESTER_MODULE_EXIT:-0}"
fi
if [[ "${command}" == *"Invoke-Pester"* ]]; then
  [[ "${command}" == *'$env:PESTER_TESTS_DIR'* ]] || exit 2
  printf '%s\n' "${PESTER_TESTS_DIR:?}" >>"${MOCK_PESTER_CALLS_FILE:?}"
  exit "${MOCK_PESTER_EXIT:-0}"
fi
exit 1
EOF

  cat >"${MOCK_BIN_DIR}/cygpath" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${!#}"
EOF

  chmod +x "${MOCK_BIN_DIR}/git" "${MOCK_BIN_DIR}/pwsh" "${MOCK_BIN_DIR}/cygpath"

  export MOCK_REPO_ROOT
  export MOCK_PESTER_CALLS_FILE="${TEST_TMPDIR}/pester.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN no staged Windows scripts or Pester tests EXPECT no Pester run" {
  export MOCK_STAGED_PATHS=$'README.md\nhome/.chezmoiscripts/macOS/a.sh.tmpl'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ ! -f "${MOCK_PESTER_CALLS_FILE}" ]
}

@test "GIVEN a staged Windows script EXPECT the Pester folder is run" {
  export MOCK_STAGED_PATHS='home/.chezmoiscripts/windows/run_before_90_bootstrap-age-identities.ps1.tmpl'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ "$(cat "${MOCK_PESTER_CALLS_FILE}")" == "${MOCK_REPO_ROOT}/tests/pester" ]
}

@test "GIVEN a staged Pester test EXPECT the Pester folder is run" {
  export MOCK_STAGED_PATHS='tests/pester/bootstrap-age-identities.Tests.ps1'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ -f "${MOCK_PESTER_CALLS_FILE}" ]
}

@test "GIVEN failing Pester tests EXPECT checker exits non-zero" {
  export MOCK_STAGED_PATHS='tests/pester/bootstrap-age-identities.Tests.ps1'
  export MOCK_PESTER_EXIT=1

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Pester tests failed."* ]]
}

@test "GIVEN git staged-files lookup failure EXPECT checker exits non-zero" {
  export MOCK_GIT_DIFF_FAIL=1

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 1 ]
}

@test "GIVEN Pester 5 missing EXPECT checker skips without a run" {
  export MOCK_STAGED_PATHS='tests/pester/bootstrap-age-identities.Tests.ps1'
  export MOCK_PESTER_MODULE_EXIT=3

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipping Pester tests: Pester 5 is not installed"* ]]
  [ ! -f "${MOCK_PESTER_CALLS_FILE}" ]
}

@test "GIVEN pwsh missing EXPECT checker skips" {
  export MOCK_STAGED_PATHS='tests/pester/bootstrap-age-identities.Tests.ps1'
  rm -f "${MOCK_BIN_DIR}/pwsh"
  restricted_path="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin"
  if PATH="${restricted_path}" command -v pwsh >/dev/null 2>&1; then
    skip "pwsh is installed in a system bin directory"
  fi

  run env PATH="${restricted_path}" /bin/bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipping Pester tests: pwsh is not installed."* ]]
}
