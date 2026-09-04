#!/usr/bin/env bash
set -euo pipefail

sudo_keepalive_pid=""
cleanup() {
  if [ -n "${sudo_keepalive_pid}" ]; then
    kill "${sudo_keepalive_pid}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [ "$(uname)" = "Darwin" ]; then
  echo "Requesting administrator privileges..." >&2
  sudo -v
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
  sudo_keepalive_pid=$!
fi

if [ "$(uname)" = "Darwin" ]; then
  tcc_db="${HOME}/Library/Application Support/com.apple.TCC/TCC.db"
  if sqlite3_bin="$(command -v sqlite3 2>/dev/null)" && ! "${sqlite3_bin}" "${tcc_db}" 'SELECT 1;' >/dev/null 2>&1; then
    echo "Full Disk Access is required for the terminal running install.sh." >&2
    echo "Grant it in System Settings > Privacy & Security > Full Disk Access, then re-run install.sh." >&2
    exit 1
  fi
fi

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

# Install Rosetta 2 on Apple Silicon when it is not already available.
if [ "$(uname)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
  echo "Installing Rosetta 2..." >&2
  sudo softwareupdate --install-rosetta --agree-to-license
fi

# Configure Git with placeholder values if not configured
has_git_name=1
has_git_email=1

git config --global user.name >/dev/null 2>&1 || has_git_name=0
git config --global user.email >/dev/null 2>&1 || has_git_email=0

if [[ ${has_git_name} -eq 0 || ${has_git_email} -eq 0 ]]; then
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
    if brew_shellenv="$(/opt/homebrew/bin/brew shellenv)"; then
      eval "${brew_shellenv}"
    fi
  else
    if brew_shellenv="$(/usr/local/bin/brew shellenv)"; then
      eval "${brew_shellenv}"
    fi
  fi
  echo "Homebrew installed and added to PATH." >&2
fi

# Install chezmoi if not present
if ! command -v chezmoi >/dev/null 2>&1; then
  bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"
  curl -fsSL https://git.io/chezmoi | sh -s -- -b "$bin_dir"
  export PATH="$bin_dir:$PATH"
fi

# Get script directory - handle both downloaded and curl execution
if [[ -f $0 ]]; then
  script_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
  chezmoi init --source="$script_dir"
else
  chezmoi init drod3763
fi

# Determine verbosity
verbose_flag=""
if [[ ${VERBOSE:-} == "1" || ${VERBOSE:-} == "true" ]]; then
  verbose_flag="--verbose"
fi

# Check for verbose flag in arguments
for arg in "$@"; do
  if [[ $arg == "-v" || $arg == "--verbose" ]]; then
    verbose_flag="--verbose"
    break
  fi
done

# Force template re-evaluation and refresh externals to avoid stale cache
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -dim chezmoi apply --force --refresh-externals $verbose_flag
else
  chezmoi apply --force --refresh-externals $verbose_flag
fi

# Switch source repo remote to SSH for future pushes (keys now provisioned)
if git -C "${HOME}/.local/share/chezmoi" remote get-url origin 2>/dev/null | grep -q '^https://github.com/drod3763/'; then
  git -C "${HOME}/.local/share/chezmoi" remote set-url origin git@github.com:drod3763/dotfiles.git
fi
