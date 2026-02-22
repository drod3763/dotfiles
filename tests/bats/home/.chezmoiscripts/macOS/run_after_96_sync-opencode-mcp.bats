#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_96_sync-opencode-mcp.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}" "${TEST_TMPDIR}/home/.config/opencode"

  export HOME="${TEST_TMPDIR}/home"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_JQ_CALLS_FILE="${TEST_TMPDIR}/jq.calls"
  export MOCK_TMP_FILE="${TEST_TMPDIR}/jq.tmp"

  cat > "${MOCK_BIN_DIR}/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_JQ_CALLS_FILE:?}"

if [[ "${1:-}" == "-e" ]]; then
  if [[ -n "${MOCK_JQ_VALID_TARGET:-}" ]]; then
    exit 0
  fi
  exit 1
fi

if [[ "${1:-}" == "--slurpfile" ]]; then
  if [[ -n "${MOCK_JQ_MERGE_FAIL:-}" ]]; then
    exit 1
  fi
  if [[ -n "${MOCK_JQ_PASSTHROUGH_TARGET:-}" ]]; then
    target_file="${4:-}"
    cat "${target_file}"
    exit 0
  fi
  printf '%s\n' '{"mcp":{"demo":{"command":"demo"}}}'
  exit 0
fi

exit 0
EOF

  cat > "${MOCK_BIN_DIR}/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${MOCK_TMP_FILE:?}"
: > "${MOCK_TMP_FILE:?}"
EOF

  chmod +x "${MOCK_BIN_DIR}/jq" "${MOCK_BIN_DIR}/mktemp"

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

@test "GIVEN mcp file missing EXPECT script exits without jq merge" {
  rm -f "${HOME}/.config/opencode/mcp.json"

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  if [[ -f "${MOCK_JQ_CALLS_FILE}" ]]; then
    run grep -q '^--slurpfile' "${MOCK_JQ_CALLS_FILE}"
    [[ "${status}" -eq 1 ]]
  fi
}

@test "GIVEN jq missing EXPECT script exits without writing opencode config" {
  rm -f "${MOCK_BIN_DIR}/jq"

  run env PATH="${MOCK_BIN_DIR}" /bin/bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run test -f "${HOME}/.config/opencode/opencode.json"
  [[ "${status}" -eq 1 ]]
}

@test "GIVEN valid target JSON EXPECT default bootstrap content is not rewritten" {
  export MOCK_JQ_VALID_TARGET=1
  export MOCK_JQ_PASSTHROUGH_TARGET=1
  printf '%s\n' '{"keep":true}' > "${HOME}/.config/opencode/opencode.json"

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '"keep":true' "${HOME}/.config/opencode/opencode.json"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN jq merge fails EXPECT script exits non-zero and temp file is cleaned" {
  export MOCK_JQ_MERGE_FAIL=1

  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -ne 0 ]]
  run test -f "${MOCK_TMP_FILE}"
  [[ "${status}" -ne 0 ]]
}
