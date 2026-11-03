## Context

The package catalog entries for brave-browser, cmux, conductor, ghostty, gitkraken, hammerspoon (`home/.chezmoidata/shell_manifest/apps/`), herdr, herdr-server and opencode (`home/.chezmoidata/shell_manifest/tool/`) are already deleted in the working tree. The package catalog resolver adds a package's `config_file_locations` to `.chezmoiignore` only while that package is listed and not selected. A deleted package lists nothing, so its config sources are now applied unconditionally:

- `home/private_Library/LaunchAgents/local.herdr-server.plist.tmpl`: a KeepAlive agent that runs `/Applications/Herdr Server.app/.../herdr-server-launcher`. It is loaded and running on this Mac and on personal machines.
- `home/dot_local/bin/executable_herdr-server-ctl` and `home/.chezmoiscripts/macOS/run_onchange_after_98b_configure-herdr-service.sh.tmpl` (gated on `lookPath "herdr"`).
- `home/private_dot_config/opencode/`, `home/private_dot_config/hammerspoon/`, `home/private_dot_config/ghostty/`.

Other leftovers are not tied to the catalog:

- `home/private_dot_config/claude/hooks/executable_herdr-agent-state.sh` and its `SessionStart` entry in `home/private_dot_config/claude/settings.json.tmpl`.
- `run_once_after_96_sync-opencode-mcp.sh.tmpl`, the Zed `agent_servers.OpenCode` entry and the repo's `.opencode/`.
- The hammerspoon Spoons in `home/.chezmoiexternal.toml.tmpl` and the `defaults write` block in `run_onchange_after_98a_configure-brew-apps.sh.tmpl`.
- Lines in `home/treefmt.toml` and `scripts/config_alignment.ignore`.

`run_onchange_before_install-packages.sh.tmpl` runs `brew bundle cleanup --force --zap`, which will uninstall every removed package and trash its zap paths on the next apply.

## Goals / Non-Goals

**Goals:**

- Unload the herdr-server LaunchAgent on every machine before its app is zapped.
- Remove every source file, template block, test and formatter or ignore entry that exists only for the removed tools.
- Delete previously rendered copies from `$HOME`.
- Keep `~/.config/ghostty` for libghostty apps.

**Non-Goals:**

- Changing the package catalog resolver or making config gating survive package deletion.
- Fixing the bats failures that predate this change (`install.sh.bats:291`, `claude_code_manifest.bats:58`).
- Preserving app data that `--zap` deletes. That is a manual backup step before apply.

## Decisions

**Unload retired agents from a `run_once_before_91_unload-retired-agents` script.** chezmoi orders scripts by target name, so `91_…` runs after `90_bootstrap-age-identities` and before `install-packages`, and the agent stops before brew trashes the app. For each of `local.herdr-server`, `homebrew.mxcl.borders` and `homebrew.mxcl.herdr-mx`, the script calls `launchctl bootout` only when `launchctl print` succeeds, and stays quiet otherwise. That makes it a no-op on machines that never had herdr. Alternatives:

- Manual `launchctl bootout` on each machine: rejected, because herdr-server was `common`, so it's on several machines.
- Keep the `98b` script in teardown form: rejected. It is an `after` script, so it runs after the zap, and it's gated on `herdr`, which brew has just removed.

**Remove rendered files with `.chezmoiremove`.** chezmoi does not delete targets whose source disappeared, and `home/.chezmoiremove` already handles retired files. Add `.config/opencode`, `.config/hammerspoon`, `.local/bin/herdr-server-ctl`, `Library/LaunchAgents/local.herdr-server.plist` and `.config/claude/hooks/herdr-agent-state.sh`. chezmoi removes files before running `after` scripts and after `before` scripts, so the plist goes once the agent has been unloaded. The `.config/opencode` and `.config/hammerspoon` entries remove the whole directory, including app-written state, which is intended. Alternative: a one-off `rm` script. Rejected, because `.chezmoiremove` is already how this repo retires files.

**Keep the ghostty config, drop `config.backup`.** `~/.config/ghostty` is read by libghostty apps, so leaving it unconditionally applied is the intended state. `Application Support/com.mitchellh.ghostty/config.backup` sits in Ghostty.app's own folder and nothing reads it.

**Drop the `SessionStart` hook block entirely.** It holds only the herdr hook. The empty `Notification` hooks entry is left as it is.

**Delete `.opencode/`.** Its opsx commands and skills only run under opencode. The same workflows exist under `.claude/`.

## Risks / Trade-offs

- [`--zap` deletes app data: Brave profiles, GitKraken settings, Hammerspoon and conductor state] → Call it out in the proposal, and back up or uninstall without `--zap` before the first apply.
- [Zapping the ghostty cask trashes `~/.config/ghostty`] → `before` scripts run before chezmoi writes targets, so the same apply re-renders it. Confirm after apply.
- [The bootout runs while you are inside a herdr pane, so the pane closes] → Apply from a shell outside herdr.
- [`run_once` will not re-run on a machine where it already ran but the agent was later reloaded] → Acceptable, because the plist source is deleted, so nothing reloads it.
- [Stale `homebrew.mxcl.herdr-mx` brew service left loaded after the herdr-mx fork was dropped] → The unload script boots it out and `.chezmoiremove` deletes its plist; `brew uninstall` alone leaves both behind.
