#!/bin/sh

set -e # -e: exit on error

# Check and install Xcode Command Line Tools on macOS
if [ "$(uname)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..." >&2
  xcode-select --install
  echo "Please complete the Xcode installation, then press Enter to continue..."
  read -r
fi

# Configure Git if not configured
if [ ! "$(git config --global user.name)" ] || [ ! "$(git config --global user.email)" ]; then
  echo "Git user.name and user.email not configured." >&2
  echo "Please set them now:" >&2
  read -p "Enter your Git user name: " git_name
  read -p "Enter your Git user email: " git_email
  git config --global user.name "$git_name"
  git config --global user.email "$git_email"
  echo "Git configuration updated." >&2
fi

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