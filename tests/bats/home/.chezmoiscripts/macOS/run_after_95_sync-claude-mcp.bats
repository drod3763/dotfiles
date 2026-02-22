#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_95_sync-claude-mcp.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}" "${TEST_TMPDIR}/home/.config/claude"

  export HOME="${TEST_TMPDIR}/home"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_JQ_CALLS_FILE="${TEST_TMPDIR}/jq.calls"

  cat > "${MOCK_BIN_DIR}/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_JQ_CALLS_FILE:?}"

if [[ "${1:-}" == "-e" ]]; then
  exit 1
fi

if [[ "${1:-}" == "--slurpfile" ]]; then
  printf '%s\n' '{"mcpServers":{"demo":{"command":"demo"}}}'
  exit 0
fi

exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/jq"

  cat > "${HOME}/.config/claude/mcp-servers.json" <<'EOF'
{"demo":{"command":"demo"}}
EOF

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_95_sync-claude-mcp.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN mcp file exists EXPECT claude config is created and updated" {
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run test -f "${HOME}/.config/claude/.claude.json"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN mcp file missing EXPECT script exits without jq merge" {
  rm -f "${HOME}/.config/claude/mcp-servers.json"

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  if [[ -f "${MOCK_JQ_CALLS_FILE}" ]]; then
    run grep -q '^--slurpfile' "${MOCK_JQ_CALLS_FILE}"
    [[ "${status}" -eq 1 ]]
  fi
}
