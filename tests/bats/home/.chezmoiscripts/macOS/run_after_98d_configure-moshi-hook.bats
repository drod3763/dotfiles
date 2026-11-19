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
    [[ ! -e "${MOCK_MOSHI_STATUS_FAILS_MARKER:-/nonexistent}" ]] || exit 1
    cat "${MOCK_MOSHI_STATUS_FILE:?}"
    ;;
  install) [[ -z "${MOCK_MOSHI_INSTALL_FAILS:-}" ]] ;;
  host)
    if [[ -n "${MOCK_MOSHI_STATUS_AFTER_SETUP_FILE:-}" ]]; then
      cp "${MOCK_MOSHI_STATUS_AFTER_SETUP_FILE}" "${MOCK_MOSHI_STATUS_FILE}"
    fi
    if [[ -n "${MOCK_MOSHI_STATUS_FAILS_MARKER:-}" ]]; then
      touch "${MOCK_MOSHI_STATUS_FAILS_MARKER}"
    fi
    [[ -z "${MOCK_MOSHI_SETUP_FAILS:-}" ]]
    ;;
  e2ee) [[ -z "${MOCK_MOSHI_E2EE_FAILS:-}" ]] ;;
esac
EOF

  cat > "${MOCK_BIN_DIR}/tailscale" <<'EOF'
#!/usr/bin/env bash
[[ -z "${MOCK_TAILSCALE_DOWN:-}" ]] || exit 1
backend="${MOCK_TAILSCALE_BACKEND:-Running}"
# Once MOCK_TAILSCALE_STOPPED_MARKER exists, Tailscale reports Stopped.
if [[ -n "${MOCK_TAILSCALE_STOPPED_MARKER:-}" ]] && [[ -e "${MOCK_TAILSCALE_STOPPED_MARKER}" ]]; then
  backend=Stopped
fi
case "$1" in
  status) printf '{"BackendState":"%s","Self":{"DNSName":"mac.tailnet.ts.net."}}\n' "${backend}" ;;
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

# Submits the answer with a newline, as pressing Enter would.
run_interactive() {
  local answer="$1"
  shift
  run env PATH="${PATH}" "$@" bash -c 'printf "%s\n" "$1" | bash "$2"' _ "${answer}" "${INTERACTIVE_SCRIPT}"
}

@test "GIVEN converged host EXPECT only a status read" {
  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  [[ "$(cat "${MOCK_MOSHI_CALLS_FILE}")" == "status --json" ]] || false
}

@test "GIVEN claude hooks not current EXPECT install only stale targets" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true missing on

  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  moshi_called "install --target claude"
}

@test "GIVEN hook install fails EXPECT warning without failing apply" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true missing on

  run_rendered_script MOCK_MOSHI_INSTALL_FAILS=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Failed to install moshi-hook hooks"* ]] || false
}

@test "GIVEN status unavailable EXPECT skip without failing apply" {
  run_rendered_script MOCK_MOSHI_STATUS_FAILS=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"skipping Moshi setup"* ]] || false
  ! moshi_called_like "install" || false
}

@test "GIVEN unpaired and non-interactive EXPECT pair hint and no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"not paired"* ]] || false
  [[ "${output}" == *"moshi-hook host setup --host mac.tailnet.ts.net --force"* ]] || false
  ! moshi_called_like "^host" || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN unpaired interactive and prompt times out EXPECT no setup and pair hint" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  # A pipe whose writer stays silent past the 1s timeout makes `read -t` time out.
  run env PATH="${PATH}" bash -c '/bin/sleep 2 | bash "$1"' _ "${INTERACTIVE_SCRIPT}"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Pair now? [y/N]"* ]] || false
  [[ "${output}" == *"To pair it, run"* ]] || false
  ! moshi_called_like "^host" || false
}

@test "GIVEN unpaired interactive and answer no EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "n"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^host" || false
  [[ "${output}" == *"To pair it, run"* ]] || false
}

@test "GIVEN unpaired interactive and y then EOF without Enter EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run env PATH="${PATH}" bash -c 'printf "y" | bash "$1"' _ "${INTERACTIVE_SCRIPT}"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^host" || false
}

@test "GIVEN unpaired interactive and answer other than yes EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "yolo"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^host" || false
}

@test "GIVEN Tailscale stops while the prompt is open EXPECT setup without host or force" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  # Tailscale is Running until the prompt is on screen, then Stopped when "yes" is submitted.
  local marker="${TEST_TMPDIR}/tailscale-stopped"
  local screen="${TEST_TMPDIR}/screen"
  : > "${screen}"

  run env PATH="${PATH}" MOCK_TAILSCALE_STOPPED_MARKER="${marker}" MOSHI_PAIR_PROMPT_TIMEOUT=10 bash -c '
    {
      for _ in {1..100}; do grep -q "Pair now" "$3" && break; /bin/sleep 0.1; done
      touch "$1"
      printf "yes\n"
    } | bash "$2" > "$3"
    cat "$3"' _ "${marker}" "${INTERACTIVE_SCRIPT}" "${screen}"

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup"
}

@test "GIVEN unpaired interactive and answer yes EXPECT setup then e2ee enable" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off

  run_interactive "y" MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json"

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup --host mac.tailnet.ts.net --force"
  moshi_called "e2ee enable"
  [[ "${output}" != *"To pair it, run"* ]] || false
}

@test "GIVEN Tailscale SSH off EXPECT setup without force" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_TAILSCALE_RUN_SSH=false

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup --host mac.tailnet.ts.net"
}

@test "GIVEN Tailscale SSH on but backend stopped EXPECT setup without host or force" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_TAILSCALE_BACKEND=Stopped

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup"
}

@test "GIVEN tailscale unavailable EXPECT plain host setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_TAILSCALE_DOWN=1

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup"
}

@test "GIVEN setup fails EXPECT warning, pair hint, and no e2ee" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_MOSHI_SETUP_FAILS=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"pairing did not complete"* ]] || false
  [[ "${output}" == *"To pair it, run"* ]] || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN setup succeeds but status cannot be read after EXPECT verify hint, not re-pair" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y" MOCK_MOSHI_STATUS_FAILS_MARKER="${TEST_TMPDIR}/status-broken" MOSHI_STATUS_RETRY_DELAY=0

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" != *"To pair it, run"* ]] || false
  [[ "${output}" == *"moshi-hook status"* ]] || false
  [[ "${output}" == *"moshi-hook e2ee enable"* ]] || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN setup fails but host reports paired EXPECT no e2ee change" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off

  run_interactive "y" MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json" MOCK_MOSHI_SETUP_FAILS=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"pairing did not complete"* ]] || false
  ! moshi_called_like "^e2ee" || false
  [[ "${output}" == *"moshi-hook e2ee enable"* ]] || false
}

@test "GIVEN already paired with e2ee off EXPECT policy kept and enable hint" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true current off

  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^e2ee" || false
  [[ "${output}" == *"moshi-hook e2ee enable"* ]] || false
}

@test "GIVEN e2ee enable fails after pairing EXPECT warning without failing apply" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off

  run_interactive "y" MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json" MOCK_MOSHI_E2EE_FAILS=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Failed to enable moshi-hook E2EE"* ]] || false
}
