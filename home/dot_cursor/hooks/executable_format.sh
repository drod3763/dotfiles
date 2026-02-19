#!/bin/bash
# Secrets hide in code
# Like shadows in the moonlight
# This hook finds them all
# redact-secrets.sh - Hook script that checks for GitHub API keys in file content
# This script implements a file content validation hook from the Cursor Hooks Spec
# Initialize debug logging
echo "Redact-secrets hook execution started" >> /tmp/hooks.log
# Read JSON input from stdin
input=$(cat)
echo "Received input: $input" >> /tmp/hooks.log

# Parse the file path and content from the JSON input
filePath=$(echo "$input" | jq -r '.filePath // empty')

echo "Parsed file path: '$filePath'" >> ~/hooks.log