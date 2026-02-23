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

if [[ "${1:-}" == "age-keygen" && "${2:-}" == "-y" ]]; then
  printf '%s\n' 'age1testrecipient'
  exit 0
fi

exit 1
EOF

  chmod +x "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/age" "${MOCK_BIN_DIR}/chezmoi"

  export HOME="${TEST_TMPDIR}/home"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/age-bootstrap.sh"
  "${REAL_CHEZMOI_BIN}" execute-template --source "${REPO_ROOT}" < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN configured sources but no identities returned EXPECT script fails" {
  unset MOCK_OP_IDENTITY

  run bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 1 ]
}

@test "GIVEN identities returned EXPECT script writes bootstrap files" {
  export MOCK_OP_IDENTITY="AGE-SECRET-KEY-TEST"

  run bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ -f "${HOME}/.config/chezmoi/age-identities/identities.txt" ]
  [ -f "${HOME}/.config/chezmoi/age-identities/recipients.txt" ]
  grep -Fx "AGE-SECRET-KEY-TEST" "${HOME}/.config/chezmoi/age-identities/identities.txt"
  grep -Fx "age1testrecipient" "${HOME}/.config/chezmoi/age-identities/recipients.txt"
}
