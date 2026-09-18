#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_onchange_after_98a_configure-brew-apps.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  TEST_HOME="${TEST_TMPDIR}/home"
  TEST_LAUNCHDAEMONS_DIR="${TEST_TMPDIR}/LaunchDaemons"
  mkdir -p "${MOCK_BIN_DIR}" "${TEST_HOME}/.config/yazi/flavors/catppuccin-mocha.yazi" "${TEST_LAUNCHDAEMONS_DIR}"

  cat > "${MOCK_BIN_DIR}/tldr" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/defaults" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_DEFAULTS_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/ya" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_YA_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/java" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_CURL_CALLS_FILE:?}"
printf '%s\n' "touch \"${MOCK_ITERM_MARKER_FILE:?}\""
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

printf '%s\n' "$*" >> "${MOCK_SUDO_CALLS_FILE:?}"
exit 0
EOF

  # Present so `lookPath "tailscale"` renders the tailscale block deterministically,
  # regardless of whether the host running the suite has tailscale installed.
  cat > "${MOCK_BIN_DIR}/tailscale" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  version)
    printf '%s\n' "1.102.4"
    printf '  tailscale commit: 0000000000000000000000000000000000000000\n'
    printf '  long version: %s\n' "${MOCK_TAILSCALE_INSTALLED_BUILD:-}"
    ;;
  status)
    if [[ -n "${MOCK_TAILSCALE_STATUS_FAILS:-}" ]]; then
      exit 1
    fi
    printf '{"BackendState":"Running","Version":"%s"}\n' "${MOCK_TAILSCALE_RUNNING_BUILD:-}"
    ;;
  *)
    exit 0
    ;;
esac
EOF

  # Narrow stand-in: this script only ever pipes tailscale JSON through
  # `jq -r '.Version // empty'` / `.AuthURL // empty`, plus a `jq -e` predicate.
  cat > "${MOCK_BIN_DIR}/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_JQ_CALLS_FILE:?}"

input="$(cat)"
[[ -n "${input}" ]] || exit 1

if [[ "${1:-}" == "-e" ]]; then
  exit 1
fi

case "${2:-}" in
  *.Version*) mock_jq_key="Version" ;;
  *.AuthURL*) mock_jq_key="AuthURL" ;;
  *) exit 1 ;;
esac

printf '%s\n' "${input}" |
  sed -n "s/.*\"${mock_jq_key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
EOF

  chmod +x "${MOCK_BIN_DIR}/tldr" "${MOCK_BIN_DIR}/defaults" "${MOCK_BIN_DIR}/ya" "${MOCK_BIN_DIR}/java" "${MOCK_BIN_DIR}/sudo" "${MOCK_BIN_DIR}/curl" "${MOCK_BIN_DIR}/tailscale" "${MOCK_BIN_DIR}/jq"

  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_YA_CALLS_FILE="${TEST_TMPDIR}/ya.calls"
  export MOCK_SUDO_CALLS_FILE="${TEST_TMPDIR}/sudo.calls"
  export MOCK_DEFAULTS_CALLS_FILE="${TEST_TMPDIR}/defaults.calls"
  export MOCK_CURL_CALLS_FILE="${TEST_TMPDIR}/curl.calls"
  export MOCK_JQ_CALLS_FILE="${TEST_TMPDIR}/jq.calls"
  export MOCK_ITERM_MARKER_FILE="${TEST_TMPDIR}/iterm-installer.ran"

  # Default tailscale fixture: daemon already registered under the current Homebrew
  # service-file name, running exactly the build that is installed.
  export MOCK_TAILSCALE_INSTALLED_BUILD="1.102.4-tbbcd7d1fc"
  export MOCK_TAILSCALE_RUNNING_BUILD="1.102.4-tbbcd7d1fc"
  touch "${TEST_LAUNCHDAEMONS_DIR}/sh.brew.tailscale.plist"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_98a_configure-brew-apps.sh"
  render_script '{"personal":true}'
}

