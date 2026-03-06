#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  HOOK_SCRIPT="${REPO_ROOT}/scripts/hooks/read-source-state-pre.sh"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_UNAME_S:-Darwin}"
EOF

  cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_BREW_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/op" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/age" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/uname" "${MOCK_BIN_DIR}/brew" "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/age"

  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  export PATH="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin"
  export OP_SERVICE_ACCOUNT_TOKEN="dummy-token"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN missing op and age EXPECT hook installs 1Password CLI and age" {
  rm -f "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/age"

  run bash "${HOOK_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^install --cask 1password-cli$' "${MOCK_BREW_CALLS_FILE}"
  [ "${status}" -eq 0 ]
  run grep -q '^install age$' "${MOCK_BREW_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN non-darwin EXPECT hook exits without brew calls" {
  export MOCK_UNAME_S="Linux"
  rm -f "${MOCK_BREW_CALLS_FILE}"

  run bash "${HOOK_SCRIPT}"

  [ "${status}" -eq 0 ]
  run test ! -s "${MOCK_BREW_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN token unset in non-interactive shell EXPECT hook skips token prompt" {
  unset OP_SERVICE_ACCOUNT_TOKEN

  run bash "${HOOK_SCRIPT}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipping 1Password service account setup (no interactive terminal)."* ]]
}
