#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_onchange_after_95_configure-passwordless-ssh.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  MOCK_HOME="${TEST_TMPDIR}/home"
  MOCK_ETC="${TEST_TMPDIR}/etc/ssh"
  mkdir -p "${MOCK_BIN_DIR}" "${MOCK_HOME}/.ssh" "${MOCK_ETC}"

  cat > "${MOCK_BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
exec "$@"
EOF

  cat > "${MOCK_BIN_DIR}/sshd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sshd %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/systemsetup" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemsetup %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
case "$1" in
  -getremotelogin)
    printf 'Remote Login: %s\n' "${MOCK_REMOTE_LOGIN_STATUS:-Off}"
    ;;
  -setremotelogin)
    if [[ "${MOCK_SYSTEMSETUP_FULL_DISK_ACCESS_FAILURE:-false}" == "true" ]]; then
      printf 'setremotelogin: Turning Remote Login on or off requires Full Disk Access privileges.\n' >&2
      exit 1
    fi
    exit 0
    ;;
esac
EOF

  cat > "${MOCK_BIN_DIR}/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'ssh-keygen %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
exit 0
EOF

  cat > "${MOCK_BIN_DIR}/launchctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'launchctl %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}/sudo" "${MOCK_BIN_DIR}/sshd" "${MOCK_BIN_DIR}/systemsetup" "${MOCK_BIN_DIR}/ssh-keygen" "${MOCK_BIN_DIR}/launchctl"

  export MOCK_CALLS_FILE="${TEST_TMPDIR}/calls.log"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export HOME="${MOCK_HOME}"
  export CHEZMOI_SSH_AUTHORIZED_KEYS="${MOCK_HOME}/.ssh/authorized_keys"
  export CHEZMOI_SSHD_CONFIG="${MOCK_ETC}/sshd_config"
  export CHEZMOI_SSHD_CONFIG_DIR="${MOCK_ETC}/sshd_config.d"
  export CHEZMOI_SSHD_BIN="${MOCK_BIN_DIR}/sshd"
  export CHEZMOI_SSH_KEYGEN_BIN="${MOCK_BIN_DIR}/ssh-keygen"
  export CHEZMOI_SSH_HOST_KEY_DIR="${MOCK_ETC}"
  export CHEZMOI_SYSTEMSETUP_BIN="${MOCK_BIN_DIR}/systemsetup"
  export CHEZMOI_LAUNCHCTL_BIN="${MOCK_BIN_DIR}/launchctl"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_95_configure-passwordless-ssh.sh"
  "${REAL_CHEZMOI_BIN}" execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN passwordless SSH disabled EXPECT setup exits without side effects" {
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Skipping passwordless SSH setup"* ]]
  [[ ! -e "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf" ]]
}

@test "GIVEN authorized_keys missing EXPECT password auth hardening is not applied" {
  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"authorized_keys"* ]]
  [[ ! -e "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf" ]]
}

@test "GIVEN authorized_keys present EXPECT hardened SSH config is written" {
  printf '%s\n' 'ssh-ed25519 AAAATEST derick@example' > "${CHEZMOI_SSH_AUTHORIZED_KEYS}"

  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^PubkeyAuthentication yes$' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 0 ]]
  run grep -q '^PasswordAuthentication no$' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 0 ]]
  run grep -q '^KbdInteractiveAuthentication no$' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 0 ]]
  run grep -q '^PermitRootLogin no$' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 0 ]]
  run grep -q '^AllowUsers ' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 0 ]]
  run grep -q '^LoginGraceTime 20$' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 0 ]]
  run grep -q '^AllowAgentForwarding no$' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN authorized_keys present EXPECT missing host keys are generated" {
  printf '%s\n' 'ssh-ed25519 AAAATEST derick@example' > "${CHEZMOI_SSH_AUTHORIZED_KEYS}"

  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^ssh-keygen -A$' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN host key exists EXPECT host key generation is skipped" {
  printf '%s\n' 'ssh-ed25519 AAAATEST derick@example' > "${CHEZMOI_SSH_AUTHORIZED_KEYS}"
  printf '%s\n' 'existing-host-key' > "${MOCK_ETC}/ssh_host_ed25519_key"

  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  script_output="${output}"
  run grep -q '^ssh-keygen -A$' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 1 ]]
  [[ "${script_output}" == *"SSH host keys already exist"* ]]
}

@test "GIVEN systemsetup requires Full Disk Access EXPECT instructions before SSH config changes" {
  printf '%s\n' 'ssh-ed25519 AAAATEST derick@example' > "${CHEZMOI_SSH_AUTHORIZED_KEYS}"

  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true MOCK_SYSTEMSETUP_FULL_DISK_ACCESS_FAILURE=true bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"needs Full Disk Access"* ]]
  [[ "${output}" == *"Quit and reopen"* || "${output}" == *"quit and reopen"* ]]
  [[ ! -e "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf" ]]
}

@test "GIVEN hardened SSH config EXPECT TCP forwarding remains unchanged" {
  printf '%s\n' 'ssh-ed25519 AAAATEST derick@example' > "${CHEZMOI_SSH_AUTHORIZED_KEYS}"

  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  run grep -q '^AllowTcpForwarding ' "${MOCK_ETC}/sshd_config.d/99-chezmoi-passwordless.conf"
  [[ "${status}" -eq 1 ]]
}

@test "GIVEN setup is rerun EXPECT sshd include is not duplicated" {
  printf '%s\n' 'ssh-ed25519 AAAATEST derick@example' > "${CHEZMOI_SSH_AUTHORIZED_KEYS}"

  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true MOCK_REMOTE_LOGIN_STATUS=On bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]
  run env CHEZMOI_ENABLE_PASSWORDLESS_SSH=true MOCK_REMOTE_LOGIN_STATUS=On bash "${RENDERED_SCRIPT}"
  [[ "${status}" -eq 0 ]]

  include_count="$(grep -c '^Include .*/sshd_config.d/\*.conf$' "${MOCK_ETC}/sshd_config")"
  [[ "${include_count}" -eq 1 ]]
  [[ "${output}" == *"Passwordless SSH setup already configured."* ]]
}
