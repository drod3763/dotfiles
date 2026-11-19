#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../../helpers/chezmoi"

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TEMPLATE_PATH="${REPO_ROOT}/home/private_dot_config/claude/modify_settings.json.tmpl"
  REAL_CHEZMOI_BIN="$(command -v chezmoi)"

  TEST_TMPDIR="$(mktemp -d)"
  RENDERED_SCRIPT="${TEST_TMPDIR}/modify_settings"
  MANAGED_FILE="${TEST_TMPDIR}/managed.json"
  OUTPUT_FILE="${TEST_TMPDIR}/output.json"
  # Never read or write the real ownership file under ~/.local/state.
  export CLAUDE_SETTINGS_OWNERSHIP="${TEST_TMPDIR}/no-ownership.json"

  chezmoi_execute_template --source "${REPO_ROOT}" <"${TEMPLATE_PATH}" >"${RENDERED_SCRIPT}"
  chmod +x "${RENDERED_SCRIPT}"
  "${RENDERED_SCRIPT}" </dev/null >"${MANAGED_FILE}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

run_modify() {
  run bash -c '"${0}" <"${1}" >"${2}"' "${RENDERED_SCRIPT}" "${1}" "${OUTPUT_FILE}"
  [[ "${status}" -eq 0 ]]
}

# Live file shaped like `moshi-hook install --target claude` output on top of the managed one.
write_moshi_live() {
  jq '
    .model = "opus"
    | .env.CLAUDE_CODE_PLUGIN_DIRS = "/home/u/.config/claude/moshi-plugin"
    | .hooks.Notification += [{"hooks": [{"async": true, "command": "'"'"'/opt/homebrew/bin/moshi-hook'"'"' claude-hook", "type": "command"}], "matcher": "permission_prompt"}]
    | .hooks.Stop = [{"hooks": [{"async": true, "command": "'"'"'/opt/homebrew/bin/moshi-hook'"'"' claude-hook", "type": "command"}]}]
  ' "${MANAGED_FILE}" >"${1}"
}

