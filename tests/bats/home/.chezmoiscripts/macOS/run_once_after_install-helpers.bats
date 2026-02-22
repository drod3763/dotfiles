#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_once_after_install-helpers.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_BREW_CALLS_FILE:?}"
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/brew"
  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_once_after_install-helpers.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN brew exists EXPECT script taps helper repository" {
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^tap drod3763/tap$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}
