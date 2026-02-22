#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

if ! command -v bats >/dev/null 2>&1; then
	echo "bats is required to run shell tests. Install bats-core first." >&2
	exit 1
fi

bats -r "${repo_root}/tests/bats"
