#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_onchange_after_98b_configure-herdr-service.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"
  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  TEST_HOME="${TEST_TMPDIR}/home"
  TEST_APP="${TEST_TMPDIR}/Herdr Server.app"
  mkdir -p "${MOCK_BIN_DIR}" "${TEST_HOME}/Library/LaunchAgents" "${TEST_HOME}/.local/bin" "${TEST_APP}/Contents/MacOS"
  touch "${TEST_APP}/Contents/MacOS/herdr-server-launcher"
  chmod +x "${TEST_APP}/Contents/MacOS/herdr-server-launcher"

  export MOCK_CALLS_FILE="${TEST_TMPDIR}/calls"
  export MOCK_CTL_STATUS_EXIT="0"
  export MOCK_SERVER_STALE="false"

  # herdr must be on PATH at render time for the template's lookPath guard.
  cat >"${MOCK_BIN_DIR}/herdr" <<'EOF'
#!/bin/bash
printf 'herdr %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
if [[ "$1" == "status" ]]; then
  printf '{"update":{"server_binary_stale":%s}}\n' "${MOCK_SERVER_STALE:?}"
fi
EOF

  cat >"${MOCK_BIN_DIR}/brew" <<'EOF'
#!/bin/bash
printf 'brew %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
EOF

  cat >"${MOCK_BIN_DIR}/launchctl" <<'EOF'
#!/bin/bash
printf 'launchctl %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
# `print` reports the agent as loaded until a bootout has been recorded, after which the
# script's wait loop must see it fail. MOCK_AGENT_LOADED=0 means "never loaded".
if [[ "$1" == "print" ]]; then
  [[ "${MOCK_AGENT_LOADED:-1}" == "1" && ! -f "${MOCK_BOOTOUT_MARKER:?}" ]] && exit 0
  exit 113
fi
[[ "$1" == "bootout" ]] && touch "${MOCK_BOOTOUT_MARKER:?}"
exit 0
EOF

  cat >"${TEST_HOME}/.local/bin/herdr-server-ctl" <<'EOF'
#!/bin/bash
printf 'ctl %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
if [[ "$1" == "status" ]]; then
  exit "${MOCK_CTL_STATUS_EXIT:?}"
fi
EOF

  chmod +x "${MOCK_BIN_DIR}"/* "${TEST_HOME}/.local/bin/herdr-server-ctl"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export CHEZMOI_LAUNCHCTL_BIN="${MOCK_BIN_DIR}/launchctl"
  export MOCK_BOOTOUT_MARKER="${TEST_TMPDIR}/booted-out"
  export MOCK_AGENT_LOADED="0"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_98b_configure-herdr-service.sh"
  "${REAL_CHEZMOI_BIN}" execute-template <"${TEMPLATE_PATH}" >"${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"

  touch "${TEST_HOME}/Library/LaunchAgents/local.herdr-server.plist"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

run_rendered_script() {
  run env HOME="${TEST_HOME}" PATH="${PATH}" HERDR_SERVER_APP="${TEST_APP}" bash "${RENDERED_SCRIPT}"
}

@test "GIVEN brew herdr launch agent EXPECT script stops the brew service" {
  touch "${TEST_HOME}/Library/LaunchAgents/sh.brew.herdr.plist"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -qx 'brew services stop herdr' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN no brew herdr launch agent EXPECT script leaves brew alone" {
  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -q '^brew ' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN managed plist EXPECT script reloads the agent into the gui domain" {
  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -qx "launchctl bootout gui/$(id -u)/local.herdr-server" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -qx "launchctl bootstrap gui/$(id -u) ${TEST_HOME}/Library/LaunchAgents/local.herdr-server.plist" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN Herdr Server.app missing EXPECT script skips the agent and says so" {
  rm -rf "${TEST_APP}"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"install drod3763/tap/herdr-server"* ]]
  run grep -q '^launchctl' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN agent loaded with the current plist EXPECT script leaves it alone" {
  export MOCK_AGENT_LOADED="1"
  mkdir -p "${TEST_HOME}/.cache/herdr-server-ctl"
  shasum -a 256 "${TEST_HOME}/Library/LaunchAgents/local.herdr-server.plist" | cut -d' ' -f1 \
    >"${TEST_HOME}/.cache/herdr-server-ctl/local.herdr-server.plist.sha256"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"already loaded"* ]]
  run grep -q 'bootout\|bootstrap' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN agent loaded with a changed plist EXPECT script reloads it and records the stamp" {
  export MOCK_AGENT_LOADED="1"
  printf 'old\n' >"${TEST_HOME}/Library/LaunchAgents/local.herdr-server.plist"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -qx "launchctl bootstrap gui/$(id -u) ${TEST_HOME}/Library/LaunchAgents/local.herdr-server.plist" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  [[ "$(cat "${TEST_HOME}/.cache/herdr-server-ctl/local.herdr-server.plist.sha256")" == "$(shasum -a 256 "${TEST_HOME}/Library/LaunchAgents/local.herdr-server.plist" | cut -d' ' -f1)" ]]
}

@test "GIVEN healthy stale server EXPECT script hands off via ctl fix" {
  export MOCK_SERVER_STALE="true"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -qx 'ctl fix -y' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN healthy fresh server EXPECT script does not touch the server" {
  run_rendered_script

  [[ "${status}" -eq 0 ]]
  run grep -q '^ctl fix' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN tainted server EXPECT script only reports it" {
  export MOCK_CTL_STATUS_EXIT="1"

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"run 'herdr-fix'"* ]]
  [[ "${output}" == *"Herdr Server.app"* ]]
  run grep -q '^ctl fix' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}
