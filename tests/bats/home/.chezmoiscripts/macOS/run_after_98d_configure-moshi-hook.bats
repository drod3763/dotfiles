#!/usr/bin/env bats

# Assertions that are not a test's last command end in `|| false`: bats runs under macOS
# bash 3.2 here, where a failing `[[ ]]` or `! cmd` mid-test does not fail the test.

load "${BATS_TEST_DIRNAME}/../../../helpers/chezmoi"

setup() {
  command -v jq >/dev/null 2>&1 || skip "jq is required"

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_after_98d_configure-moshi-hook.sh.tmpl"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  # Status comes from MOCK_MOSHI_STATUS_FILE; `host setup` swaps in
  # MOCK_MOSHI_STATUS_AFTER_SETUP_FILE so the post-pairing re-read can be asserted.
  # MOCK_MOSHI_SETUP_NEEDS_FORCE mimics moshi's prerequisite stop: exit 1 unless --force.
  cat > "${MOCK_BIN_DIR}/moshi-hook" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MOCK_MOSHI_CALLS_FILE:?}"
case "$1" in
  status)
    if [[ -n "${MOCK_MOSHI_STATUS_RAW:-}" ]]; then
      printf '%s\n' "${MOCK_MOSHI_STATUS_RAW}"
      exit "${MOCK_MOSHI_STATUS_RAW_EXIT:-0}"
    fi
    [[ -z "${MOCK_MOSHI_STATUS_FAILS:-}" ]] || exit 1
    [[ ! -e "${MOCK_MOSHI_STATUS_FAILS_MARKER:-/nonexistent}" ]] || exit 1
    # After setup, MOCK_MOSHI_STALE_READS reads still return the pre-setup status.
    stale_file="${MOCK_MOSHI_STATUS_FILE}.stale"
    if [[ -f "${stale_file}" ]]; then
      stale="$(cat "${stale_file}")"
      if (( stale > 0 )); then
        printf '%s\n' "$((stale - 1))" > "${stale_file}"
      elif [[ -f "${MOCK_MOSHI_STATUS_FILE}.next" ]]; then
        mv "${MOCK_MOSHI_STATUS_FILE}.next" "${MOCK_MOSHI_STATUS_FILE}"
      fi
    fi
    cat "${MOCK_MOSHI_STATUS_FILE:?}"
    ;;
  install) [[ -z "${MOCK_MOSHI_INSTALL_FAILS:-}" ]] ;;
  host)
    if [[ -n "${MOCK_MOSHI_SETUP_NEEDS_FORCE:-}" ]] && [[ " $* " != *" --force "* ]]; then
      printf '%s\n' "Tailscale SSH is enabled on this host. Then run \`moshi-hook host setup\` again."
      exit 1
    fi
    if [[ -n "${MOCK_MOSHI_STATUS_AFTER_SETUP_FILE:-}" ]]; then
      if [[ -n "${MOCK_MOSHI_STALE_READS:-}" ]]; then
        cp "${MOCK_MOSHI_STATUS_AFTER_SETUP_FILE}" "${MOCK_MOSHI_STATUS_FILE}.next"
        printf '%s\n' "${MOCK_MOSHI_STALE_READS}" > "${MOCK_MOSHI_STATUS_FILE}.stale"
      else
        cp "${MOCK_MOSHI_STATUS_AFTER_SETUP_FILE}" "${MOCK_MOSHI_STATUS_FILE}"
      fi
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
esac
EOF

  chmod +x "${MOCK_BIN_DIR}"/*

  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_MOSHI_CALLS_FILE="${TEST_TMPDIR}/moshi.calls"
  export MOCK_MOSHI_STATUS_FILE="${TEST_TMPDIR}/status.json"
  export MOSHI_PROMPT_TIMEOUT=1
  export MOSHI_STATUS_RETRY_DELAY=0
  touch "${MOCK_MOSHI_CALLS_FILE}"

  # Default fixture: fully converged host.
  write_status "${MOCK_MOSHI_STATUS_FILE}" true current on

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_after_98d_configure-moshi-hook.sh"
  chezmoi_execute_template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"

  # Same script with the TTY guard forced on, for the interactive pairing paths.
  INTERACTIVE_SCRIPT="${TEST_TMPDIR}/interactive.sh"
  sed 's/\[\[ ! -t 0 \]\]/false/' "${RENDERED_SCRIPT}" > "${INTERACTIVE_SCRIPT}"
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

# run_interactive <answer>...: each answer is submitted with Enter; then stdin hits EOF.
run_interactive() {
  run env PATH="${PATH}" bash -c 'shift; printf "%s\n" "$@" | bash "$0"' "${INTERACTIVE_SCRIPT}" _ "$@"
}

@test "GIVEN converged host EXPECT only a status read and an all-clear report" {
  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  [[ "$(cat "${MOCK_MOSHI_CALLS_FILE}")" == "status --json" ]] || false
  [[ "${output}" == *"Moshi setup report"* ]] || false
  [[ "${output}" == *"Hooks: current."* ]] || false
  [[ "${output}" == *"Pairing: already paired."* ]] || false
  [[ "${output}" == *"E2EE: on."* ]]
}

@test "GIVEN claude hooks not current EXPECT install only stale targets" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true missing on

  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  moshi_called "install --target claude"
  [[ "${output}" == *"Hooks: reinstalled for claude."* ]]
}

@test "GIVEN hook install fails EXPECT reported without failing apply" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true missing on

  run_rendered_script MOCK_MOSHI_INSTALL_FAILS=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Hooks: install failed for claude"* ]]
}

@test "GIVEN status unavailable EXPECT skip reported without failing apply" {
  run_rendered_script MOCK_MOSHI_STATUS_FAILS=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Skipped: moshi-hook status is unavailable"* ]] || false
  ! moshi_called_like "install" || false
}

@test "GIVEN status prints a JSON error string EXPECT skip reported without failing apply" {
  run_rendered_script MOCK_MOSHI_STATUS_RAW='"daemon not running"'

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Skipped: moshi-hook status is unavailable"* ]] || false
  ! moshi_called_like "install" || false
}

@test "GIVEN status prints JSON but exits nonzero EXPECT skip" {
  run_rendered_script MOCK_MOSHI_STATUS_RAW='{"paired":false,"hooks":[]}' MOCK_MOSHI_STATUS_RAW_EXIT=1

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Skipped: moshi-hook status is unavailable"* ]]
}

@test "GIVEN status object without a paired field EXPECT skip" {
  run_rendered_script MOCK_MOSHI_STATUS_RAW='{"error":"not ready"}'

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Skipped: moshi-hook status is unavailable"* ]]
}

@test "GIVEN host gets paired while the pair prompt is open EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${MOCK_MOSHI_STATUS_FILE}.next" true current off
  # The read before the prompt shows unpaired; the next read (after "y") shows paired.
  printf '1\n' > "${MOCK_MOSHI_STATUS_FILE}.stale"

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^host" || false
  ! moshi_called_like "^e2ee" || false
  [[ "${output}" == *"Pairing: not run"* ]]
}

@test "GIVEN host gets paired while the force prompt is open EXPECT no forced setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${MOCK_MOSHI_STATUS_FILE}.next" true current off
  export MOCK_MOSHI_SETUP_NEEDS_FORCE=1
  # Reads: before the pair prompt, after "y", before the force prompt: unpaired; after "y": paired.
  printf '3\n' > "${MOCK_MOSHI_STATUS_FILE}.stale"

  run_interactive "y" "y"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"--force? [y/N]"* ]] || false
  ! moshi_called_like "force" || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN unpaired and non-interactive EXPECT no setup and pair command in report" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"not interactive, so pairing was not offered"* ]] || false
  [[ "${output}" == *"to pair, run: moshi-hook host setup --host mac.tailnet.ts.net (add --force"* ]] || false
  [[ "${output}" == *"E2EE: not changed (needs a pairing)."* ]] || false
  ! moshi_called_like "^host" || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN pair prompt times out EXPECT no setup and declined in report" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  # A pipe whose writer stays silent past the 1s timeout makes `read -t` time out.
  run env PATH="${PATH}" bash -c '/bin/sleep 2 | bash "$1"' _ "${INTERACTIVE_SCRIPT}"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Pair now? [y/N] (no in 1s)"* ]] || false
  [[ "${output}" == *"Pairing: declined (or no answer in 1s)."* ]] || false
  ! moshi_called_like "^host" || false
}

@test "GIVEN pair prompt answered no EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "n"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^host" || false
  [[ "${output}" == *"Pairing: declined"* ]]
}

@test "GIVEN y then EOF without Enter EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run env PATH="${PATH}" bash -c 'printf "y" | bash "$1"' _ "${INTERACTIVE_SCRIPT}"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^host" || false
}

@test "GIVEN answer other than yes EXPECT no setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "yolo"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^host" || false
}

@test "GIVEN answer yes and setup passes its checks EXPECT setup without force then e2ee enable" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off
  export MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json"

  run_interactive "yes"

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup --host mac.tailnet.ts.net"
  ! moshi_called_like "force" || false
  moshi_called "e2ee enable"
  [[ "${output}" == *"Pairing: paired."* ]] || false
  [[ "${output}" == *"E2EE: enabled"* ]]
}

@test "GIVEN setup stops on warnings and user continues EXPECT forced setup and e2ee enable" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off
  export MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json"
  export MOCK_MOSHI_SETUP_NEEDS_FORCE=1

  run_interactive "y" "y"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Tailscale SSH is enabled on this host"* ]] || false
  [[ "${output}" == *"Pairing stopped on the warnings above. Continue past them with --force? [y/N]"* ]] || false
  moshi_called "host setup --host mac.tailnet.ts.net"
  moshi_called "host setup --host mac.tailnet.ts.net --force"
  moshi_called "e2ee enable"
  [[ "${output}" == *"Pairing: paired (continued past prerequisite warnings with --force)."* ]]
}

@test "GIVEN setup stops on warnings and the force prompt is not answered EXPECT no forced setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  export MOCK_MOSHI_SETUP_NEEDS_FORCE=1

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "force" || false
  ! moshi_called_like "^e2ee" || false
  [[ "${output}" == *"Pairing: did not complete."* ]] || false
  [[ "${output}" == *"to pair, run: moshi-hook host setup --host mac.tailnet.ts.net"* ]]
}

@test "GIVEN Tailscale backend stopped EXPECT setup without host" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  export MOCK_TAILSCALE_BACKEND=Stopped

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup"
}

@test "GIVEN Tailscale stops while the prompt is open EXPECT setup without host" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  # Tailscale is Running until the prompt is on screen, then Stopped when "yes" is submitted.
  local marker="${TEST_TMPDIR}/tailscale-stopped"
  local screen="${TEST_TMPDIR}/screen"
  : > "${screen}"

  run env PATH="${PATH}" MOCK_TAILSCALE_STOPPED_MARKER="${marker}" MOSHI_PROMPT_TIMEOUT=10 bash -c '
    {
      for _ in {1..100}; do grep -q "Pair now" "$3" && break; /bin/sleep 0.1; done
      touch "$1"
      printf "yes\n"
    } | bash "$2" > "$3"
    cat "$3"' _ "${marker}" "${INTERACTIVE_SCRIPT}" "${screen}"

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup"
}

@test "GIVEN tailscale unavailable EXPECT plain host setup" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  export MOCK_TAILSCALE_DOWN=1

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  moshi_called "host setup"
}

@test "GIVEN setup fails for a reason other than its prerequisite checks EXPECT no force offered" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  export MOCK_MOSHI_SETUP_FAILS=1

  run_interactive "y" "y"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" != *"--force? [y/N]"* ]] || false
  [[ "${output}" == *"Pairing: did not complete."* ]] || false
  ! moshi_called_like "force" || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN setup succeeds but status briefly still shows unpaired EXPECT confirmed and e2ee enabled" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off
  export MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json"
  export MOCK_MOSHI_STALE_READS=1

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  moshi_called "e2ee enable"
  [[ "${output}" == *"Pairing: paired."* ]] || false
  [[ "${output}" != *"to pair, run"* ]]
}

@test "GIVEN setup succeeds but status never shows paired EXPECT unconfirmed report without re-pair" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"could not confirm the pairing. Check: moshi-hook status"* ]] || false
  [[ "${output}" != *"to pair, run"* ]] || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN setup succeeds but status cannot be read after EXPECT verify hint, not re-pair" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  export MOCK_MOSHI_STATUS_FAILS_MARKER="${TEST_TMPDIR}/status-broken"

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" != *"to pair, run"* ]] || false
  [[ "${output}" == *"could not confirm the pairing. Check: moshi-hook status"* ]] || false
  [[ "${output}" == *"run: moshi-hook e2ee enable"* ]] || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN setup fails but host reports paired EXPECT no e2ee change" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off
  export MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json"
  export MOCK_MOSHI_SETUP_FAILS=1

  run_interactive "y" "y"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"Pairing: did not complete."* ]] || false
  ! moshi_called_like "force" || false
  ! moshi_called_like "^e2ee" || false
  [[ "${output}" == *"E2EE: off, left as is"* ]]
}

@test "GIVEN setup stops on warnings but host is paired by then EXPECT no force offered" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off
  export MOCK_MOSHI_SETUP_NEEDS_FORCE=1
  # Paired from elsewhere while setup ran: the refusal is real but the host is now paired.
  cp "${TEST_TMPDIR}/after.json" "${MOCK_MOSHI_STATUS_FILE}.next"
  printf '1\n' > "${MOCK_MOSHI_STATUS_FILE}.stale"

  run_interactive "y" "y"

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "force" || false
  ! moshi_called_like "^e2ee" || false
}

@test "GIVEN already paired with e2ee off EXPECT policy kept and enable hint" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" true current off

  run_rendered_script

  [[ "${status}" -eq 0 ]] || false
  ! moshi_called_like "^e2ee" || false
  [[ "${output}" == *"E2EE: off, left as is. To turn it on, run: moshi-hook e2ee enable"* ]]
}

@test "GIVEN e2ee enable fails after pairing EXPECT reported without failing apply" {
  write_status "${MOCK_MOSHI_STATUS_FILE}" false current off
  write_status "${TEST_TMPDIR}/after.json" true current off
  export MOCK_MOSHI_STATUS_AFTER_SETUP_FILE="${TEST_TMPDIR}/after.json"
  export MOCK_MOSHI_E2EE_FAILS=1

  run_interactive "y"

  [[ "${status}" -eq 0 ]] || false
  [[ "${output}" == *"E2EE: enable failed. Run: moshi-hook e2ee enable"* ]]
}
