#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_onchange_after_configure-brew-apps.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  TEST_HOME="${TEST_TMPDIR}/home"
  mkdir -p "${MOCK_BIN_DIR}" "${TEST_HOME}/.config/yazi/flavors/catppuccin-mocha.yazi"

  cat > "${MOCK_BIN_DIR}/tldr" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/defaults" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/ya" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_YA_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/java" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-n" && "${2:-}" == "true" ]]; then
  exit 0
fi

if [[ "${1:-}" == "-v" ]]; then
  exit 0
fi

printf '%s\n' "$*" >> "${MOCK_SUDO_CALLS_FILE:?}"
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/tldr" "${MOCK_BIN_DIR}/defaults" "${MOCK_BIN_DIR}/ya" "${MOCK_BIN_DIR}/java" "${MOCK_BIN_DIR}/sudo"

  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_YA_CALLS_FILE="${TEST_TMPDIR}/ya.calls"
  export MOCK_SUDO_CALLS_FILE="${TEST_TMPDIR}/sudo.calls"

  override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' '{"personal":true}' > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_onchange_after_configure-brew-apps.sh"
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

@test "GIVEN personal profile EXPECT script executes without sudo-required work steps" {
  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN yazi flavor missing EXPECT script installs catppuccin flavor" {
  rm -rf "${TEST_HOME}/.config/yazi/flavors/catppuccin-mocha.yazi"

  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^pkg add yazi-rs/flavors:catppuccin-mocha$' "${MOCK_YA_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN non-personal with java EXPECT script runs sudo java symlink command" {
  render_non_personal_script

  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q 'ln -sfn /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN forced hosts update path EXPECT script writes hosts entry via sudo tee" {
  render_non_personal_script
  forced_script="${TEST_TMPDIR}/run_onchange_after_configure-brew-apps-forced-hosts.sh"
  cp "${RENDERED_SCRIPT}" "${forced_script}"
  printf '\nprintf %s\\n "127.0.0.1 corp.local" | with_sudo tee -a /etc/hosts >/dev/null\n' "'%s'" >> "${forced_script}"
  chmod +x "${forced_script}"

  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${forced_script}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^tee -a /etc/hosts$' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}
