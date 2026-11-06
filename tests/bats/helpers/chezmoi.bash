CHEZMOI_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Renders read 1Password through the fake `op` in helpers/bin: real `op` needs app approval,
# hits the network and can spawn a daemon that inherits bats' pipes and hangs the suite.
chezmoi_execute_template() {
  PATH="${CHEZMOI_HELPERS_DIR}/bin:${PATH}" "${REAL_CHEZMOI_BIN:-chezmoi}" execute-template "$@"
}
