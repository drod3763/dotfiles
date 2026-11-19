#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers/chezmoi"

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/dot_claude/modify_settings.json"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"
  TEST_TMPDIR="$(mktemp -d)"

  # Render as a Windows work machine on any host: the template is Windows-only,
  # and work makes the personal-only cloudflare marketplace and plugin inactive.
  OVERRIDE_FILE="${TEST_TMPDIR}/override.json"
  printf '{"personal":false,"chezmoi":{"os":"windows"}}\n' >"${OVERRIDE_FILE}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# Runs the modify template with $1 as the current ~/.claude/settings.json.
merge_settings() {
  chezmoi_execute_template --override-data-file "${OVERRIDE_FILE}" --with-stdin \
    "$(cat "${TEMPLATE_PATH}")" <"$1" >"$2"
}

@test "GIVEN local settings EXPECT unrelated keys and local entries are kept" {
  input_file="${TEST_TMPDIR}/input.json"
  output_file="${TEST_TMPDIR}/output.json"
  cat >"${input_file}" <<'JSON'
{
  "theme": "dark",
  "env": { "LOCAL_VAR": "1" },
  "extraKnownMarketplaces": {
    "local-market": { "source": { "source": "directory", "path": "C:/local" } }
  },
  "enabledPlugins": {
    "local-plugin@local-market": true,
    "local-plugin@team-rocket-tools": true
  }
}
JSON

  merge_settings "${input_file}" "${output_file}"

  run jq -e '.theme == "dark" and .env.LOCAL_VAR == "1"' "${output_file}"
  [ "${status}" -eq 0 ]
  run jq -e '.extraKnownMarketplaces."local-market".source.path == "C:/local"' "${output_file}"
  [ "${status}" -eq 0 ]
  # Plugins of a marketplace the data does not own are kept.
  run jq -e '.enabledPlugins."local-plugin@local-market" == true and .enabledPlugins."local-plugin@team-rocket-tools" == true' "${output_file}"
  [ "${status}" -eq 0 ]
  run jq -e '.extraKnownMarketplaces."agentic-tools".source.url == "git@github.com:drod3763/agentic-tools.git"' "${output_file}"
  [ "${status}" -eq 0 ]
  run jq -e '.enabledPlugins."engineering@agentic-tools" == true' "${output_file}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN ineligible manifest plugins EXPECT them disabled and inactive marketplaces dropped" {
  input_file="${TEST_TMPDIR}/input.json"
  output_file="${TEST_TMPDIR}/output.json"
  cat >"${input_file}" <<'JSON'
{
  "extraKnownMarketplaces": {
    "cloudflare": { "source": { "source": "github", "repo": "cloudflare/skills" } }
  },
  "enabledPlugins": {
    "imessage@claude-plugins-official": true,
    "cloudflare@cloudflare": true
  }
}
JSON

  merge_settings "${input_file}" "${output_file}"

  # not_os = ["windows"]
  run jq -e '.enabledPlugins."imessage@claude-plugins-official" == false' "${output_file}"
  [ "${status}" -eq 0 ]
  # personal-only plugin on a work machine
  run jq -e '.enabledPlugins."cloudflare@cloudflare" == false' "${output_file}"
  [ "${status}" -eq 0 ]
  run jq -e '.extraKnownMarketplaces | has("cloudflare") | not' "${output_file}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN a plugin deleted from an owned marketplace EXPECT it removed" {
  input_file="${TEST_TMPDIR}/input.json"
  output_file="${TEST_TMPDIR}/output.json"
  cat >"${input_file}" <<'JSON'
{
  "enabledPlugins": { "retired-plugin@agentic-tools": true }
}
JSON

  merge_settings "${input_file}" "${output_file}"

  run jq -e '.enabledPlugins | has("retired-plugin@agentic-tools") | not' "${output_file}"
  [ "${status}" -eq 0 ]
}

@test "GIVEN merged settings EXPECT a second apply to change nothing" {
  input_file="${TEST_TMPDIR}/input.json"
  first_file="${TEST_TMPDIR}/first.json"
  second_file="${TEST_TMPDIR}/second.json"
  cat >"${input_file}" <<'JSON'
{
  "theme": "dark",
  "enabledPlugins": {
    "retired-plugin@agentic-tools": true,
    "imessage@claude-plugins-official": true
  }
}
JSON

  merge_settings "${input_file}" "${first_file}"
  merge_settings "${first_file}" "${second_file}"

  run cmp "${first_file}" "${second_file}"
  [ "${status}" -eq 0 ]
}
