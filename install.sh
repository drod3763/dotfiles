#!/usr/bin/env bash
set -euo pipefail

# Check and install Xcode Command Line Tools on macOS
if [ "$(uname)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..." >&2
  xcode-select --install
  echo "Please complete the Xcode installation, then press Enter to continue..."
  read -r
fi

# Wait for Xcode Command Line Tools to be available
if [ "$(uname)" = "Darwin" ] && ! command -v git >/dev/null 2>&1; then
  echo "Waiting for Xcode Command Line Tools to complete..." >&2
  while ! command -v git >/dev/null 2>&1; do
    sleep 2
  done
  echo "Xcode Command Line Tools are now available." >&2
fi

# Configure Git with placeholder values if not configured
if [ ! "$(git config --global user.name)" ] || [ ! "$(git config --global user.email)" ]; then
  echo "Setting placeholder Git configuration (will be replaced by chezmoi)..." >&2
  git config --global user.name "Temporary User"
  git config --global user.email "temp@example.com"
  echo "Git configuration set with placeholder values." >&2
fi

# Install Homebrew if not present
if [ "$(uname)" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..." >&2
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH for this session
  if [ "$(uname -m)" = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  echo "Homebrew installed and added to PATH." >&2
fi

# Install 1Password CLI if not present
if ! command -v op >/dev/null 2>&1; then
  echo "Installing 1Password CLI..." >&2
  brew install --cask 1password-cli
  echo "1Password CLI installed." >&2
fi

# Set up 1Password CLI service account token
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  echo "Enter 1Password service account token (or press Enter to skip):" >&2
  read -s -r op_token
  echo "" >&2
  if [ -n "$op_token" ]; then
    export OP_SERVICE_ACCOUNT_TOKEN="$op_token"
    echo "1Password service account token set." >&2
  else
    echo "Skipping 1Password service account setup." >&2
  fi
fi

# Install chezmoi if not present
if ! command -v chezmoi >/dev/null 2>&1; then
  bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"
  curl -fsSL https://git.io/chezmoi | sh -s -- -b "$bin_dir"
  export PATH="$bin_dir:$PATH"
fi

# Get script directory - handle both downloaded and curl execution
if [[ -f "$0" ]]; then
  script_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
  chezmoi init --source="$script_dir"
else
  chezmoi init drod3763
fi

# Force template re-evaluation and refresh externals to avoid stale cache
chezmoi apply --force --refresh-externals --verbose