@test "GIVEN empty stdin EXPECT valid managed settings" {
  run jq -e '.statusLine.type == "command" and .includeCoAuthoredBy == false' "${MANAGED_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN invalid json EXPECT failure without output" {
  input_file="${TEST_TMPDIR}/input.json"
  printf '%s\n' "not-json" >"${input_file}"

  run bash -c '"${0}" <"${1}" >"${2}"' "${RENDERED_SCRIPT}" "${input_file}" "${OUTPUT_FILE}"

  [[ "${status}" -ne 0 ]]
  [[ ! -s "${OUTPUT_FILE}" ]]
}

@test "GIVEN existing settings and no jq EXPECT failure without output" {
  input_file="${TEST_TMPDIR}/input.json"
  write_moshi_live "${input_file}"
  no_jq_bin="${TEST_TMPDIR}/no-jq-bin"
  mkdir -p "${no_jq_bin}"
  for tool in bash cat mktemp rm; do
    ln -s "$(command -v "${tool}")" "${no_jq_bin}/${tool}"
  done

  run env PATH="${no_jq_bin}" bash -c '"${0}" <"${1}" >"${2}"' "${RENDERED_SCRIPT}" "${input_file}" "${OUTPUT_FILE}"

  [[ "${status}" -ne 0 ]]
  [[ ! -s "${OUTPUT_FILE}" ]]
}

@test "GIVEN empty stdin and no jq EXPECT managed settings" {
  no_jq_bin="${TEST_TMPDIR}/no-jq-bin"
  mkdir -p "${no_jq_bin}"
  for tool in bash cat mktemp rm; do
    ln -s "$(command -v "${tool}")" "${no_jq_bin}/${tool}"
  done

  run env PATH="${no_jq_bin}" bash -c '"${0}" </dev/null >"${1}"' "${RENDERED_SCRIPT}" "${OUTPUT_FILE}"

  [[ "${status}" -eq 0 ]]
  cmp "${OUTPUT_FILE}" "${MANAGED_FILE}"
}

@test "GIVEN only reordered keys EXPECT live file passed through byte for byte" {
  input_file="${TEST_TMPDIR}/input.json"
  jq --sort-keys --indent 4 . "${MANAGED_FILE}" >"${input_file}"

  run_modify "${input_file}"

  cmp "${OUTPUT_FILE}" "${input_file}"
}

@test "GIVEN moshi-hook entries and model EXPECT them kept unchanged" {
  input_file="${TEST_TMPDIR}/input.json"
  write_moshi_live "${input_file}"

  run_modify "${input_file}"

  cmp "${OUTPUT_FILE}" "${input_file}"
}

@test "GIVEN moshi-hook entries and stale managed keys EXPECT managed keys restored and moshi kept" {
  input_file="${TEST_TMPDIR}/input.json"
  write_moshi_live "${TEST_TMPDIR}/moshi.json"
  jq '
    .includeCoAuthoredBy = true
    | .permissions.deny = ["stale"]
    | .env.DISABLE_TELEMETRY = "0"
    | del(.hooks.Notification[0])
  ' "${TEST_TMPDIR}/moshi.json" >"${input_file}"

  run_modify "${input_file}"

  run jq -e --slurpfile want "${TEST_TMPDIR}/moshi.json" '. == $want[0]' "${OUTPUT_FILE}"
  [[ "${status}" -eq 0 ]]
  run jq -e '.hooks.Notification[0].matcher == "" and .hooks.Notification[1].matcher == "permission_prompt"' "${OUTPUT_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN entries retired from the template since last apply EXPECT them removed and third-party kept" {
  export CLAUDE_SETTINGS_OWNERSHIP="${TEST_TMPDIR}/owned.json"
  retired_hook='{"hooks": [{"command": "retired-hook", "type": "command"}]}'
  jq -n --argjson g "${retired_hook}" '{
    keys: {"[\"enabledPlugins\",\"retired@market\"]": [true], "[\"env\",\"RETIRED_VAR\"]": ["1"]},
    hooks: {Stop: [$g]}
  }' >"${CLAUDE_SETTINGS_OWNERSHIP}"
  input_file="${TEST_TMPDIR}/input.json"
  write_moshi_live "${TEST_TMPDIR}/moshi.json"
  jq --argjson g "${retired_hook}" '
    .enabledPlugins["retired@market"] = true
    | .env.RETIRED_VAR = "1"
    | .hooks.Stop = [$g] + .hooks.Stop
  ' "${TEST_TMPDIR}/moshi.json" >"${input_file}"

  run_modify "${input_file}"

  run jq -e --slurpfile want "${TEST_TMPDIR}/moshi.json" '. == $want[0]' "${OUTPUT_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN retired entry edited locally since last apply EXPECT local value kept" {
  export CLAUDE_SETTINGS_OWNERSHIP="${TEST_TMPDIR}/owned.json"
  printf '%s\n' '{"keys": {"[\"env\",\"RETIRED_VAR\"]": ["1"]}, "hooks": {}}' >"${CLAUDE_SETTINGS_OWNERSHIP}"
  input_file="${TEST_TMPDIR}/input.json"
  jq '.env.RETIRED_VAR = "2"' "${MANAGED_FILE}" >"${input_file}"

  run_modify "${input_file}"

  run jq -e '.env.RETIRED_VAR == "2"' "${OUTPUT_FILE}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN targeted apply without lifecycle scripts EXPECT managed entries recorded as owned" {
  export CLAUDE_SETTINGS_OWNERSHIP="${TEST_TMPDIR}/state/chezmoi/owned.json"
  export CHEZMOI_COMMAND="apply"
  export CHEZMOI_ARGS="chezmoi apply ${HOME}/.config/claude/settings.json"
  input_file="${TEST_TMPDIR}/input.json"
  write_moshi_live "${input_file}"

  run_modify "${input_file}"

  run jq -e --slurpfile m "${MANAGED_FILE}" '
    (.keys["[\"statusLine\",\"type\"]"] | index("command")) != null
    and (.hooks.Notification | index($m[0].hooks.Notification)) != null
    and ([.hooks[][].hooks[]?.command | strings] | any(test("moshi-hook")) | not)
  ' "${CLAUDE_SETTINGS_OWNERSHIP}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN diff or dry-run apply EXPECT no ownership recorded" {
  input_file="${TEST_TMPDIR}/input.json"
  cp "${MANAGED_FILE}" "${input_file}"

  for invocation in "diff:chezmoi diff" "apply:chezmoi apply --dry-run" "apply:chezmoi apply -nv" "status:chezmoi status"; do
    export CLAUDE_SETTINGS_OWNERSHIP="${TEST_TMPDIR}/owned-${RANDOM}.json"
    export CHEZMOI_COMMAND="${invocation%%:*}"
    export CHEZMOI_ARGS="${invocation#*:}"

    run_modify "${input_file}"

    [[ ! -e "${CLAUDE_SETTINGS_OWNERSHIP}" ]]
  done
}

@test "GIVEN ownership lock held by another run EXPECT settings still merged and ledger untouched" {
  export CLAUDE_SETTINGS_OWNERSHIP="${TEST_TMPDIR}/owned.json"
  export CHEZMOI_COMMAND="apply"
  export CHEZMOI_ARGS="chezmoi apply"
  mkdir "${CLAUDE_SETTINGS_OWNERSHIP}.lock"
  input_file="${TEST_TMPDIR}/input.json"
  cp "${MANAGED_FILE}" "${input_file}"

  run_modify "${input_file}"

  cmp "${OUTPUT_FILE}" "${input_file}"
  [[ ! -e "${CLAUDE_SETTINGS_OWNERSHIP}" ]]
  [[ -z "$(find "${TEST_TMPDIR}" -name '.claude-settings.owned.*')" ]]
}

@test "GIVEN ownership from an earlier run EXPECT it kept when the template drops entries" {
  export CLAUDE_SETTINGS_OWNERSHIP="${TEST_TMPDIR}/owned.json"
  export CHEZMOI_COMMAND="apply"
  export CHEZMOI_ARGS="chezmoi apply"
  printf '%s\n' '{"keys": {"[\"env\",\"RETIRED_VAR\"]": ["1"]}, "hooks": {}}' >"${CLAUDE_SETTINGS_OWNERSHIP}"
  input_file="${TEST_TMPDIR}/input.json"
  cp "${MANAGED_FILE}" "${input_file}"

  run_modify "${input_file}"
  run_modify "${input_file}"

  run jq -e '.keys["[\"env\",\"RETIRED_VAR\"]"] == ["1"]' "${CLAUDE_SETTINGS_OWNERSHIP}"
  [[ "${status}" -eq 0 ]]
}

@test "GIVEN live already holds managed hook groups EXPECT no duplicates" {
  input_file="${TEST_TMPDIR}/input.json"
  write_moshi_live "${input_file}"

  run_modify "${input_file}"

  run jq -e '(.hooks.Notification | length) == 2 and (.hooks.Stop | length) == 1' "${OUTPUT_FILE}"
  [[ "${status}" -eq 0 ]]
}
