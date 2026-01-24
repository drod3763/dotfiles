## 1. Review and Confirm Additions

- [x] 1.1 Review new brew additions - confirm all are intentional (not temporary installs)
- [x] 1.2 Review new cask additions - confirm all are intentional
- [x] 1.3 Decide on removals (iterm2, rio, heynote, superkey, lastpass, lastpass-cli) - CONFIRMED
- [x] 1.4 Confirm `dotnet` vs `dotnet@8` versioning strategy - using dotnet@8

## 2. Update Homebrew Taps

- [x] 2.1 Add `felixkratz/formulae` tap (sketchybar/borders)
- [x] 2.2 Add `nikitabobko/tap` tap (aerospace)
- [x] 2.3 Add `oven-sh/bun` tap (bun runtime)
- [x] 2.4 Add `playlist-tech/tap` tap (pipemind)
- [x] 2.5 Add `waydabber/betterdisplay` tap (betterdisplay)
- [x] 2.6 Add `ynqa/tap` tap (jnv)

## 3. Update Package Script

- [x] 3.1 Add new common brews to the shared `$brews` list
- [x] 3.2 Add new work-only brews to the `{{ if not .personal }}` section
- [x] 3.3 Add new common casks to the shared `$casks` list
- [x] 3.4 Add new work-only casks to the `{{ if not .personal }}` section
- [x] 3.5 Remove deprecated packages from config (after confirmation)

## 4. Update Exports

- [x] 4.1 Add `OPENSPEC_TELEMETRY=0` to exports template

## 4a. Add Claude Code Config Files

- [x] 4a.1 Add `~/.config/claude/settings.json` to chezmoi

## 5. Common vs Work-Only Classification

### Brews to Add to Common List
- `gh` - GitHub CLI (useful everywhere)
- `go` - Go language (useful everywhere)
- `jq` - JSON processor (useful everywhere)
- `yq` - YAML processor (useful everywhere)
- `age-plugin-yubikey` - YubiKey age plugin (useful with YubiKey)
- `glow` - Markdown renderer
- `pandoc` - Document converter
- `pipx` - Python app installer
- `uv` - Python package manager
- `yazi` - File manager
- `treefmt` - Multi-language formatter

### Brews to Add to Work-Only
- `act` - GitHub Actions local runner
- `actionlint` - GitHub Actions linter
- `azure-cli` - Azure CLI
- `bun` - JavaScript runtime
- `codex` - OpenAI Codex CLI
- `deno` - JavaScript runtime
- `dotnet@8` - .NET SDK (replace `dotnet`)
- `gdu` - Disk usage analyzer
- `gemini-cli` - Google Gemini CLI
- `jnv` - JSON navigator
- `mermaid-cli` - Diagram generator
- `nushell` - Modern shell
- `okta-aws-cli` - Okta AWS integration
- `opencode` - OpenCode CLI
- `pipemind` - AI coding assistant
- `pulumi` - Infrastructure as code
- `selenium-server` - Selenium testing
- `sleepwatcher` - Sleep/wake scripts
- `sops` - Secret encryption
- `volta` - JavaScript toolchain

### Casks to Add to Common List
- `ghostty` - GPU terminal (could replace iterm2)
- `vlc` - Media player

### Casks to Add to Work-Only
- `aerospace` - Tiling window manager
- `affinity` - Design apps
- `antigravity` - AI coding assistant
- `betterdisplay` - Display manager
- `bruno` - API client
- `chrysalis` - Keyboard config
- `claude` - Claude desktop
- `claude-code` - Claude Code
- `cursor` - AI code editor
- `devtoys` - Developer utilities
- `discord` - Chat app
- `docker-desktop` - Docker Desktop
- `elgato-stream-deck` - Stream Deck software
- `gitkraken` - Git GUI
- `hammerspoon` - macOS automation
- `homerow` - Keyboard navigation
- `jetbrains-toolbox` - JetBrains IDE manager
- `logitech-options` - Logitech software
- `mac-mouse-fix` - Mouse enhancement
- `marvin` - Task management
- `mouseless` - Keyboard navigation
- `notion` - Note-taking
- `powershell` - PowerShell
- `yubico-yubikey-manager` - YubiKey GUI
- `zen` - Zen Browser

## 6. Testing and Validation

- [x] 6.1 Validate all taps exist (`brew tap-info <tap>`)
- [x] 6.2 Validate all new formulas exist (`brew info <formula>`)
- [x] 6.3 Validate all new casks exist (`brew info --cask <cask>`)
- [x] 6.4 Run `chezmoi diff` to verify template changes
- [x] 6.5 Run `chezmoi apply --dry-run` to test
- [x] 6.6 Run `chezmoi doctor` to check for issues
- [ ] 6.7 Verify on work machine with `brew bundle check`

## 7. Cleanup

- [x] 7.1 Remove any packages confirmed as no longer needed
- [x] 7.2 Update `$args` dict if new packages need special flags
