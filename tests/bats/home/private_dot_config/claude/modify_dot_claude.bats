#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/private_dot_config/claude/modify_private_dot_claude.json.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  export PATH="${MOCK_BIN_DIR}:${PATH}"

  cat >"${MOCK_BIN_DIR}/op" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "signin" ]]; then
  printf '%s\n' 'mock-session'
  exit 0
fi

if [[ "$*" == *"item get"* ]]; then
  cat <<'JSON'
{
  "fields": [
    {
      "id": "ffpafb4xoc64jwnrtqgktcjiyq",
      "value": "ghp_mock"
    },
    {
      "id": "launchdarkly-token",
      "label": "launchdarkly reader token",
      "value": "ld_mock"
    }
  ]
}
JSON
  exit 0
fi

exit 1
EOF

  chmod +x "${MOCK_BIN_DIR}/op"

  RENDERED_SCRIPT="${TEST_TMPDIR}/modify_dot_claude"
  "${REAL_CHEZMOI_BIN}" execute-template <"${TEMPLATE_PATH}" >"${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN existing claude state EXPECT only mcpServers is replaced" {
  input_file="${TEST_TMPDIR}/input.json"
  output_file="${TEST_TMPDIR}/output.json"
  cat >"${input_file}" <<'JSON'
{
  "keep": true,
  "mcpServers": {
    "old": {
      "command": "old"
    }
  }
}
JSON

  run bash -c '"${0}" <"${1}" >"${2}"' "${RENDERED_SCRIPT}" "${input_file}" "${output_file}"

  [[ "${status}" -eq 0 ]]
  run jq -e '.keep == true' "${output_file}"
  [[ "${status}" -eq 0 ]]
  run jq -e '.mcpServers.old == null' "${output_file}"
  [[ "${status}" -eq 0 ]]
  run jq -e '.mcpServers.github.headers.Authorization == "Bearer ghp_mock"' "${output_file}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN invalid claude state EXPECT script creates json object with mcpServers" {
  output_file="${TEST_TMPDIR}/output.json"

  run bash -c 'printf "%s\n" "not-json" | "${0}" >"${1}"' "${RENDERED_SCRIPT}" "${output_file}"

  [[ "${status}" -eq 0 ]]
  run jq -e '.mcpServers.github.headers.Authorization == "Bearer ghp_mock"' "${output_file}"
  [[ "${status}" -eq 0 ]]
}
