#!/bin/sh

set -e # -e: exit on error

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

# Debug: Show Git version and location
echo "Git debugging info:" >&2
echo "Which git: $(which git)" >&2
echo "Git version: $(git --version)" >&2

if [ ! "$(command -v chezmoi)" ]; then
  bin_dir="$HOME/.local/bin"
  chezmoi="$bin_dir/chezmoi"
  if [ "$(command -v curl)" ]; then
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir"
  elif [ "$(command -v wget)" ]; then
    sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$bin_dir"
  else
    echo "To install chezmoi, you must have curl or wget installed." >&2
    exit 1
  fi
else
  chezmoi=chezmoi
fi

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
# exec: replace current process with chezmoi init
exec "$chezmoi" init --apply "--source=$script_dir"