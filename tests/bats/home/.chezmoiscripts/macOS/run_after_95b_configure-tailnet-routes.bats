#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../../helpers/chezmoi"

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_onchange_after_95b_configure-tailnet-routes.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
exec "$@"
EOF

  cat > "${MOCK_BIN_DIR}/launchctl" <<'EOF'
#!/usr/bin/env bash
printf 'launchctl %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
EOF

  cat > "${MOCK_BIN_DIR}/tailscale" <<'EOF'
#!/usr/bin/env bash
[[ -n "${MOCK_TS_IP:-}" ]] && printf '%s\n' "${MOCK_TS_IP}"
EOF

  cat > "${MOCK_BIN_DIR}/ifconfig" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
utun123: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280
	inet 100.64.0.0 --> 100.64.0.0 netmask 0xffffffff
utun7: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280
	inet 100.107.196.46 --> 100.107.196.46 netmask 0xffffffff
OUT
EOF

  cat > "${MOCK_BIN_DIR}/route" <<'EOF'
#!/usr/bin/env bash
printf 'route %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
if [[ "$2" == "get" ]]; then
  printf '   route to: %s\n  interface: %s\n' "$3" "${MOCK_ROUTE_IF:-utun123}"
fi
EOF

  chmod +x "${MOCK_BIN_DIR}"/*

  export MOCK_CALLS_FILE="${TEST_TMPDIR}/calls.log"
  touch "${MOCK_CALLS_FILE}"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export CHEZMOI_TAILNET_ROUTES_HELPER="${TEST_TMPDIR}/libexec/tailnet-routes"
  export CHEZMOI_TAILNET_ROUTES_PLIST="${TEST_TMPDIR}/local.tailnet-routes.plist"
  export CHEZMOI_LAUNCHCTL_BIN="${MOCK_BIN_DIR}/launchctl"
  export TAILNET_ROUTES_TAILSCALE_BIN="${MOCK_BIN_DIR}/tailscale"
  export TAILNET_ROUTES_ROUTE_BIN="${MOCK_BIN_DIR}/route"
  export TAILNET_ROUTES_IFCONFIG_BIN="${MOCK_BIN_DIR}/ifconfig"

  render "work" '{"personal": false, "tailnetRoutes": {"work": [{"ip": "100.90.57.6"}]}}'
  render "personal" '{"personal": true}'
}

render() {
  printf '%s\n' "$2" > "${TEST_TMPDIR}/$1.json"
  chezmoi_execute_template --override-data-file "${TEST_TMPDIR}/$1.json" \
    < "${TEMPLATE_PATH}" > "${TEST_TMPDIR}/$1.sh"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN work machine EXPECT helper and daemon are installed and loaded" {
  run bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  [[ -x "${CHEZMOI_TAILNET_ROUTES_HELPER}" ]]
  run grep -qF '"100.90.57.6"' "${CHEZMOI_TAILNET_ROUTES_HELPER}"
  [[ "${status}" -eq 0 ]]
  run plutil -lint "${CHEZMOI_TAILNET_ROUTES_PLIST}"
  [[ "${status}" -eq 0 ]]
  run grep -qF "<string>${CHEZMOI_TAILNET_ROUTES_HELPER}</string>" "${CHEZMOI_TAILNET_ROUTES_PLIST}"
  [[ "${status}" -eq 0 ]]
  run grep -qx "launchctl bootstrap system ${CHEZMOI_TAILNET_ROUTES_PLIST}" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN peer routed via another tunnel EXPECT helper routes it via the Tailscale interface" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun123 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]]
  run grep -qx 'route -n add -host 100.90.57.6 -interface utun7' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN peer already routed via Tailscale EXPECT helper changes nothing" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun7 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]]
  run grep -qE 'route -n (add|delete)' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN Tailscale down EXPECT helper exits without touching routes" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP= bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
}

@test "GIVEN Tailscale IP on no interface EXPECT helper exits without touching routes" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.1.2.3 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
}

@test "GIVEN personal machine with daemon installed EXPECT daemon is removed" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run bash "${TEST_TMPDIR}/personal.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -e "${CHEZMOI_TAILNET_ROUTES_HELPER}" ]]
  [[ ! -e "${CHEZMOI_TAILNET_ROUTES_PLIST}" ]]
  run grep -qx 'launchctl bootout system/local.tailnet-routes' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN personal machine without daemon EXPECT no changes" {
  run bash "${TEST_TMPDIR}/personal.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
}
