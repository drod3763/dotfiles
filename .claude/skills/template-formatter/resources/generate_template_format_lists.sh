#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
tmp_dir="${repo_root}/tmp"

render_only_out="${tmp_dir}/templated_format_render_only.txt"
source_safe_out="${tmp_dir}/templated_format_source_safe.txt"
all_candidates_out="${tmp_dir}/templated_files_format_candidates.txt"

mkdir -p "${tmp_dir}"

all_tmpl="$(cd "${repo_root}" && git ls-files "**/*.tmpl")"

candidates_tmp="$(mktemp)"
source_safe_tmp="$(mktemp)"
render_only_tmp="$(mktemp)"
trap 'rm -f "${candidates_tmp}" "${source_safe_tmp}" "${render_only_tmp}"' EXIT

while IFS= read -r path; do
	[[ -n "${path}" ]] || continue
	case "${path}" in
	home/.chezmoiscripts/*) continue ;;
	home/.chezmoitemplates/*) continue ;;
	*.age.tmpl) continue ;;
	*license*.tmpl | *.lic.tmpl | *.key.tmpl | *.dat.tmpl) continue ;;
	esac
	printf '%s\n' "${path}" >>"${candidates_tmp}"
done <<<"${all_tmpl}"

declare -a source_safe=(
	"home/private_dot_config/claude/symlink_ide.tmpl"
)

for path in "${source_safe[@]}"; do
	printf '%s\n' "${path}" >>"${source_safe_tmp}"
done

while IFS= read -r path; do
	[[ -n "${path}" ]] || continue
	if grep -Fxq "${path}" "${source_safe_tmp}"; then
		continue
	fi
	printf '%s\n' "${path}" >>"${render_only_tmp}"
done <"${candidates_tmp}"

sort "${candidates_tmp}" >"${all_candidates_out}"
sort "${source_safe_tmp}" >"${source_safe_out}"
sort "${render_only_tmp}" >"${render_only_out}"

printf 'Wrote %s (%d entries)\n' "${all_candidates_out}" "$(wc -l <"${all_candidates_out}")"
printf 'Wrote %s (%d entries)\n' "${source_safe_out}" "$(wc -l <"${source_safe_out}")"
printf 'Wrote %s (%d entries)\n' "${render_only_out}" "$(wc -l <"${render_only_out}")"
