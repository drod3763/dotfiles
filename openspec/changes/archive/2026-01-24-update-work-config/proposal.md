# Change: Update Work Machine Configuration

## Why
The work machine (hostname `P6H9DQX16L`) has accumulated many useful tools and applications that are not tracked in the chezmoi configuration. This creates drift between the actual state and the managed state, making it difficult to replicate the environment on a new work machine.

## What Changes

### Homebrew Formulae Additions (Work-only)
New developer tools to add to work configuration:
- **AI/LLM Tools:** `codex`, `gemini-cli`, `opencode`, `pipemind`
- **Cloud/DevOps:** `azure-cli`, `okta-aws-cli`, `pulumi`, `sops`
- **JavaScript/Node:** `bun`, `deno`, `volta`
- **Python:** `pipx`, `uv`
- **Languages:** `go`
- **CLI Utilities:** `act`, `actionlint`, `gh`, `gdu`, `glow`, `jnv`, `jq`, `mermaid-cli`, `nushell`, `pandoc`, `treefmt`, `yazi`, `yq`
- **Security:** `age-plugin-yubikey`
- **System:** `sleepwatcher`
- **Testing:** `selenium-server`

### Homebrew Cask Additions (Work-only)
New applications to add to work configuration:
- **AI/Coding:** `antigravity`, `claude`, `claude-code`, `cursor`
- **Development:** `bruno`, `devtoys`, `gitkraken`, `jetbrains-toolbox`, `powershell`
- **Window Management:** `aerospace`, `homerow`, `mouseless@preview`
- **Productivity:** `notion`, `marvin`, `betterdisplay`, `hammerspoon`, `mac-mouse-fix`
- **Hardware:** `chrysalis`, `elgato-stream-deck`, `logitech-options`, `yubico-yubikey-manager`
- **Terminals:** `ghostty`
- **Media:** `vlc`
- **Browsers:** `zen`
- **Design:** `affinity`
- **Communication:** `discord`

### Homebrew Taps Additions (Work-only)
New taps required for work-only formulae:
- `felixkratz/formulae` - sketchybar/borders
- `nikitabobko/tap` - aerospace window manager
- `oven-sh/bun` - bun JavaScript runtime
- `playlist-tech/tap` - pipemind AI assistant
- `waydabber/betterdisplay` - betterdisplay
- `ynqa/tap` - jnv JSON navigator

### Environment Exports
Add to exports template:
- `OPENSPEC_TELEMETRY=0` - disable openspec telemetry

### New Config Files (Work-only)
Add Claude Code CLI configuration:
- `~/.config/claude/settings.json` - Claude Code settings (telemetry, hooks, status line)

### Configuration Updates
- Update `dotnet` to `dotnet@8` (version pinning)
- Add docker-related tools: `docker-compose`, `docker-desktop` cask

### Removals
- `iterm2` - replaced by ghostty
- `rio` - replaced by ghostty
- `heynote` - no longer used
- `superkey` - replaced by homerow/aerospace
- `lastpass` - no longer used
- `lastpass-cli` - no longer used

## Impact
- Affected files:
  - `home/.chezmoiscripts/macOS/run_onchange_before_install-packages.sh.tmpl`
  - `home/.chezmoitemplates/exports.tmpl`
  - `home/private_dot_config/claude/settings.json` (new)
- Scope: Work machine only (guarded by `{{ if not .personal }}`)
- Risk: Low - additive changes only, no breaking changes

## Validation
- Validate taps exist with `brew tap-info <tap>`
- Validate formulas exist with `brew info <formula>`
- Validate casks exist with `brew info --cask <cask>`
- Run `chezmoi diff` to verify template changes
- Run `chezmoi apply --dry-run` to test application
- Run `chezmoi doctor` to check for issues
- Verify with `brew bundle check` on work machine
