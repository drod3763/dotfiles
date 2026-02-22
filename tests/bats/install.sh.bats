#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  INSTALL_SCRIPT="${REPO_ROOT}/install.sh"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-m" ]]; then
  printf '%s\n' 'x86_64'
else
  printf '%s\n' 'Linux'
fi
EOF

  cat > "${MOCK_BIN_DIR}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "config" && "${2:-}" == "--global" && "${3:-}" == "user.name" ]]; then
  if [[ -n "${MOCK_GIT_CONFIG_MISSING:-}" && $# -eq 3 ]]; then
    exit 1
  fi
  if [[ $# -gt 3 ]]; then
    printf '%s\n' "$*" >> "${MOCK_GIT_CALLS_FILE:?}"
    exit 0
  fi
  printf '%s\n' 'Test User'
  exit 0
fi

if [[ "${1:-}" == "config" && "${2:-}" == "--global" && "${3:-}" == "user.email" ]]; then
  if [[ -n "${MOCK_GIT_CONFIG_MISSING:-}" && $# -eq 3 ]]; then
    exit 1
  fi
  if [[ $# -gt 3 ]]; then
    printf '%s\n' "$*" >> "${MOCK_GIT_CALLS_FILE:?}"
    exit 0
  fi
  printf '%s\n' 'test@example.com'
  exit 0
fi

exit 0
EOF

  cat > "${MOCK_BIN_DIR}/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_CHEZMOI_CALLS_FILE:?}"
exit 0
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

  chmod +x "${MOCK_BIN_DIR}/uname" "${MOCK_BIN_DIR}/git" "${MOCK_BIN_DIR}/chezmoi" "${MOCK_BIN_DIR}/brew" "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/age"

  export MOCK_CHEZMOI_CALLS_FILE="${TEST_TMPDIR}/chezmoi.calls"
  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  export MOCK_GIT_CALLS_FILE="${TEST_TMPDIR}/git.calls"
  export OP_SERVICE_ACCOUNT_TOKEN="dummy-token"
  export PATH="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN verbose flag EXPECT install script calls chezmoi apply with verbose and force refresh" {
  run bash "${INSTALL_SCRIPT}" --verbose

  [ "${status}" -eq 0 ]
  run grep -q '^init --source=' "${MOCK_CHEZMOI_CALLS_FILE}"
  [ "${status}" -eq 0 ]
  run grep -q '^apply --force --refresh-externals --verbose$' "${MOCK_CHEZMOI_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN missing op and age EXPECT install script installs required brew packages" {
  rm -f "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/age"

  run bash "${INSTALL_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^install --cask 1password-cli$' "${MOCK_BREW_CALLS_FILE}"
  [ "${status}" -eq 0 ]
  run grep -q '^install age$' "${MOCK_BREW_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN missing git config EXPECT install script sets placeholder values" {
  export MOCK_GIT_CONFIG_MISSING=1

  run bash "${INSTALL_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^config --global user.name Temporary User$' "${MOCK_GIT_CALLS_FILE}"
  [ "${status}" -eq 0 ]
  run grep -q '^config --global user.email temp@example.com$' "${MOCK_GIT_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}
