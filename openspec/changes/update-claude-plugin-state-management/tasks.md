## 1. Update Managed Claude Plugin Set

- [x] 1.1 Remove `homebrew-formula-cask@agentic-tools`, `pr-prep@agentic-tools`, `prettier-hook@agentic-tools`, and `truenas-extras@agentic-tools` from the managed plugin map in `home/private_dot_config/claude/plugins/modify_installed_plugins.json`.
- [x] 1.2 Add or retain fallback seed entries for `brew@agentic-tools`, `engineering@agentic-tools`, `marketplace@agentic-tools`, and `writing-style@agentic-tools` in `modify_installed_plugins.json`.
- [x] 1.3 Add or retain a managed fallback seed entry for `codex@openai-codex` in `modify_installed_plugins.json`.
- [x] 1.4 Remove obsolete profile-specific unset logic for old leaf plugins when it is no longer needed.

## 2. Preserve Existing Plugin Metadata

- [x] 2.1 Update the managed plugin merge loop to preserve current `installPath`, `version`, and `gitCommitSha` when a managed plugin already exists.
- [x] 2.2 Keep existing preservation of `installedAt` and `lastUpdated` for managed plugins.
- [x] 2.3 Ensure fallback seed metadata is used only when the managed plugin is absent from current `installed_plugins.json`.

## 3. Align Enabled Plugin Settings

- [x] 3.1 Update `home/private_dot_config/claude/settings.json.tmpl` to enable `brew@agentic-tools`, `engineering@agentic-tools`, `marketplace@agentic-tools`, `writing-style@agentic-tools`, and `codex@openai-codex`.
- [x] 3.2 Remove enabled settings for the old leaf plugins from `settings.json.tmpl`.
- [x] 3.3 Ensure `clangd-lsp@claude-plugins-official` is not enabled by managed settings.
- [x] 3.4 Confirm existing personal/work conditionals still behave as intended for unrelated plugins.

## 4. Validate Rendered State

- [x] 4.1 Run `chezmoi diff ~/.config/claude/plugins/installed_plugins.json` and verify old leaf plugins are not added by the target.
- [x] 4.2 Run `chezmoi diff ~/.config/claude/settings.json` and verify enabled plugins match the aggregate plugin set plus `codex@openai-codex`, without `clangd-lsp@claude-plugins-official`.
- [x] 4.3 Run `chezmoi diff ~/.config/claude/plugins/known_marketplaces.json` and verify the diff remains content-preserving, aside from expected permissions if present.
- [x] 4.4 Run `mise exec -- openspec validate update-claude-plugin-state-management --strict`.
