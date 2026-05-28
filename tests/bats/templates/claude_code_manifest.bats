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

render_template() {
  local template_path="$1"
  local personal="$2"
  local output_path="$3"

  local override_file="${TEST_TMPDIR}/override-${personal}.json"
  printf '{"personal":%s}\n' "${personal}" >"${override_file}"
  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" <"${template_path}" >"${output_path}"
}

@test "GIVEN work profile EXPECT work marketplaces and plugins are active" {
  marketplace_json="${TEST_TMPDIR}/marketplaces-work.json"
  plugin_json="${TEST_TMPDIR}/plugins-work.json"

  render_template "${REPO_ROOT}/home/.chezmoitemplates/claude_code_marketplace_renderer.tmpl" false "${marketplace_json}"
  render_template "${REPO_ROOT}/home/.chezmoitemplates/claude_code_plugin_renderer.tmpl" false "${plugin_json}"

  run jq -e '.extraKnownMarketplaces.arcus.source.url == "git@github.com:mindbody/arcus-agentic-resources.git"' "${marketplace_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.extraKnownMarketplaces.cloudflare == null' "${marketplace_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.extraKnownMarketplaces."claude-plugins-official" == null' "${marketplace_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."arcus-build@arcus" == true' "${plugin_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."marketplace@agentic-tools" == null' "${plugin_json}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN personal profile EXPECT personal marketplaces and plugins are active" {
  marketplace_json="${TEST_TMPDIR}/marketplaces-personal.json"
  plugin_json="${TEST_TMPDIR}/plugins-personal.json"

  render_template "${REPO_ROOT}/home/.chezmoitemplates/claude_code_marketplace_renderer.tmpl" true "${marketplace_json}"
  render_template "${REPO_ROOT}/home/.chezmoitemplates/claude_code_plugin_renderer.tmpl" true "${plugin_json}"

  run jq -e '.extraKnownMarketplaces.cloudflare.source.repo == "cloudflare/skills"' "${marketplace_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.extraKnownMarketplaces.arcus == null' "${marketplace_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."cloudflare@cloudflare" == true' "${plugin_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."marketplace@agentic-tools" == true' "${plugin_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."arcus-build@arcus" == null' "${plugin_json}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN disabled plugin override EXPECT install seed exists without enabled setting" {
  override_file="${TEST_TMPDIR}/override-disabled.json"
  plugin_json="${TEST_TMPDIR}/plugins-disabled.json"

  cat >"${override_file}" <<'JSON'
{
  "personal": false,
  "claude_code": {
    "plugins": {
      "disabled-test@agentic-tools": {
        "type": "common",
        "enabled": false,
        "depends_on": ["marketplace:agentic-tools"],
        "scope": "user",
        "version": "1.0.0",
        "git_commit_sha": "abc123"
      }
    }
  }
}
JSON

  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" <"${REPO_ROOT}/home/.chezmoitemplates/claude_code_plugin_renderer.tmpl" >"${plugin_json}"

  run jq -e '.install_seeds."disabled-test@agentic-tools"["version"] == "1.0.0"' "${plugin_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."disabled-test@agentic-tools" == null' "${plugin_json}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN owned marketplace pruning EXPECT project scoped plugin is preserved" {
  override_file="${TEST_TMPDIR}/override-installed.json"
  output_json="${TEST_TMPDIR}/installed-output.json"

  jq -n --arg stdin '{"version":2,"plugins":{"old-user@agentic-tools":[{"scope":"user"}],"old-project@agentic-tools":[{"scope":"project"}],"local@random":[{"scope":"user"}]}}' '{"chezmoi":{"stdin":$stdin}}' >"${override_file}"

  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" <"${REPO_ROOT}/home/private_dot_config/claude/plugins/modify_installed_plugins.json" >"${output_json}"

  run jq -e '.plugins."old-user@agentic-tools" == null' "${output_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.plugins."old-project@agentic-tools"[0].scope == "project"' "${output_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.plugins."local@random"[0].scope == "user"' "${output_json}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN project scoped manifest plugin EXPECT installed but not globally enabled" {
  override_file="${TEST_TMPDIR}/override-project-plugin.json"
  plugin_json="${TEST_TMPDIR}/plugins-project.json"

  cat >"${override_file}" <<'JSON'
{
  "personal": false,
  "claude_code": {
    "plugins": {
      "project-test@agentic-tools": {
        "type": "common",
        "enabled": true,
        "depends_on": ["marketplace:agentic-tools"],
        "scope": "project",
        "version": "1.0.0",
        "git_commit_sha": "abc123"
      }
    }
  }
}
JSON

  "${REAL_CHEZMOI_BIN}" execute-template --override-data-file "${override_file}" <"${REPO_ROOT}/home/.chezmoitemplates/claude_code_plugin_renderer.tmpl" >"${plugin_json}"

  run jq -e '.install_seeds."project-test@agentic-tools".scope == "project"' "${plugin_json}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."project-test@agentic-tools" == null' "${plugin_json}"
  [ "${status}" -eq 0 ]
}
