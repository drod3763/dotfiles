#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_once_before_91_unload-herdr-server.sh.tmpl"
  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  export MOCK_CALLS_FILE="${TEST_TMPDIR}/calls"
  touch "${MOCK_CALLS_FILE}"

  cat >"${MOCK_BIN_DIR}/launchctl" <<'EOF'
#!/bin/bash
printf 'launchctl %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
if [[ "$1" == "print" ]]; then
  [[ "${MOCK_AGENT_LOADED:?}" == "1" ]] && exit 0
  exit 113
fi
exit 0
EOF
  chmod +x "${MOCK_BIN_DIR}/launchctl"
  export CHEZMOI_LAUNCHCTL_BIN="${MOCK_BIN_DIR}/launchctl"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_before_91_unload-herdr-server.sh"
  chezmoi execute-template <"${TEMPLATE_PATH}" >"${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN herdr-server agent loaded EXPECT script boots it out" {
  export MOCK_AGENT_LOADED="1"
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"unloaded local.herdr-server"* ]]
  run grep -qx "launchctl bootout gui/$(id -u)/local.herdr-server" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN herdr-server agent not loaded EXPECT script is a silent no-op" {
  export MOCK_AGENT_LOADED="0"
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
  run grep -q '^launchctl bootout' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}
