#!/bin/bash
# Combined statusline: caveman badge + ccusage

CAVEMAN_SCRIPT="$HOME/.config/claude/plugins/marketplaces/caveman/hooks/caveman-statusline.sh"
CAVEMAN=""
if [ -f "$CAVEMAN_SCRIPT" ]; then
  CAVEMAN=$(bash "$CAVEMAN_SCRIPT" 2>/dev/null)
fi

CCUSAGE=$(bun x ccusage statusline 2>/dev/null)

if [ -n "$CAVEMAN" ] && [ -n "$CCUSAGE" ]; then
  printf '%s\n%s' "$CAVEMAN" "$CCUSAGE"
elif [ -n "$CAVEMAN" ]; then
  printf '%s' "$CAVEMAN"
else
  printf '%s' "$CCUSAGE"
fi
