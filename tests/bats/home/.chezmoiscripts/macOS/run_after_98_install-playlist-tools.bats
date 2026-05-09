#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_once_after_98_install-playlist-tools.sh.tmpl"
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

if [[ "${1:-}" == "auth" && "${2:-}" == "login" && -n "${MOCK_GH_LOGIN_FAIL:-}" ]]; then
  exit 1
fi

printf '%s\n' "$*" >> "${MOCK_GH_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/op" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "item" && "${2:-}" == "get" ]]; then
  if [[ -n "${MOCK_OP_FAIL:-}" ]]; then
    exit 1
  fi
  printf '%s' "${MOCK_OP_TOKEN:-ghp_test_token}"
  exit 0
fi

exit 1
EOF

cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list" && "${2:-}" == "--formula" && "${3:-}" == "pipemind" ]]; then
  if [[ -n "${MOCK_PIPEMIND_INSTALLED:-}" ]]; then
    exit 0
  fi
  exit 1
fi

if [[ "${1:-}" == "tap" && -n "${MOCK_BREW_TAP_FAIL:-}" ]]; then
  exit 1
fi

if [[ "${1:-}" == "install" && -n "${MOCK_BREW_INSTALL_FAIL:-}" ]]; then
  exit 1
fi

printf '%s\n' "$*" >> "${MOCK_BREW_CALLS_FILE:?}"
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/gh" "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/brew"
  export MOCK_GH_CALLS_FILE="${TEST_TMPDIR}/gh.calls"
  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' '{"personal":true}' > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_98_install-playlist-tools.sh"
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

@test "GIVEN non-personal and unauthenticated gh EXPECT script logs in with token and installs tools" {
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^auth login --hostname github.com --with-token$' "${MOCK_GH_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q '^tap playlist-tech/tap$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q '^list --formula pipemind$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q '^install playlist-tech/tap/pipemind$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN non-personal and pipemind already installed EXPECT script skips install" {
  export MOCK_GH_AUTHENTICATED=1
  export MOCK_PIPEMIND_INSTALLED=1
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^list --formula pipemind$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q '^install playlist-tech/tap/pipemind$' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 1 ]]
}

@test "GIVEN non-personal and authenticated gh EXPECT script skips gh auth login" {
  export MOCK_GH_AUTHENTICATED=1
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^auth login --hostname github.com --with-token$' "${MOCK_GH_CALLS_FILE}"
  [[ "${status}" -eq 1 ]]
  run grep -q '^auth setup-git$' "${MOCK_GH_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN gh login fails EXPECT script exits non-zero" {
  export MOCK_GH_LOGIN_FAIL=1
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -ne 0 ]]
}

@test "GIVEN unauthenticated gh and token lookup fails EXPECT script exits non-zero" {
  export MOCK_OP_FAIL=1
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -ne 0 ]]
}

@test "GIVEN unauthenticated gh and token lookup fails EXPECT pasted token is used" {
  export MOCK_OP_FAIL=1
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}" <<< "ghp_pasted_token"

  [[ "${status}" -eq 0 ]]
  run grep -q '^auth login --hostname github.com --with-token$' "${MOCK_GH_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN brew tap fails EXPECT script exits non-zero" {
  export MOCK_GH_AUTHENTICATED=1
  export MOCK_BREW_TAP_FAIL=1
  render_non_personal_script

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -ne 0 ]]
}