# Renders the template and redirects the hardcoded /Library/LaunchDaemons lookups at a
# test-local directory so plist fixtures never depend on real system state.
render_script() {
  local override_json="$1"
  local override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' "${override_json}" > "${override_file}"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" |
    sed "s|/Library/LaunchDaemons|${TEST_LAUNCHDAEMONS_DIR}|g" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

render_non_personal_script() {
  render_script '{"personal":false}'
}

run_rendered_script() {
  run env -u SSH_CONNECTION HOME="${TEST_HOME}" PATH="${PATH}" "$@" bash "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN personal profile EXPECT script executes without sudo-required work steps" {
  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN yazi flavor missing EXPECT script installs catppuccin flavor" {
  rm -rf "${TEST_HOME}/.config/yazi/flavors/catppuccin-mocha.yazi"

  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^pkg add yazi-rs/flavors:catppuccin-mocha$' "${MOCK_YA_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN non-personal with java EXPECT script runs sudo java symlink command" {
  render_non_personal_script

  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q 'ln -sfn /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN forced hosts update path EXPECT script writes hosts entry via sudo tee" {
  render_non_personal_script
  forced_script="${TEST_TMPDIR}/run_after_98a_configure-brew-apps-forced-hosts.sh"
  cp "${RENDERED_SCRIPT}" "${forced_script}"
  printf '\nprintf %s\\n "127.0.0.1 corp.local" | with_sudo tee -a /etc/hosts >/dev/null\n' "'%s'" >> "${forced_script}"
  chmod +x "${forced_script}"

  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${forced_script}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^tee -a /etc/hosts$' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN forced iTerm branch EXPECT script runs integration installer pipeline" {
  forced_script="${TEST_TMPDIR}/run_after_98a_configure-brew-apps-forced-iterm.sh"
  cp "${RENDERED_SCRIPT}" "${forced_script}"
  printf '\ncurl --location https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash\n' >> "${forced_script}"
  chmod +x "${forced_script}"

  run env HOME="${TEST_HOME}" PATH="${PATH}" bash "${forced_script}"

  [[ "${status}" -eq 0 ]]
  run test -f "${MOCK_ITERM_MARKER_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN no tailscale launch daemon EXPECT script registers root service via sudo" {
  rm -f "${TEST_LAUNCHDAEMONS_DIR}/sh.brew.tailscale.plist"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -qx 'brew services start tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN sh.brew tailscale plist EXPECT script skips service start" {
  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -q 'brew services start tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN legacy homebrew.mxcl tailscale plist EXPECT script skips service start" {
  rm -f "${TEST_LAUNCHDAEMONS_DIR}/sh.brew.tailscale.plist"
  touch "${TEST_LAUNCHDAEMONS_DIR}/homebrew.mxcl.tailscale.plist"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -q 'brew services start tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN running tailscaled matches installed build EXPECT script skips service restart" {
  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -q 'brew services restart tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN stale tailscaled build off SSH EXPECT script restarts service via sudo" {
  run_rendered_script MOCK_TAILSCALE_RUNNING_BUILD="1.100.0-taaaaaaaaa"

  [[ "${status}" -eq 0 ]]
  run grep -qx 'brew services restart tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN stale tailscaled build over SSH EXPECT script defers restart with guidance" {
  run_rendered_script MOCK_TAILSCALE_RUNNING_BUILD="1.100.0-taaaaaaaaa" SSH_CONNECTION="100.84.54.16 52000 100.84.54.17 22"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"sudo brew services restart tailscale"* ]]
  run grep -q 'brew services restart tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN unreachable tailscaled EXPECT script skips service restart" {
  run_rendered_script MOCK_TAILSCALE_STATUS_FAILS=1

  [[ "${status}" -eq 0 ]]
  run grep -q 'brew services restart tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN tailscale reports no running build EXPECT script skips service restart" {
  run_rendered_script MOCK_TAILSCALE_RUNNING_BUILD=""

  [[ "${status}" -eq 0 ]]
  run grep -q 'brew services restart tailscale' "${MOCK_SUDO_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}
