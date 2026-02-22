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
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/tldr" "${MOCK_BIN_DIR}/defaults" "${MOCK_BIN_DIR}/ya"

  export PATH="${MOCK_BIN_DIR}:${PATH}"

  override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' '{"personal":true}' > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_onchange_after_configure-brew-apps.sh"
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
