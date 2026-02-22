#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_96_sync-opencode-mcp.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}" "${TEST_TMPDIR}/home/.config/opencode"

  cat > "${MOCK_BIN_DIR}/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-e" ]]; then
  exit 1
fi

if [[ "${1:-}" == "--slurpfile" ]]; then
  printf '%s\n' '{"mcp":{"demo":{"command":"demo"}}}'
  exit 0
fi

exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/jq"
  export HOME="${TEST_TMPDIR}/home"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  cat > "${HOME}/.config/opencode/mcp.json" <<'EOF'
{"demo":{"command":"demo"}}
EOF

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_96_sync-opencode-mcp.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN mcp file exists EXPECT opencode config is created and updated" {
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run test -f "${HOME}/.config/opencode/opencode.json"
  [[ "${status}" -eq 0 ]]
}
