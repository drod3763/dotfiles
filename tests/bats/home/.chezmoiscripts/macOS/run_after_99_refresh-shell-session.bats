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
