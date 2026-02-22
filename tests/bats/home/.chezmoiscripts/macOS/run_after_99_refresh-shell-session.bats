#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_99_refresh-shell-session.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_99_refresh-shell-session.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN non-interactive test run EXPECT script exits successfully" {
  run bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN interactive branch forced EXPECT refresh instruction is printed" {
  forced_script="${TEST_TMPDIR}/run_after_99_refresh-shell-session-forced.sh"
  sed 's/\[\[ -t 1 \]\]/true/' "${RENDERED_SCRIPT}" > "${forced_script}"
  chmod +x "${forced_script}"

  run bash "${forced_script}"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *'exec "$SHELL" -l'* ]]
}
