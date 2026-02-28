#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_onchange_before_install-packages_mise.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  mkdir -p "${MOCK_BIN_DIR}"

  cat > "${MOCK_BIN_DIR}/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "activate" ]]; then
  printf '%s\n' "$*" >> "${MOCK_MISE_CALLS_FILE:?}"
  printf '%s\n' ':'
  exit 0
fi

printf '%s\n' "$*" >> "${MOCK_MISE_CALLS_FILE:?}"
EOF

  chmod +x "${MOCK_BIN_DIR}/mise"
  export MOCK_MISE_CALLS_FILE="${TEST_TMPDIR}/mise.calls"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  override_file="${TEST_TMPDIR}/override.json"
  printf '%s\n' '{"personal":false,"transient":false,"shell":"zsh"}' > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_onchange_before_install-packages_mise.sh"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

render_with_shell() {
  local shell_name="$1"
  local override_file="${TEST_TMPDIR}/override-${shell_name}.json"
  printf '{"personal":false,"transient":false,"shell":"%s"}\n' "${shell_name}" > "${override_file}"

  RENDERED_SCRIPT="${TEST_TMPDIR}/run_onchange_before_install-packages_mise-${shell_name}.sh"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "GIVEN package marked use_mise EXPECT script installs package via mise" {
  run env -u MISE_SHELL bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^activate bash$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -eq 0 ]

  run grep -q '^install --global bun$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -eq 0 ]

  run grep -q '^install --global node$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -eq 0 ]

  run grep -q '^install --global pnpm$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -eq 0 ]

  run grep -q '^install --global dotnet@8$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -eq 0 ]

  run grep -q '^install --global go$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -ne 0 ]

  run grep -q '^install --global python$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -ne 0 ]
}

@test "GIVEN shell templatedata is zsh EXPECT script still activates mise for bash" {
  render_with_shell "zsh"

  run env -u MISE_SHELL bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^activate bash$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN mise already activated EXPECT script skips activation" {
  run env MISE_SHELL=bash bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 0 ]
  run grep -q '^activate bash$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -ne 0 ]

  run grep -q '^install --global bun$' "${MOCK_MISE_CALLS_FILE}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN mise unavailable EXPECT script exits with clear missing-mise error" {
  rm -f "${MOCK_BIN_DIR}/mise"

  run -127 env PATH="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 127 ]
  [[ "${output}" == *"mise is required to install packages marked with use_mise"* ]]
}
