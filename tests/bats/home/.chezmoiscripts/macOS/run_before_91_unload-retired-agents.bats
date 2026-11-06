#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../../helpers/chezmoi"

setup() {
  bats_require_minimum_version 1.5.0

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_once_before_91_unload-retired-agents.sh.tmpl"
  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  export MOCK_CALLS_FILE="${TEST_TMPDIR}/calls"
  touch "${MOCK_CALLS_FILE}"

  # MOCK_LOADED_LABELS: space-separated labels that `print` reports as loaded.
  cat >"${MOCK_BIN_DIR}/launchctl" <<'EOF'
#!/bin/bash
printf 'launchctl %s\n' "$*" >>"${MOCK_CALLS_FILE:?}"
if [[ "$1" == "print" ]]; then
  [[ " ${MOCK_LOADED_LABELS} " == *" ${2##*/} "* ]] && exit 0
  exit 113
fi
exit 0
EOF
  chmod +x "${MOCK_BIN_DIR}/launchctl"
  export CHEZMOI_LAUNCHCTL_BIN="${MOCK_BIN_DIR}/launchctl"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_before_91_unload-retired-agents.sh"
  chezmoi_execute_template <"${TEMPLATE_PATH}" >"${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN all retired agents loaded EXPECT script boots out each one" {
  export MOCK_LOADED_LABELS="local.herdr-server homebrew.mxcl.borders homebrew.mxcl.herdr-mx"
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  for label in local.herdr-server homebrew.mxcl.borders homebrew.mxcl.herdr-mx; do
    [[ "${output}" == *"unloaded retired agent ${label}."* ]]
    run grep -qx "launchctl bootout gui/$(id -u)/${label}" "${MOCK_CALLS_FILE}"
    [[ "${status}" -eq 0 ]]
  done
}

@test "GIVEN only borders loaded EXPECT script boots out borders alone" {
  export MOCK_LOADED_LABELS="homebrew.mxcl.borders"
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "unloaded retired agent homebrew.mxcl.borders." ]]
  run grep -c '^launchctl bootout' "${MOCK_CALLS_FILE}"
  [[ "${output}" == "1" ]]
}

@test "GIVEN no retired agents loaded EXPECT script is a silent no-op" {
  export MOCK_LOADED_LABELS=""
  run bash "${RENDERED_SCRIPT}"

  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
  run grep -q '^launchctl bootout' "${MOCK_CALLS_FILE}"
  [[ "${status}" -ne 0 ]]
}
