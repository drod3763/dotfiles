#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_install-playlist-tools.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
  if [[ -n "${MOCK_GH_AUTHENTICATED:-}" ]]; then
    exit 0
  fi
  exit 1
fi

printf '%s\n' "$*" >> "${MOCK_GH_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_BREW_CALLS_FILE:?}"
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/gh" "${MOCK_BIN_DIR}/brew"
  export MOCK_GH_CALLS_FILE="${TEST_TMPDIR}/gh.calls"
  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' '{"personal":true}' > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_install-playlist-tools.sh"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

render_non_personal_script() {
  local override_file="${TEST_TMPDIR}/override-non-personal.json"
  printf '%s\n' '{"personal":false}' > "${override_file}"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN personal profile EXPECT playlist tools post-install script no-ops cleanly" {
  run bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN non-personal and unauthenticated gh EXPECT script logs in and installs tools" {
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^auth login$' "${MOCK_GH_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q '^tap playlist-tech/tap$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q '^install playlist-tech/tap/pipemind$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}
