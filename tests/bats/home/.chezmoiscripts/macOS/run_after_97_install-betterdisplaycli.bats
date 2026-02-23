#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_97_install-betterdisplaycli.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  MOCK_APPS_DIR="${TEST_TMPDIR}/Applications"
  mkdir -p "${MOCK_BIN_DIR}" "${MOCK_APPS_DIR}"

  cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list" && "${2:-}" == "--formula" ]]; then
  if [[ -n "${MOCK_BREW_HAS_BETTERDISPLAYCLI:-}" ]]; then
    exit 0
  fi
  exit 1
fi

printf '%s\n' "$*" >> "${MOCK_BREW_CALLS_FILE:?}"
exit 0
EOF

chmod +x "${MOCK_BIN_DIR}/brew"
export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
export PATH="${MOCK_BIN_DIR}:${PATH}"

  override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' '{"personal":true}' > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_97_install-betterdisplaycli.sh"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

render_non_personal_script() {
  local override_file="${TEST_TMPDIR}/override-non-personal.json"
  local raw_script="${TEST_TMPDIR}/run_after_97_install-betterdisplaycli.raw.sh"
  printf '%s\n' '{"personal":false}' > "${override_file}"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${raw_script}"
  sed "s|/Applications|${MOCK_APPS_DIR}|g" "${raw_script}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN personal profile EXPECT betterdisplay post-install script no-ops cleanly" {
  run bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN non-personal and Xcode installed EXPECT betterdisplaycli is installed" {
  render_non_personal_script
  mkdir -p "${MOCK_APPS_DIR}/Xcode.app"

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^install betterdisplaycli$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN non-personal and Xcode missing EXPECT script skips install" {
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^install betterdisplaycli$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN non-personal and formula already installed EXPECT install is not repeated" {
  render_non_personal_script
  mkdir -p "${MOCK_APPS_DIR}/Xcode.app"
  export MOCK_BREW_HAS_BETTERDISPLAYCLI=1

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^install betterdisplaycli$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN non-personal and brew missing EXPECT script exits cleanly without install" {
  render_non_personal_script
  rm -f "${MOCK_BIN_DIR}/brew"

  run env PATH="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run test -f "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}
