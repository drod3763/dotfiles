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

@test "GIVEN live already holds managed hook groups EXPECT no duplicates" {
  input_file="${TEST_TMPDIR}/input.json"
  write_moshi_live "${input_file}"

  run_modify "${input_file}"

  run jq -e '(.hooks.Notification | length) == 2 and (.hooks.Stop | length) == 1' "${OUTPUT_FILE}"
  [[ "${status}" -eq 0 ]]
}
