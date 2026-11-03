## Why

Several apps and tools are no longer used: brave-browser, cmux, conductor, the ghostty cask, gitkraken, hammerspoon, herdr, herdr-server, opencode and borders. Their package catalog entries are already gone, but the configs, lifecycle scripts, LaunchAgent and tests that supported them remain. Without a package entry, a config path is no longer listed as inactive, so chezmoi now applies those leftovers to every machine, including a KeepAlive LaunchAgent that points at an app brew is about to zap.

## What Changes

- Remove the package catalog entries for the apps and tools above (already done in the working tree).
- Unload retired LaunchAgents (`local.herdr-server`, the borders brew service and a leftover herdr-mx brew service) on every machine before `brew bundle cleanup --zap` removes their programs.
- Remove the herdr-server machinery: LaunchAgent plist, `herdr-server-ctl`, the `98b` configure script and their tests.
- Remove the herdr Claude Code hook and its `SessionStart` entry.
- Remove opencode configs, the `96` MCP sync script and test, the Zed `OpenCode` agent server and the repo's `.opencode/` directory.
- Remove borders, its `felixkratz/formulae` tap and `bordersrc`, and the `anomalyco/tap` tap that only opencode used.
- Remove the hammerspoon config, its Spoon externals and the `98a` `defaults write` block.
- Remove the stale `com.mitchellh.ghostty/config.backup`.
- Keep `~/.config/ghostty`: libghostty-based apps read it. It now applies on every machine.
- Delete previously managed files from `$HOME` via `.chezmoiremove`.
- **BREAKING**: the next apply uninstalls these apps with `--zap`, which also deletes their app data (e.g. Brave profiles, GitKraken settings).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `work-config`: OpenCode drops out of the work AI tooling and common CLI tool lists; the ghostty scenario changes from "installed as the primary terminal" to "config retained for libghostty apps".

## Impact

- Affected domains: shell manifest/package catalog, package installation (brew zap), macOS lifecycle scripts, LaunchAgents, Claude Code settings, Zed settings, external resources, formatter config, tests.
- Rendered files: `~/Library/LaunchAgents/local.herdr-server.plist`, `~/.local/bin/herdr-server-ctl`, `~/.config/opencode/`, `~/.config/hammerspoon/` and `~/.config/claude/hooks/herdr-agent-state.sh` are removed; `~/.config/claude/settings.json` and Zed settings change.
- Profiles: applies to personal and work machines; herdr, herdr-server and hammerspoon were `common`.
- Non-goals: no change to package catalog or shell manifest rendering logic; no fix for the 2 bats failures that predate this change (`install.sh.bats:291`, `claude_code_manifest.bats:58`); hunk stays.
