#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../../helpers/chezmoi"

setup() {
  command -v jq >/dev/null 2>&1 || skip "jq is required"

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_98d_configure-moshi-hook.sh.tmpl"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  # Status comes from MOCK_MOSHI_STATUS_FILE; a successful `host setup` swaps in
  # MOCK_MOSHI_STATUS_AFTER_SETUP_FILE so the post-pairing re-read can be asserted.
  cat > "${MOCK_BIN_DIR}/moshi-hook" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MOCK_MOSHI_CALLS_FILE:?}"
case "$1" in
  status)
    [[ -z "${MOCK_MOSHI_STATUS_FAILS:-}" ]] || exit 1
    cat "${MOCK_MOSHI_STATUS_FILE:?}"
    ;;
  install) [[ -z "${MOCK_MOSHI_INSTALL_FAILS:-}" ]] ;;
  host)
    [[ -z "${MOCK_MOSHI_SETUP_FAILS:-}" ]] || exit 1
    if [[ -n "${MOCK_MOSHI_STATUS_AFTER_SETUP_FILE:-}" ]]; then
      cp "${MOCK_MOSHI_STATUS_AFTER_SETUP_FILE}" "${MOCK_MOSHI_STATUS_FILE}"
    fi
    ;;
  e2ee) [[ -z "${MOCK_MOSHI_E2EE_FAILS:-}" ]] ;;
esac
EOF

  cat > "${MOCK_BIN_DIR}/tailscale" <<'EOF'
#!/usr/bin/env bash
[[ -z "${MOCK_TAILSCALE_DOWN:-}" ]] || exit 1
case "$1" in
  status) printf '{"BackendState":"%s","Self":{"DNSName":"mac.tailnet.ts.net."}}\n' "${MOCK_TAILSCALE_BACKEND:-Running}" ;;
  debug) printf '{"RunSSH": %s}\n' "${MOCK_TAILSCALE_RUN_SSH:-true}" ;;
esac
EOF

  chmod +x "${MOCK_BIN_DIR}"/*

  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_MOSHI_CALLS_FILE="${TEST_TMPDIR}/moshi.calls"
  export MOCK_MOSHI_STATUS_FILE="${TEST_TMPDIR}/status.json"
  export MOSHI_PAIR_PROMPT_TIMEOUT=1
  touch "${MOCK_MOSHI_CALLS_FILE}"

  # Default fixture: fully converged host.
  write_status "${MOCK_MOSHI_STATUS_FILE}" true current on

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_98d_configure-moshi-hook.sh"
  chezmoi_execute_template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"

  # Same script with the TTY guard forced on, for the interactive pairing paths.
  INTERACTIVE_SCRIPT="${TEST_TMPDIR}/interactive.sh"
  sed 's/\[\[ -t 0 \]\]/true/' "${RENDERED_SCRIPT}" > "${INTERACTIVE_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# write_status <file> <paired> <claude hook status> <e2ee policy>
write_status() {
  cat > "$1" <<EOF
{"paired":$2,"e2ee":{"policy":"$4"},"hooks":[
  {"target":"claude","status":"$3"},
  {"target":"codex","status":"current"},
  {"target":"gemini","status":"not_found"}
]}
EOF
}

moshi_called() {
  grep -qx -- "$1" "${MOCK_MOSHI_CALLS_FILE}"
}

moshi_called_like() {
  grep -q -- "$1" "${MOCK_MOSHI_CALLS_FILE}"
}

run_rendered_script() {
  run env PATH="${PATH}" "$@" bash "${RENDERED_SCRIPT}" </dev/null
}

run_interactive() {
  local answer="$1"
  shift
  run env PATH="${PATH}" "$@" bash -c 'printf "%s" "$1" | bash "$2"' _ "${answer}" "${INTERACTIVE_SCRIPT}"
}

@test "GIVEN converged host EXPECT only a status read" {
  run_rendered_script

  [[ "${status}" -eq 0 ]]
  [[ "$(cat "${MOCK_MOSHI_CALLS_FILE}")" == "status --json" ]]
}

@test "GIVEN claude hooks not current EXPECT install only stale targets" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true missing on

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  moshi_called "install --target claude"
}

@test "GIVEN hook install fails EXPECT warning without failing apply" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true missing on

  run_rendered_script MOCK_MOSHI_INSTALL_FAILS=1

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Failed to install moshi-hook hooks"* ]]
}

@test "GIVEN status unavailable EXPECT skip without failing apply" {
  run_rendered_script MOCK_MOSHI_STATUS_FAILS=1

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"skipping Moshi setup"* ]]
  ! moshi_called_like "install"
}

@test "GIVEN unpaired and non-interactive EXPECT pair hint and no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"not paired"* ]]
  [[ "${output}" == *"moshi-hook host setup --host mac.tailnet.ts.net --force"* ]]
  ! moshi_called_like "^host"
  ! moshi_called_like "^e2ee"
}

@test "GIVEN unpaired interactive and prompt times out EXPECT no setup and pair hint" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  # A pipe whose writer stays silent past the 1s timeout makes `read -t` time out.
  run env PATH="${PATH}" bash -c '/bin/sleep 2 | bash "$1"' _ "${INTERACTIVE_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Pair now? [y/N]"* ]]
  [[ "${output}" == *"To pair it, run"* ]]
  ! moshi_called_like "^host"
}

@test "GIVEN unpaired interactive and answer no EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "n"

  [[ "${status}" -eq 0 ]]
  ! moshi_called_like "^host"
  [[ "${output}" == *"To pair it, run"* ]]
}

@test "GIVEN unpaired interactive and answer yes EXPECT setup then e2ee enable" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off

  run_interactive "y" MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json"

  [[ "${status}" -eq 0 ]]
  moshi_called "host setup --host mac.tailnet.ts.net --force"
  moshi_called "e2ee enable"
  [[ "${output}" != *"To pair it, run"* ]]
}

@test "GIVEN Tailscale SSH off EXPECT setup without force" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_TAILSCALE_RUN_SSH=false

  [[ "${status}" -eq 0 ]]
  moshi_called "host setup --host mac.tailnet.ts.net"
}

@test "GIVEN Tailscale SSH on but backend stopped EXPECT setup without host or force" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_TAILSCALE_BACKEND=Stopped

  [[ "${status}" -eq 0 ]]
  moshi_called "host setup"
}

@test "GIVEN tailscale unavailable EXPECT plain host setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_TAILSCALE_DOWN=1

  [[ "${status}" -eq 0 ]]
  moshi_called "host setup"
}

@test "GIVEN setup fails EXPECT warning, pair hint, and no e2ee" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_MOSHI_SETUP_FAILS=1

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"pairing did not complete"* ]]
  [[ "${output}" == *"To pair it, run"* ]]
  ! moshi_called_like "^e2ee"
}

@test "GIVEN paired with e2ee off EXPECT e2ee enable" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true current off

  run_rendered_script

  [[ "${status}" -eq 0 ]]
  moshi_called "e2ee enable"
}

@test "GIVEN e2ee enable fails EXPECT warning without failing apply" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true current off

  run_rendered_script MOCK_MOSHI_E2EE_FAILS=1

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Failed to enable moshi-hook E2EE"* ]]
}
