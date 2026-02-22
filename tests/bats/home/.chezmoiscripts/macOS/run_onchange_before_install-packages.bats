#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/.chezmoiscripts/macOS/run_onchange_before_install-packages.sh.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  MOCK_BIN_DIR="${TEST_TMPDIR}/bin"
  MOCK_FALLBACK_HOME="${TEST_TMPDIR}/fallback"
  mkdir -p "${MOCK_BIN_DIR}" "${MOCK_FALLBACK_HOME}/opt/homebrew/bin" "${MOCK_FALLBACK_HOME}/usr/local/bin"
  export MOCK_FALLBACK_HOME

  cat > "${MOCK_BIN_DIR}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

counter_file="${MOCK_BREW_COUNTER_FILE:?}"
fails_before_success="${MOCK_BREW_FAILS_BEFORE_SUCCESS:-0}"

if [[ "${1:-}" == "bundle" ]]; then
  count=0
  if [[ -f "${counter_file}" ]]; then
    count="$(cat "${counter_file}")"
  fi
  count=$((count + 1))
  printf '%s\n' "${count}" > "${counter_file}"

  if [[ "${count}" -le "${fails_before_success}" ]]; then
    exit 1
  fi
  exit 0
fi

if [[ "${1:-}" == "shellenv" ]]; then
  printf '%s\n' 'export HOMEBREW_MOCKED=1'
  exit 0
fi

exit 0
EOF

  cat > "${MOCK_FALLBACK_HOME}/opt/homebrew/bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

counter_file="${MOCK_BREW_COUNTER_FILE:?}"
fails_before_success="${MOCK_BREW_FAILS_BEFORE_SUCCESS:-0}"

if [[ "${1:-}" == "shellenv" ]]; then
  printf '%s\n' "export PATH=\"${MOCK_FALLBACK_HOME}/opt/homebrew/bin:\$PATH\""
  exit 0
fi

if [[ "${1:-}" == "bundle" ]]; then
  count=0
  if [[ -f "${counter_file}" ]]; then
    count="$(cat "${counter_file}")"
  fi
  count=$((count + 1))
  printf '%s\n' "${count}" > "${counter_file}"

  if [[ "${count}" -le "${fails_before_success}" ]]; then
    exit 1
  fi
  exit 0
fi

exit 0
EOF

  cat > "${MOCK_BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-n" && "${2:-}" == "true" ]]; then
  exit 0
fi

if [[ "${1:-}" == "-v" ]]; then
  exit 0
fi

exit 0
EOF

  cat > "${MOCK_BIN_DIR}/sleep" <<'EOF'
#!/usr/bin/env bash
/bin/sleep 0.01
EOF

  chmod +x "${MOCK_BIN_DIR}/brew" "${MOCK_BIN_DIR}/sudo" "${MOCK_BIN_DIR}/sleep" "${MOCK_FALLBACK_HOME}/opt/homebrew/bin/brew"

  RENDERED_SCRIPT="${TEST_TMPDIR}/install-packages.sh"
  chezmoi execute-template < "${TEMPLATE_PATH}" > "${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"

  export MOCK_BREW_COUNTER_FILE="${TEST_TMPDIR}/brew-bundle-count"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

render_with_overrides() {
  local personal="$1"
  local transient="$2"
  local output_path="$3"

  local override_file="${TEST_TMPDIR}/override-${personal}-${transient}.json"
  printf '{"personal":%s,"transient":%s}\n' "${personal}" "${transient}" > "${override_file}"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${TEMPLATE_PATH}" > "${output_path}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

render_with_mocked_brew_paths() {
  local output_path="$1"
  sed -e "s|/opt/homebrew|${MOCK_FALLBACK_HOME}/opt/homebrew|g" -e "s|/usr/local|${MOCK_FALLBACK_HOME}/usr/local|g" "${RENDERED_SCRIPT}" > "${output_path}"
  chmod +x "${output_path}"
}

@test "GIVEN brew bundle fails once EXPECT script retries and succeeds" {
  export MOCK_BREW_FAILS_BEFORE_SUCCESS=1

  run bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 0 ]
  [ "$(cat "${MOCK_BREW_COUNTER_FILE}")" -eq 2 ]
}

@test "GIVEN brew bundle keeps failing EXPECT script exits after max attempts" {
  export MOCK_BREW_FAILS_BEFORE_SUCCESS=99
  export BREW_BUNDLE_MAX_ATTEMPTS=2

  run bash "${RENDERED_SCRIPT}"

  [ "${status}" -eq 1 ]
  [ "$(cat "${MOCK_BREW_COUNTER_FILE}")" -eq 2 ]
}

@test "GIVEN personal non-transient EXPECT personal package set excludes work-only brews" {
  rendered_file="${TEST_TMPDIR}/rendered-personal.sh"
  render_with_overrides true false "${rendered_file}"

  run grep -q 'brew "mkcert"' "${rendered_file}"
  [ "${status}" -eq 0 ]

  run grep -q 'brew "awscli"' "${rendered_file}"
  [ "${status}" -eq 1 ]
}

@test "GIVEN non-personal non-transient EXPECT work package set includes work brews" {
  rendered_file="${TEST_TMPDIR}/rendered-non-personal.sh"
  render_with_overrides false false "${rendered_file}"

  run grep -q 'brew "awscli"' "${rendered_file}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN transient machine EXPECT mas and not-transient casks are omitted" {
  rendered_file="${TEST_TMPDIR}/rendered-transient.sh"
  render_with_overrides false true "${rendered_file}"

  run grep -q 'mas "OpenIn"' "${rendered_file}"
  [ "${status}" -eq 1 ]

  run grep -q 'cask "parallels"' "${rendered_file}"
  [ "${status}" -eq 1 ]
}

@test "GIVEN brew absent in PATH EXPECT script resolves brew via fallback shellenv path" {
  rm -f "${MOCK_BIN_DIR}/brew"
  fallback_script="${TEST_TMPDIR}/install-packages-fallback.sh"
  render_with_mocked_brew_paths "${fallback_script}"

  run env PATH="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${fallback_script}"

  [ "${status}" -eq 0 ]
  [ "$(cat "${MOCK_BREW_COUNTER_FILE}")" -ge 1 ]
}

@test "GIVEN brew unavailable everywhere EXPECT script exits with clear missing-brew error" {
  rm -f "${MOCK_BIN_DIR}/brew" "${MOCK_FALLBACK_HOME}/opt/homebrew/bin/brew"
  fallback_script="${TEST_TMPDIR}/install-packages-no-brew.sh"
  render_with_mocked_brew_paths "${fallback_script}"

  run -127 env PATH="${MOCK_BIN_DIR}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${fallback_script}"

  [ "${status}" -eq 127 ]
  [[ "${output}" == *"Homebrew is required but was not found in PATH."* ]]
}
