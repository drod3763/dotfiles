#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

if ! command -v chezmoi >/dev/null 2>&1; then
	echo "chezmoi is required to render script templates." >&2
	exit 1
fi

if ! command -v shellcheck >/dev/null 2>&1; then
	echo "shellcheck is required to lint rendered script templates." >&2
	exit 1
fi

declare -a candidates=()
check_all=0

if ! staged_paths="$(git diff --cached --name-only --diff-filter=ACMR)"; then
	echo "Failed to read staged files." >&2
	exit 1
fi

add_candidate() {
	local candidate="$1"
	local existing

	if [[ ${#candidates[@]} -gt 0 ]]; then
		for existing in "${candidates[@]}"; do
			if [[ "${existing}" == "${candidate}" ]]; then
				return
			fi
		done
	fi

	candidates+=("${candidate}")
}

while IFS= read -r path; do
	[[ -n "${path}" ]] || continue

	case "${path}" in
	home/.chezmoitemplates/*.tmpl)
		check_all=1
		;;
	home/.chezmoiscripts/*/*.tmpl)
		add_candidate "${path}"
		;;
	*) ;;
	esac
done <<<"${staged_paths}"

if [[ ${check_all} -eq 1 ]]; then
	if ! tracked_paths="$(git ls-files)"; then
		echo "Failed to list tracked files." >&2
		exit 1
	fi

	while IFS= read -r rel_path; do
		case "${rel_path}" in
		home/.chezmoiscripts/*/*.tmpl)
			add_candidate "${rel_path}"
			;;
		*) ;;
		esac
	done <<<"${tracked_paths}"
fi

if [[ ${#candidates[@]} -eq 0 ]]; then
	exit 0
fi

status=0
for template in "${candidates[@]}"; do
	src="${repo_root}/${template}"
	tmp="$(mktemp "${TMPDIR:-/tmp}/rendered-script.XXXXXX.sh")"

	if ! chezmoi execute-template <"${src}" >"${tmp}"; then
		echo "Failed to render template: ${template}" >&2
		rm -f "${tmp}"
		status=1
		continue
	fi

	if ! shellcheck "${tmp}"; then
		echo "ShellCheck failed for rendered template: ${template}" >&2
		status=1
	fi

	rm -f "${tmp}"
done

exit "${status}"
