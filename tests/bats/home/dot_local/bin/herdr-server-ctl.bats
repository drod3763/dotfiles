#!/usr/bin/env bats

# Exercises the decision table of herdr-server-ctl with the process probes mocked out:
# pgrep (server pid), python3 (responsible pid), ps (responsible path), launchctl (agent)
# and herdr itself. A `kickstart` drops a marker that flips the pgrep mock to the "after"
# state, which is how the wait loops terminate.

setup() {
  bats_require_minimum_version 1.5.0

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CTL="${REPO_ROOT}/home/dot_local/bin/executable_herdr-server-ctl"
  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  export MOCK_CALLS_FILE="${TEST_TMPDIR}/calls"
  export MOCK_KICK_MARKER="${TEST_TMPDIR}/kicked"
  export MOCK_SERVER_PID="4242"
  export MOCK_SERVER_PID_AFTER_KICK="5150"
  export MOCK_RESPONSIBLE_PID="777"
  export MOCK_RESPONSIBLE_PATH="/Applications/Herdr Server.app/Contents/MacOS/herdr-server-launcher"
  export MOCK_SERVER_STALE="false"
  export MOCK_AGENT_LOADED="1"

  # Server presence: MOCK_SERVER_PID until a kickstart happened, then
  # MOCK_SERVER_PID_AFTER_KICK (empty values mean "no server").
  cat >"${MOCK_BIN_DIR}/pgrep" <<'EOF'
#!/bin/bash
if [[ -f "${MOCK_KICK_MARKER:?}" ]]; then
  pid="${MOCK_SERVER_PID_AFTER_KICK:-}"
elif [[ -f "${MOCK_STOP_MARKER:?}" ]]; then
  pid=""
else
  pid="${MOCK_SERVER_PID:-}"
fi
[[ -n "${pid}" ]] || exit 1
printf '%s\n' "${pid}"
EOF

  cat >"${MOCK_BIN_DIR}/python3" <<'EOF'
#!/bin/bash
printf '%s\n' "${MOCK_RESPONSIBLE_PID:?}"
EOF

  cat >"${MOCK_BIN_DIR}/ps" <<'EOF'
#!/bin/bash
printf '%s\n' "${MOCK_RESPONSIBLE_PATH:?}"
EOF

  cat >"${MOCK_BIN_DIR}/launchctl" <<'EOF'
#!/bin/bash
printf 'launchctl %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
case "$1" in
  print) [[ "${MOCK_AGENT_LOADED:?}" == "1" ]] ;;
  kickstart) touch "${MOCK_KICK_MARKER:?}" ;;
esac
EOF

  cat >"${MOCK_BIN_DIR}/herdr" <<'EOF'
#!/bin/bash
printf 'herdr %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
if [[ "$1" == "status" ]]; then
  printf '{"update":{"server_binary_stale":%s}}\n' "${MOCK_SERVER_STALE:?}"
elif [[ "$*" == "server stop" ]]; then
  # The launcher is standing by; after the stop nothing listens until it is kicked.
  touch "${MOCK_STOP_MARKER:?}"
fi
EOF

  cat >"${MOCK_BIN_DIR}/pkill" <<'EOF'
#!/bin/bash
printf 'pkill %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
EOF

  cat >"${MOCK_BIN_DIR}/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF

  chmod +x "${MOCK_BIN_DIR}"/*
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_STOP_MARKER="${TEST_TMPDIR}/stopped"
  export HERDR_CTL_HERDR_BIN="${MOCK_BIN_DIR}/herdr"
  export HERDR_CTL_LAUNCHCTL_BIN="${MOCK_BIN_DIR}/launchctl"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN no server EXPECT status exits 2" {
  export MOCK_SERVER_PID=""

  run bash "${CTL}" status

  [[ "${status}" -eq 2 ]]
  [[ "${output}" == *"not running"* ]]
}

@test "GIVEN server attributed to the bundle EXPECT status exits 0" {
  run bash "${CTL}" status

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"pid=4242 responsible=777 (/Applications/Herdr Server.app/Contents/MacOS/herdr-server-launcher) ok"* ]]
}

@test "GIVEN server attributed to tailscaled EXPECT status exits 1" {
  export MOCK_RESPONSIBLE_PATH="/opt/homebrew/opt/tailscale/bin/tailscaled"

  run bash "${CTL}" status

  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"NOT attributed to an app"* ]]
}

@test "GIVEN server running EXPECT start does not touch the agent" {
  run bash "${CTL}" start

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"already running"* ]]
  [[ ! -f "${MOCK_KICK_MARKER}" ]]
}

@test "GIVEN no server EXPECT start kickstarts the agent" {
  export MOCK_SERVER_PID=""

  run bash "${CTL}" start

  [[ "${status}" -eq 0 ]]
  run grep -qx "launchctl kickstart -k gui/$(id -u)/local.herdr-server" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN agent not loaded EXPECT start refuses with a chezmoi hint" {
  export MOCK_SERVER_PID=""
  export MOCK_AGENT_LOADED="0"

  run bash "${CTL}" start

  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"not loaded"* ]]
  [[ ! -f "${MOCK_KICK_MARKER}" ]]
}

@test "GIVEN tainted server EXPECT fix -y stops it and kickstarts the agent" {
  export MOCK_RESPONSIBLE_PATH="/opt/homebrew/opt/tailscale/bin/tailscaled"

  run bash "${CTL}" fix -y

  [[ "${status}" -eq 0 ]]
  run grep -nE "^(pkill|herdr server stop|launchctl kickstart)" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  # Bridges first (their clients would otherwise respawn a tainted server), then stop, then kick.
  [[ "${lines[0]}" == *"pkill -f ^[^ ]*/herdr remote-client-bridge" ]]
  [[ "${lines[1]}" == *"herdr server stop" ]]
  [[ "${lines[2]}" == *"launchctl kickstart -k gui/$(id -u)/local.herdr-server" ]]
}

@test "GIVEN tainted server and declined prompt EXPECT fix aborts" {
  export MOCK_RESPONSIBLE_PATH="/opt/homebrew/opt/tailscale/bin/tailscaled"

  run bash "${CTL}" fix <<<"n"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"aborted"* ]]
  run grep -q "server stop" "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN healthy stale server EXPECT fix hands off without stopping" {
  export MOCK_SERVER_STALE="true"

  run bash "${CTL}" fix -y

  [[ "${status}" -eq 0 ]]
  run grep -qx "herdr server live-handoff" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run grep -q "server stop\|kickstart" "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN healthy fresh server EXPECT fix is a no-op" {
  run bash "${CTL}" fix -y

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"nothing to do"* ]]
  run grep -q "live-handoff\|server stop\|kickstart" "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}
