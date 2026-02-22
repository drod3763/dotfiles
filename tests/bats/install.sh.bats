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
  printf '%s\n' "${MOCK_UNAME_M:-x86_64}"
else
  printf '%s\n' "${MOCK_UNAME_S:-Linux}"
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

  cat > "${MOCK_BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-n" && "${2:-}" == "true" ]]; then
  exit 0
fi

if [[ "${1:-}" == "-v" ]]; then
  exit 0
fi

exit 0
EOF

  cat > "${MOCK_BIN_DIR}/caffeinate" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_CAFFEINATE_CALLS_FILE:?}"

while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == -* ]]; then
    shift
    continue
  fi
  break
done

"$@"
EOF

  cat > "${MOCK_BIN_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_CURL_CALLS_FILE:?}"
printf '%s\n' 'exit 0'
EOF

  cat > "${MOCK_BIN_DIR}/xcode-select" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_XCODE_CALLS_FILE:?}"

if [[ "${1:-}" == "-p" ]]; then
  if [[ -n "${MOCK_XCODE_MISSING:-}" ]]; then
    exit 1
  fi
  exit 0
fi

if [[ "${1:-}" == "--install" ]]; then
  exit 0
fi

exit 0
EOF

  cat > "${MOCK_BIN_DIR}/op" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-s" ]]; then
  shift
fi

if [[ "${1:-}" == "--" ]]; then
  shift
fi

bin_dir=""
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == "-b" ]]; then
    bin_dir="$2"
    shift 2
    continue
  fi
  shift
done

if [[ -n "${bin_dir}" ]]; then
  mkdir -p "${bin_dir}"
  cat > "${bin_dir}/chezmoi" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_CHEZMOI_CALLS_FILE:?}"
exit 0
INNER
  chmod +x "${bin_dir}/chezmoi"
fi

cat >/dev/null
EOF

  cat > "${MOCK_BIN_DIR}/age" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/uname" "${MOCK_BIN_DIR}/git" "${MOCK_BIN_DIR}/chezmoi" "${MOCK_BIN_DIR}/brew" "${MOCK_BIN_DIR}/op" "${MOCK_BIN_DIR}/age" "${MOCK_BIN_DIR}/sudo" "${MOCK_BIN_DIR}/caffeinate" "${MOCK_BIN_DIR}/curl" "${MOCK_BIN_DIR}/xcode-select" "${MOCK_BIN_DIR}/sh"

  export MOCK_CHEZMOI_CALLS_FILE="${TEST_TMPDIR}/chezmoi.calls"
  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  export MOCK_GIT_CALLS_FILE="${TEST_TMPDIR}/git.calls"
  export MOCK_CAFFEINATE_CALLS_FILE="${TEST_TMPDIR}/caffeinate.calls"
  export MOCK_CURL_CALLS_FILE="${TEST_TMPDIR}/curl.calls"
  export MOCK_XCODE_CALLS_FILE="${TEST_TMPDIR}/xcode.calls"
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

@test "GIVEN VERBOSE env EXPECT install script applies with verbose" {
  run env VERBOSE=1 bash "${INSTALL_SCRIPT}"

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

@test "GIVEN caffeinate available EXPECT apply runs through caffeinate wrapper" {
  run bash "${INSTALL_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^-dim chezmoi apply --force --refresh-externals$' "${MOCK_CAFFEINATE_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN Darwin with missing brew EXPECT install script triggers Homebrew bootstrap" {
  export MOCK_UNAME_S="Darwin"
  rm -f "${MOCK_BIN_DIR}/brew"

  run bash "${INSTALL_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' "${MOCK_CURL_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN missing chezmoi EXPECT installer bootstraps it via sh pipe" {
  rm -f "${MOCK_BIN_DIR}/chezmoi"

  run bash "${INSTALL_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^init --source=' "${MOCK_CHEZMOI_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN token unset EXPECT installer prompts and continues when skipped" {
  unset OP_SERVICE_ACCOUNT_TOKEN

  run bash "${INSTALL_SCRIPT}" <<<""

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Skipping 1Password service account setup."* ]]
}

@test "GIVEN token unset and provided EXPECT installer acknowledges token setup" {
  unset OP_SERVICE_ACCOUNT_TOKEN

  run bash "${INSTALL_SCRIPT}" <<<"token-value"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1Password service account token set."* ]]
}

@test "GIVEN Darwin and missing xcode tools EXPECT installer runs xcode-select --install" {
  export MOCK_UNAME_S="Darwin"
  export MOCK_XCODE_MISSING=1

  run bash "${INSTALL_SCRIPT}" <<<""

  [ "${status}" -eq 0 ]
  run grep -q '^--install$' "${MOCK_XCODE_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN caffeinate unavailable EXPECT installer falls back to direct chezmoi apply" {
  rm -f "${MOCK_BIN_DIR}/caffeinate"

  run bash "${INSTALL_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^apply --force --refresh-externals$' "${MOCK_CHEZMOI_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}
