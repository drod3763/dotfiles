#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_before_90_bootstrap-age-identities.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/op" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${MOCK_OP_IDENTITY:-}" ]]; then
  printf '%s\n' "${MOCK_OP_IDENTITY}"
fi
EOF

  cat > "${MOCK_BIN_DIR}/age" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "source-path" ]]; then
  printf '%s\n' "${MOCK_SOURCE_ITEMS_FILE:?}"
  exit 0
fi

if [[ "${1:-}" == "age-keygen" && "${2:-}" == "-y" ]]; then
  printf '%s\n' 'age1testrecipient'
  exit 0
fi

exit 1
EOF

  chmod +x "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/age" "${MOCK_BIN_DIR}/chezmoi"

  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}/.local/share/chezmoi/home/private_dot_config/chezmoi"

  export MOCK_SOURCE_ITEMS_FILE="${HOME}/.local/share/chezmoi/home/private_dot_config/chezmoi/private_age-identities.items"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/age-bootstrap.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN configured sources but no identities returned EXPECT script fails" {
  cat > "${MOCK_SOURCE_ITEMS_FILE}" <<'EOF'
item-id vault-id
EOF
  unset MOCK_OP_IDENTITY

  run bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 1 ]
}

@test "GIVEN malformed env source entries EXPECT script ignores them and exits cleanly" {
  export CHEZMOI_AGE_IDENTITY_ITEMS="malformed-entry"
  unset MOCK_OP_IDENTITY

  run bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 0 ]
}
