#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_once_after_install-helpers.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  MOCK_APPS_DIR="${TEST_TMPDIR}/Applications"
  mkdir -p "${MOCK_BIN_DIR}" "${MOCK_APPS_DIR}"

  cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_BREW_CALLS_FILE:?}"
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/brew"
  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  RENDERED_SCRIPT_RAW="${TEST_TMPDIR}/run_once_after_install-helpers.raw.sh"
  RENDERED_SCRIPT="${TEST_TMPDIR}/run_once_after_install-helpers.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT_RAW}"
  sed "s|/Applications|${MOCK_APPS_DIR}|g" "${RENDERED_SCRIPT_RAW}" > "${RENDERED_SCRIPT}"
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

@test "GIVEN required app missing EXPECT helper cask install is skipped" {
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^install --cask drod3763/tap/openin-helper$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 1 ]]
}

@test "GIVEN required app present and helper absent EXPECT helper cask is installed" {
  mkdir -p "${MOCK_APPS_DIR}/OpenIn.app"

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^install --cask drod3763/tap/openin-helper$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN helper already installed EXPECT helper cask install is not attempted" {
  mkdir -p "${MOCK_APPS_DIR}/OpenIn.app" "${MOCK_APPS_DIR}/OpenIn Helper.app"

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^install --cask drod3763/tap/openin-helper$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 1 ]]
}
