#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_98c_restart-stale-moshi-hook.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  # Present so `lookPath "moshi-hook"` renders the script body deterministically.
  cat > "${MOCK_BIN_DIR}/moshi-hook" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ -n "${MOCK_MOSHI_HOOK_PID:-}" ]] || exit 1
printf '%s\n' "${MOCK_MOSHI_HOOK_PID}"
EOF

  cat > "${MOCK_BIN_DIR}/lsof" <<'EOF'
#!/usr/bin/env bash
printf 'p%s\n' "${MOCK_MOSHI_HOOK_PID:-}"
printf 'ftxt\n'
if [[ -n "${MOCK_MOSHI_HOOK_RUNNING:-}" ]]; then
  printf 'n%s\n' "${MOCK_MOSHI_HOOK_RUNNING}"
  printf 'ftxt\nn/usr/lib/dyld\n'
fi
EOF

  cat > "${MOCK_BIN_DIR}/realpath" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_MOSHI_HOOK_INSTALLED:?}"
EOF

  cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MOCK_BREW_CALLS_FILE:?}"
[[ -z "${MOCK_BREW_FAILS:-}" ]]
EOF

  chmod +x "${MOCK_BIN_DIR}"/*

  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_BREW_CALLS_FILE="${TEST_TMPDIR}/brew.calls"
  touch "${MOCK_BREW_CALLS_FILE}"

  # Default fixture: daemon running exactly the installed keg.
  export MOCK_MOSHI_HOOK_PID="1221"
  export MOCK_MOSHI_HOOK_INSTALLED="/opt/homebrew/Cellar/moshi-hook/0.4.9/bin/moshi-hook"
  export MOCK_MOSHI_HOOK_RUNNING="${MOCK_MOSHI_HOOK_INSTALLED}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_98c_restart-stale-moshi-hook.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

run_rendered_script() {
  run env PATH="${PATH}" "$@" bash "${RENDERED_SCRIPT}"
}

@test "GIVEN running daemon matches installed keg EXPECT no restart" {
  run_rendered_script

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_BREW_CALLS_FILE}" ]]
}

@test "GIVEN daemon running a stale keg EXPECT brew services restart" {
  run_rendered_script MOCK_MOSHI_HOOK_RUNNING="/opt/homebrew/Cellar/moshi-hook/0.3.26/bin/moshi-hook"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"0.3.26"*"0.4.9"* ]]
  run grep -qx 'services restart moshi-hook' "${MOCK_BREW_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN no daemon process EXPECT no restart" {
  run_rendered_script MOCK_MOSHI_HOOK_PID=""

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_BREW_CALLS_FILE}" ]]
}

@test "GIVEN lsof reports no executable EXPECT no restart" {
  run_rendered_script MOCK_MOSHI_HOOK_RUNNING=""

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_BREW_CALLS_FILE}" ]]
}

@test "GIVEN stale daemon and restart fails EXPECT warning without failing apply" {
  run_rendered_script MOCK_MOSHI_HOOK_RUNNING="/opt/homebrew/Cellar/moshi-hook/0.3.26/bin/moshi-hook" MOCK_BREW_FAILS=1

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Failed to restart moshi-hook"* ]]
}
