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
case "$1" in
  ip) [[ -n "${MOCK_TS_IP:-}" ]] && printf '%s\n' "${MOCK_TS_IP}" ;;
  status) printf '%s\n' "${MOCK_TS_STATUS:-}" ;;
esac
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
  export TAILNET_ROUTES_JQ_BIN="$(command -v jq)"
  export TAILNET_ROUTES_STATE_FILE="${TEST_TMPDIR}/routed-peers"
  export MOCK_TS_STATUS='{"Peer":{"a":{"TailscaleIPs":["100.90.57.6","fd7a:115c:a1e0::1"]},"b":{"TailscaleIPs":["100.100.147.58","fd7a:115c:a1e0::2"]}}}'

  render "work" '{"personal": false}'
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

  [[ "${status}" -eq 0 ]] || false
  [[ -x "${CHEZMOI_TAILNET_ROUTES_HELPER}" ]] || false
  run plutil -lint "${CHEZMOI_TAILNET_ROUTES_PLIST}"
  [[ "${status}" -eq 0 ]] || false
  run grep -qF "<string>${CHEZMOI_TAILNET_ROUTES_HELPER}</string>" "${CHEZMOI_TAILNET_ROUTES_PLIST}"
  [[ "${status}" -eq 0 ]] || false
  run grep -qx "launchctl bootstrap system ${CHEZMOI_TAILNET_ROUTES_PLIST}" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]] || false
}

@test "GIVEN peers routed via another tunnel EXPECT helper routes every peer IPv4 via the Tailscale interface" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun123 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  run grep -qx 'route -n add -host 100.90.57.6 -interface utun7' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]] || false
  run grep -qx 'route -n add -host 100.100.147.58 -interface utun7' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]] || false
  run grep -qF 'fd7a:' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]] || false
}

@test "GIVEN tailnet with no peers EXPECT helper changes nothing" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_TS_STATUS='{"Peer":null}' bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  [[ ! -s "${MOCK_CALLS_FILE}" ]] || false
}

@test "GIVEN unreadable Tailscale status EXPECT helper exits cleanly without touching routes" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_TS_STATUS='not json' bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  [[ ! -s "${MOCK_CALLS_FILE}" ]] || false
}

@test "GIVEN peer already routed via Tailscale EXPECT helper changes nothing" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun7 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  run grep -qE 'route -n (add|delete)' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]] || false
}

@test "GIVEN Tailscale down EXPECT helper exits without touching routes" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP= bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  [[ ! -s "${MOCK_CALLS_FILE}" ]] || false
}

@test "GIVEN Tailscale IP on no interface EXPECT helper exits without touching routes" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.1.2.3 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  [[ ! -s "${MOCK_CALLS_FILE}" ]] || false
}

@test "GIVEN personal machine with daemon installed EXPECT daemon is removed" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run bash "${TEST_TMPDIR}/personal.sh"

  [[ "${status}" -eq 0 ]] || false
  [[ ! -e "${CHEZMOI_TAILNET_ROUTES_HELPER}" ]] || false
  [[ ! -e "${CHEZMOI_TAILNET_ROUTES_PLIST}" ]] || false
  run grep -qx 'launchctl bootout system/local.tailnet-routes' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]] || false
}

@test "GIVEN personal machine without daemon EXPECT no changes" {
  run bash "${TEST_TMPDIR}/personal.sh"

  [[ "${status}" -eq 0 ]] || false
  [[ ! -s "${MOCK_CALLS_FILE}" ]] || false
}

@test "GIVEN a routed peer leaves the tailnet EXPECT its host route is removed" {
  bash "${TEST_TMPDIR}/work.sh"
  MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun123 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun7 \
    MOCK_TS_STATUS='{"Peer":{"a":{"TailscaleIPs":["100.90.57.6"]}}}' bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  run grep -qx 'route -n delete -host 100.100.147.58' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]] || false
  run grep -qx 'route -n delete -host 100.90.57.6' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]] || false
}

@test "GIVEN unreadable Tailscale status after routing peers EXPECT routes are kept" {
  bash "${TEST_TMPDIR}/work.sh"
  MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun123 bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 MOCK_ROUTE_IF=utun7 MOCK_TS_STATUS='not json' bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -eq 0 ]] || false
  run grep -q 'route -n delete' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]] || false
}

@test "GIVEN jq missing EXPECT helper fails loudly without touching routes" {
  bash "${TEST_TMPDIR}/work.sh"
  : > "${MOCK_CALLS_FILE}"

  run env MOCK_TS_IP=100.107.196.46 TAILNET_ROUTES_JQ_BIN="${TEST_TMPDIR}/missing-jq" bash "${CHEZMOI_TAILNET_ROUTES_HELPER}"

  [[ "${status}" -ne 0 ]] || false
  [[ "${output}" == *"jq"* ]] || false
  [[ ! -s "${MOCK_CALLS_FILE}" ]] || false
}
