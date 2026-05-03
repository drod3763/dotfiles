#!/bin/zsh

set -euo pipefail

history_file="${ZDOTDIR:-$HOME/.config/zsh}/.zsh_history"
backup_file="${history_file}.bak"
pattern='OPENAI_API_KEY=|ANTHROPIC_API_KEY=|AWS_SECRET_ACCESS_KEY=|GITHUB_TOKEN=|HOMEBREW_GITHUB_API_TOKEN=|NEW_RELIC_API_KEY=|MINDBODY_CLIENT_SECRET=|[Aa][Pp][Ii][_-][Kk][Ee][Yy]=|[Aa][Pp][Ii][Kk][Ee][Yy]=|[Aa][Cc][Cc][Ee][Ss][Ss][_-][Tt][Oo][Kk][Ee][Nn]=|[Aa][Cc][Cc][Ee][Ss][Ss][Tt][Oo][Kk][Ee][Nn]=|[Rr][Ee][Ff][Rr][Ee][Ss][Hh][_-][Tt][Oo][Kk][Ee][Nn]=|[Rr][Ee][Ff][Rr][Ee][Ss][Hh][Tt][Oo][Kk][Ee][Nn]=|[Ss][Ee][Ss][Ss][Ii][Oo][Nn][_-][Tt][Oo][Kk][Ee][Nn]=|[Ss][Ee][Ss][Ss][Ii][Oo][Nn][Tt][Oo][Kk][Ee][Nn]=|[Ss][Ee][Cc][Rr][Ee][Tt][_-][Kk][Ee][Yy]=|[Ss][Ee][Cc][Rr][Ee][Tt][Kk][Ee][Yy]=|[Pp][Rr][Ii][Vv][Aa][Tt][Ee][_-][Kk][Ee][Yy]=|[Pp][Rr][Ii][Vv][Aa][Tt][Ee][Kk][Ee][Yy]=|[Cc][Ll][Ii][Ee][Nn][Tt][_-][Ii][Dd]=|[Cc][Ll][Ii][Ee][Nn][Tt][_-][Ss][Ee][Cc][Rr][Ee][Tt]=|[Cc][Ll][Ii][Ee][Nn][Tt][Ii][Dd]=|[Cc][Ll][Ii][Ee][Nn][Tt][Ss][Ee][Cc][Rr][Ee][Tt]=|"[Aa][Pp][Ii]_[Kk][Ee][Yy]"[[:space:]]*:[[:space:]]*|"[Aa][Pp][Ii][Kk][Ee][Yy]"[[:space:]]*:[[:space:]]*|"[Aa][Cc][Cc][Ee][Ss][Ss]_[Tt][Oo][Kk][Ee][Nn]"[[:space:]]*:[[:space:]]*|"[Aa][Cc][Cc][Ee][Ss][Ss][Tt][Oo][Kk][Ee][Nn]"[[:space:]]*:[[:space:]]*|"[Rr][Ee][Ff][Rr][Ee][Ss][Hh]_[Tt][Oo][Kk][Ee][Nn]"[[:space:]]*:[[:space:]]*|"[Rr][Ee][Ff][Rr][Ee][Ss][Hh][Tt][Oo][Kk][Ee][Nn]"[[:space:]]*:[[:space:]]*|"[Ss][Ee][Ss][Ss][Ii][Oo][Nn]_[Tt][Oo][Kk][Ee][Nn]"[[:space:]]*:[[:space:]]*|"[Ss][Ee][Ss][Ss][Ii][Oo][Nn][Tt][Oo][Kk][Ee][Nn]"[[:space:]]*:[[:space:]]*|"[Ss][Ee][Cc][Rr][Ee][Tt]_[Kk][Ee][Yy]"[[:space:]]*:[[:space:]]*|"[Ss][Ee][Cc][Rr][Ee][Tt][Kk][Ee][Yy]"[[:space:]]*:[[:space:]]*|"[Pp][Rr][Ii][Vv][Aa][Tt][Ee]_[Kk][Ee][Yy]"[[:space:]]*:[[:space:]]*|"[Pp][Rr][Ii][Vv][Aa][Tt][Ee][Kk][Ee][Yy]"[[:space:]]*:[[:space:]]*|"[Cc][Ll][Ii][Ee][Nn][Tt]_[Ii][Dd]"[[:space:]]*:[[:space:]]*|"[Cc][Ll][Ii][Ee][Nn][Tt]_[Ss][Ee][Cc][Rr][Ee][Tt]"[[:space:]]*:[[:space:]]*|"[Cc][Ll][Ii][Ee][Nn][Tt][Ii][Dd]"[[:space:]]*:[[:space:]]*|"[Cc][Ll][Ii][Ee][Nn][Tt][Ss][Ee][Cc][Rr][Ee][Tt]"[[:space:]]*:[[:space:]]*|[Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+[A-Za-z0-9._-]+|BEGIN[[:space:]]+(RSA[[:space:]]+)?PRIVATE[[:space:]]+KEY|BEGIN[[:space:]]+OPENSSH[[:space:]]+PRIVATE[[:space:]]+KEY|--password|--token|Authorization:[[:space:]]*Bearer|authorization:[[:space:]]*bearer|gh[[:space:]]+auth[[:space:]]+login.*--with-token|op[[:space:]]+item[[:space:]]+get|op[[:space:]]+read|aws[[:space:]]+configure[[:space:]]+set.*aws_secret_access_key|aws[[:space:]]+secretsmanager[[:space:]]+create-secret|aws[[:space:]]+secretsmanager[[:space:]]+put-secret-value|--secret-string|--secret-binary'

if [[ ! -f "${history_file}" ]]; then
  print -u2 "History file not found: ${history_file}"
  exit 1
fi

report_json="$(gitleaks detect --no-git --source "${history_file}" --report-format json --report-path - 2>/dev/null || true)"
gitleaks_lines="$(printf '%s' "${report_json}" | jq -r '.[].StartLine')"
pattern_lines="$(grep -nE "${pattern}" "${history_file}" | cut -d: -f1 || true)"
lines=(${(f)"$(printf '%s\n%s\n' "${gitleaks_lines}" "${pattern_lines}" | sed '/^$/d' | sort -rn | uniq)"})

if (( ${#lines[@]} == 0 )); then
  print "No matching history lines found in ${history_file}."
  exit 0
fi

print "Deleting ${history_file} lines:"
printf '  %s\n' "${lines[@]}"

cp "${history_file}" "${backup_file}"
awk 'NR==FNR { del[$1]=1; next } !del[FNR]' <(printf '%s\n' "${lines[@]}") "${backup_file}" > "${history_file}"
fc -R "${history_file}"
