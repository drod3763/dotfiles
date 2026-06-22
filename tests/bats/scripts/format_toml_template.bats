#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  SCRIPT="${REPO_ROOT}/scripts/format_toml_template.js"

  for tool in bun taplo chezmoi; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      skip "${tool} is required for format_toml_template tests"
    fi
  done

  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

fmt() {
  run bun "${SCRIPT}" "$@"
}

@test "GIVEN messy renderable template EXPECT dedented TOML and normalized Go" {
  local f="${TEST_TMPDIR}/a.toml.tmpl"
  cat > "${f}" <<'EOF'
[a]
    type = "file"
    url    =   "https://example.com/x"
{{- if true }}
[b]
k=1
{{-   end }}
EOF

  fmt "${f}"
  [ "${status}" -eq 0 ]

  # No static line keeps its leading indentation (taplo left-aligns entries).
  run grep -nE '^[[:space:]]+(type|url|k)' "${f}"
  [ "${status}" -ne 0 ]

  # Spacing around `=` normalized on a previously-cramped line.
  run grep -qxF 'k = 1' "${f}"
  [ "${status}" -eq 0 ]

  # Go expressions normalized (collapsed padding).
  run grep -qxF '{{- end }}' "${f}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN already-formatted template EXPECT idempotent second run" {
  local f="${TEST_TMPDIR}/idem.toml.tmpl"
  cat > "${f}" <<'EOF'
[a]
    type = "file"
    url = "https://example.com/x"
EOF

  fmt "${f}"
  [ "${status}" -eq 0 ]
  local first
  first="$(cat "${f}")"

  fmt "${f}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${f}")" = "${first}" ]
}

@test "GIVEN renderable template EXPECT rendered TOML semantically unchanged" {
  local f="${TEST_TMPDIR}/sem.toml.tmpl"
  cat > "${f}" <<'EOF'
[a]
    type = "file"
    url    =   "https://example.com/x"
{{- if true }}
k=1
{{-   end }}
EOF

  local before
  before="$(chezmoi execute-template < "${f}" | taplo format --no-auto-config -o reorder_keys=false -)"

  fmt "${f}"
  [ "${status}" -eq 0 ]

  local after
  after="$(chezmoi execute-template < "${f}" | taplo format --no-auto-config -o reorder_keys=false -)"
  [ "${before}" = "${after}" ]
}

@test "GIVEN non-renderable template EXPECT step 2 skipped and exit 0" {
  local f="${TEST_TMPDIR}/skip.toml.tmpl"
  cat > "${f}" <<'EOF'
[a]
    type = "file"
x = {{ promptBool "q" }}
EOF

  fmt "${f}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"skip step 2"* ]]

  # Step 2 skipped: the indented static line is left untouched.
  run grep -qE '^    type = "file"' "${f}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN string with internal spaces EXPECT contents preserved" {
  local f="${TEST_TMPDIR}/str.toml.tmpl"
  cat > "${f}" <<'EOF'
[a]
    msg = "hello   world"
EOF

  fmt "${f}"
  [ "${status}" -eq 0 ]

  run grep -qxF 'msg = "hello   world"' "${f}"
  [ "${status}" -eq 0 ]
}
