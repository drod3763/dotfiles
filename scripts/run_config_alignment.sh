#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ignore_file="${repo_root}/scripts/config_alignment.ignore"

declare -a ignore_args=()
while IFS= read -r pattern || [[ -n "${pattern}" ]]; do
  [[ -z "${pattern}" || "${pattern}" == \#* ]] && continue
  ignore_args+=(--ignore "${pattern}")
done < "${ignore_file}"

python3 "${repo_root}/scripts/config_alignment.py" \
  --repo-root "${repo_root}" \
  --output-dir "${repo_root}/tmp/config-alignment" \
  "${ignore_args[@]}" \
  --machine-specific '*/.claude.json*' \
  --machine-specific '*/history*' \
  --machine-specific '*/state*' \
  --machine-specific '*/session*' \
  --machine-specific '*/recent*' \
  --sensitive 'aws/*' \
  --sensitive '*/credentials*' \
  --sensitive '*/id_*' \
  --sensitive 'gh/hosts.yml' \
  --omit-from-report 'tealdeer/cache/**' \
  --omit-from-report 'zed/**/*.tmp' \
  "$@"
