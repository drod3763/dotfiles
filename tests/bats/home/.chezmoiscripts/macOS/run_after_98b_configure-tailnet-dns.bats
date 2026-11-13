#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../../helpers/chezmoi"

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_98b_configure-tailnet-dns.sh.tmpl"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
MOCK_AS_ROOT=1 exec "$@"
EOF

  cat > "${MOCK_BIN_DIR}/tailscale" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  status) printf '%s\n' "${MOCK_TS_STATUS:-}" ;;
  debug) printf '%s\n' "${MOCK_TS_PREFS:-}" ;;
  set)
    if [[ -n "${MOCK_TS_SET_NEEDS_ROOT:-}" && -z "${MOCK_AS_ROOT:-}" ]]; then
      exit 1
    fi
    printf 'tailscale %s\n' "$*" >> "${MOCK_CALLS_FILE:?}"
    ;;
esac
EOF

  chmod +x "${MOCK_BIN_DIR}"/*

  export MOCK_CALLS_FILE="${TEST_TMPDIR}/calls.log"
  touch "${MOCK_CALLS_FILE}"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export CHEZMOI_TAILSCALE_BIN="${MOCK_BIN_DIR}/tailscale"
  export CHEZMOI_RESOLVER_DIR="${TEST_TMPDIR}/resolver"
  export MOCK_TS_STATUS='{"BackendState":"Running","MagicDNSSuffix":"tail1234.ts.net"}'
  export MOCK_TS_PREFS='{"CorpDNS":true}'

  MARKER="# managed by chezmoi: tailnet-dns"
  RESOLVER_FILE="${CHEZMOI_RESOLVER_DIR}/tail1234.ts.net"

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

write_managed_resolver() {
  mkdir -p "${CHEZMOI_RESOLVER_DIR}"
  printf '%s\nnameserver 100.100.100.100\n' "${MARKER}" > "${CHEZMOI_RESOLVER_DIR}/$1"
}

@test "GIVEN work machine with Tailscale DNS on EXPECT DNS takeover disabled and suffix resolver written" {
  run bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  run grep -qx 'tailscale set --accept-dns=false' "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
  run cat "${RESOLVER_FILE}"
  [[ "${output}" == "$(printf '%s\nnameserver 100.100.100.100' "${MARKER}")" ]]
}

@test "GIVEN Tailscale DNS already off and resolver current EXPECT no changes" {
  write_managed_resolver "tail1234.ts.net"

  run env MOCK_TS_PREFS='{"CorpDNS":false}' bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
}

@test "GIVEN tailscale set needs root EXPECT retried with sudo" {
  run env MOCK_TS_SET_NEEDS_ROOT=1 bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  run grep -qx "sudo ${CHEZMOI_TAILSCALE_BIN} set --accept-dns=false" "${MOCK_CALLS_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN managed resolver for an old suffix EXPECT it is removed and unmanaged files kept" {
  write_managed_resolver "old.ts.net"
  printf 'nameserver 10.0.0.1\n' > "${CHEZMOI_RESOLVER_DIR}/corp.example"

  run bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -e "${CHEZMOI_RESOLVER_DIR}/old.ts.net" ]]
  [[ -f "${CHEZMOI_RESOLVER_DIR}/corp.example" ]]
  [[ -f "${RESOLVER_FILE}" ]]
}

@test "GIVEN Tailscale not running EXPECT no changes" {
  run env MOCK_TS_STATUS='{"BackendState":"Stopped","MagicDNSSuffix":"tail1234.ts.net"}' bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
  [[ ! -e "${RESOLVER_FILE}" ]]
}

@test "GIVEN Tailscale status unreadable EXPECT no changes" {
  run env MOCK_TS_STATUS='not json' bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
}

@test "GIVEN tailscale missing EXPECT no changes" {
  run env CHEZMOI_TAILSCALE_BIN="${TEST_TMPDIR}/missing" bash "${TEST_TMPDIR}/work.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
  [[ ! -e "${RESOLVER_FILE}" ]]
}

@test "GIVEN personal machine with managed resolver EXPECT resolver removed and Tailscale DNS untouched" {
  write_managed_resolver "tail1234.ts.net"

  run bash "${TEST_TMPDIR}/personal.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -e "${RESOLVER_FILE}" ]]
  run grep -q 'tailscale set' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}

@test "GIVEN personal machine without managed resolver EXPECT no changes" {
  run bash "${TEST_TMPDIR}/personal.sh"

  [[ "${status}" -eq 0 ]]
  [[ ! -s "${MOCK_CALLS_FILE}" ]]
}
