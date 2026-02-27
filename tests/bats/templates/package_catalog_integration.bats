#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.5.0

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

render_with_overrides() {
  local template_path="$1"
  local personal="$2"
  local transient="$3"
  local output_path="$4"

  local override_file="${TEST_TMPDIR}/override-${personal}-${transient}.json"
  printf '{"personal":%s,"transient":%s}\n' "${personal}" "${transient}" > "${override_file}"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" < "${template_path}" > "${output_path}"
}

@test "GIVEN non-personal host EXPECT saml2aws package function is included" {
  output_file="${TEST_TMPDIR}/functions-work-host.sh"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/functions.tmpl" false false "${output_file}"

  run grep -q '^loginarcus() {' "${output_file}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN personal host EXPECT saml2aws package function is excluded" {
  output_file="${TEST_TMPDIR}/functions-personal-host.sh"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/functions.tmpl" true false "${output_file}"

  run grep -q '^loginarcus() {' "${output_file}"
  [ "${status}" -eq 1 ]
}

@test "GIVEN darwin context EXPECT tailscale package alias and claude export are included" {
  aliases_file="${TEST_TMPDIR}/aliases.sh"
  exports_file="${TEST_TMPDIR}/exports.sh"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/aliases.tmpl" false false "${aliases_file}"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/exports.tmpl" false false "${exports_file}"

  run grep -q "^alias tsfix='sudo ./tailscaled install-system-daemon'" "${aliases_file}"
  [ "${status}" -eq 0 ]

  run grep -q '^export CLAUDE_CONFIG_DIR=' "${exports_file}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN personal profile EXPECT work-scoped AWS and Tilt exports are excluded" {
  exports_file="${TEST_TMPDIR}/exports-personal.sh"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/exports.tmpl" true false "${exports_file}"

  run grep -q '^export AWS_PROFILE=' "${exports_file}"
  [ "${status}" -eq 1 ]

  run grep -q '^export TILT_NAMESPACE=' "${exports_file}"
  [ "${status}" -eq 1 ]
}

@test "GIVEN transient context EXPECT resolver excludes host-only package" {
  host_json="${TEST_TMPDIR}/resolver-host.json"
  vm_json="${TEST_TMPDIR}/resolver-vm.json"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/package_catalog_resolver.tmpl" false false "${host_json}"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/package_catalog_resolver.tmpl" false true "${vm_json}"

  run jq -e '.active_packages | index("parallels") != null' "${host_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.active_packages | index("parallels") == null' "${vm_json}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN package uses mise EXPECT resolver routes package away from brew" {
  resolver_json="${TEST_TMPDIR}/resolver-mise.json"
  render_with_overrides "${REPO_ROOT}/home/.chezmoitemplates/package_catalog_resolver.tmpl" false false "${resolver_json}"

  run jq -e '.mise_packages | index("bun") != null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.mise_packages | index("node") != null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.mise_packages | index("pnpm") != null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.mise_packages | index("dotnet@8") != null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.mise_packages | index("go") != null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.mise_packages | index("python") != null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.brew_formulas | index("oven-sh/bun/bun") == null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.brew_formulas | index("dotnet@8") == null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.brew_formulas | index("go") == null' "${resolver_json}"
  [ "${status}" -eq 0 ]

  run jq -e '.brew_formulas | index("python") == null' "${resolver_json}"
  [ "${status}" -eq 0 ]
}
