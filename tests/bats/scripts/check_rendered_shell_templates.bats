#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CHECK_SCRIPT="${REPO_ROOT}/scripts/check_rendered_shell_templates.sh"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  MOCK_REPO_ROOT="${TEST_TMPDIR}/repo"
  mkdir -p "${MOCK_BIN_DIR}" "${MOCK_REPO_ROOT}/home/.chezmoiscripts/macOS" "${MOCK_REPO_ROOT}/home/.chezmoitemplates"

  cat > "${MOCK_REPO_ROOT}/home/.chezmoiscripts/macOS/a.sh.tmpl" <<'EOF'
#!/usr/bin/env bash
echo a
EOF
  cat > "${MOCK_REPO_ROOT}/home/.chezmoiscripts/macOS/b.sh.tmpl" <<'EOF'
#!/usr/bin/env bash
echo b
EOF

  cat > "${MOCK_BIN_DIR}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--show-toplevel" ]]; then
  printf '%s\n' "${MOCK_REPO_ROOT:?}"
  exit 0
fi

if [[ "${1:-}" == "diff" && "${2:-}" == "--cached" ]]; then
  printf '%s' "${MOCK_STAGED_PATHS:-}"
  exit 0
fi

if [[ "${1:-}" == "ls-files" ]]; then
  printf '%s\n' 'home/.chezmoiscripts/macOS/a.sh.tmpl'
  printf '%s\n' 'home/.chezmoiscripts/macOS/b.sh.tmpl'
  exit 0
fi

exit 1
EOF

  cat > "${MOCK_BIN_DIR}/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat
EOF

  cat > "${MOCK_BIN_DIR}/shellcheck" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1}" >> "${MOCK_SHELLCHECK_CALLS_FILE:?}"
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/git" "${MOCK_BIN_DIR}/chezmoi" "${MOCK_BIN_DIR}/shellcheck"

  export MOCK_REPO_ROOT
  export MOCK_SHELLCHECK_CALLS_FILE="${TEST_TMPDIR}/shellcheck.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN no staged shell templates EXPECT checker exits without shellcheck runs" {
  export MOCK_STAGED_PATHS='README.md'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ ! -f "${MOCK_SHELLCHECK_CALLS_FILE}" ]
}

@test "GIVEN staged shared template EXPECT checker validates all script templates" {
  export MOCK_STAGED_PATHS='home/.chezmoitemplates/sudo_helpers.tmpl'

  run bash "${CHECK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ "$(wc -l < "${MOCK_SHELLCHECK_CALLS_FILE}" | tr -d ' ')" -eq 2 ]
}
