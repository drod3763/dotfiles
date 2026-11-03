## 1. Package catalog (already in working tree)

- [x] 1.1 Delete `apps/{brave-browser,cmux,conductor,ghostty,gitkraken,hammerspoon}.toml` from `home/.chezmoidata/shell_manifest/`
- [x] 1.2 Delete `tool/herdr.toml` (herdr + herdr-server) and `tool/opencode.toml`
- [x] 1.3 Swap the `brave-browser` assertions in `run_onchange_before_install-packages.bats` for `bruno`; drop herdr tests and mock from `package_catalog_integration.bats`
- [x] 1.4 Commit the apps removal (manifest + install-packages test)

## 2. herdr-server teardown

- [x] 2.1 Add `home/.chezmoiscripts/macOS/run_once_before_91_unload-retired-agents.sh.tmpl`: `launchctl bootout` each retired agent only when `launchctl print` finds it loaded; quiet no-op otherwise
- [x] 2.2 Add a bats test for 2.1 covering loaded → bootout called, not loaded → no bootout
- [x] 2.3 Confirm ordering: `chezmoi apply --dry-run --verbose` lists `91_unload-retired-agents` before `install-packages`
- [x] 2.4 Delete `private_dot_config/herdr/config.toml`, `local.herdr-server.plist.tmpl`, `executable_herdr-server-ctl`, `run_onchange_after_98b_configure-herdr-service.sh.tmpl` and their bats files
- [x] 2.5 Delete `home/private_dot_config/claude/hooks/executable_herdr-agent-state.sh` and the `SessionStart` block in `claude/settings.json.tmpl`; validate with `chezmoi execute-template < home/private_dot_config/claude/settings.json.tmpl | jq .`
- [x] 2.6 Remove the herdr note and both shfmt/shellcheck excludes from `home/treefmt.toml`
- [x] 2.7 Add `.config/herdr`, `.local/bin/herdr-server-ctl`, `Library/LaunchAgents/local.herdr-server.plist` and `.config/claude/hooks/herdr-agent-state.sh` to `home/.chezmoiremove`
- [x] 2.8 Run `mise exec -- shellcheck` on the new script and the herdr-related bats; commit herdr removal

## 3. opencode

- [x] 3.1 Delete `home/private_dot_config/opencode/`
- [x] 3.2 Delete `run_once_after_96_sync-opencode-mcp.sh.tmpl` and `tests/bats/home/.chezmoiscripts/macOS/run_after_96_sync-opencode-mcp.bats`
- [x] 3.3 Remove `agent_servers.OpenCode` from `home/private_dot_config/zed/private_settings.json` (drop `agent_servers` if empty); confirm valid JSON
- [x] 3.4 Delete the repo's `.opencode/` directory
- [x] 3.5 Remove `opencode/**` from `scripts/config_alignment.ignore`
- [x] 3.6 Add `.config/opencode` to `home/.chezmoiremove`; commit opencode removal (with `tool/opencode.toml`)

## 4. hammerspoon

- [x] 4.1 Delete `home/private_dot_config/hammerspoon/`
- [x] 4.2 Remove the 3 hammerspoon Spoon entries from `home/.chezmoiexternal.toml.tmpl`; render with `chezmoi execute-template` to confirm valid TOML
- [x] 4.3 Remove the Hammerspoon `defaults write` block from `run_onchange_after_98a_configure-brew-apps.sh.tmpl`
- [x] 4.4 Remove the hammerspoon Spoons exclude from `home/treefmt.toml` and `hammerspoon/**` from `scripts/config_alignment.ignore`
- [x] 4.5 Add `.config/hammerspoon` to `home/.chezmoiremove`; commit hammerspoon removal

## 5. ghostty

- [x] 5.1 Delete `home/private_Library/private_Application Support/com.mitchellh.ghostty/config.backup`; keep `home/private_dot_config/ghostty/`
- [x] 5.2 Confirm `chezmoi managed | grep ghostty` still lists `.config/ghostty/config`; commit

## 6. borders

- [x] 6.1 Delete `tool/borders.toml`, `taps/tap-felixkratz-formulae.toml` and `home/private_dot_config/borders/`
- [x] 6.2 Add `homebrew.mxcl.borders` and `homebrew.mxcl.herdr-mx` to the unload script; cover each label in its bats test
- [x] 6.3 Add `.config/borders` and both brew-service plists to `home/.chezmoiremove`
- [x] 6.4 Commit borders removal; fold the `anomalyco/tap` removal into the opencode commit

## 7. Spec and validation

- [x] 7.1 Run `mise exec -- openspec validate remove-unused-tools --strict`
- [x] 7.2 Run `mise exec -- treefmt --config-file home/treefmt.toml` and `mise exec -- shellcheck`
- [x] 7.3 Run `mise exec -- bats -r tests/bats`; only `install.sh.bats:291` and `claude_code_manifest.bats:58` may fail (they fail on a clean checkout too)
- [x] 7.4 `grep -rniE 'herdr|opencode|hammerspoon|borders|felixkratz' --exclude-dir=.git --exclude-dir=archive .` returns only this change's docs
- [x] 7.5 `chezmoi diff` / `chezmoi apply --dry-run`: `.chezmoiremove` targets are removed, `.config/ghostty` is kept

## 8. Apply (manual, per machine)

- [ ] 8.1 On other machines, check app data `--zap` would delete (Brave profiles, cmux); nothing worth keeping on this Mac
- [ ] 8.2 Run `chezmoi apply` from a shell outside herdr
- [ ] 8.3 Verify `launchctl print` fails for all three retired agents and `~/.config/ghostty/config` exists
- [ ] 8.4 Archive the change with `/opsx:archive`
