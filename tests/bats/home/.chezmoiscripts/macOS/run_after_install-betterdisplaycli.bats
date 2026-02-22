#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_install-betterdisplaycli.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"

  override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' '{"personal":true}' > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_install-betterdisplaycli.sh"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN personal profile EXPECT betterdisplay post-install script no-ops cleanly" {
  run bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]
}
