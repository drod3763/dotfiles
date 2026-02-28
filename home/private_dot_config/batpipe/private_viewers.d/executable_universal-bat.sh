#!/usr/bin/env bash

viewer_universal_bat_supports() {
	return 0
}

viewer_universal_bat_process() {
	local file_path="$1"
	local color_mode="never"

	if [[ "${BATPIPE_ENABLE_COLOR:-false}" == "true" ]]; then
		color_mode="always"
	fi

	if command -v bat >/dev/null 2>&1; then
		bat --paging=never --style=plain --color="${color_mode}" -- "${file_path}"
	else
		cat -- "${file_path}"
	fi
}

BATPIPE_VIEWERS+=("universal_bat")
