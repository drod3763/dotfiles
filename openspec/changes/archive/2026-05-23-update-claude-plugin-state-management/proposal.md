## Why

Claude plugin state is currently managed with stale, hardcoded leaf plugin pins for `agentic-tools` plugins. The actual desired state has moved to aggregate hash-versioned plugins, so `chezmoi diff` keeps proposing to reinstall old leaf plugins and rewrite current plugin metadata back to obsolete `1.0.0` entries.

This needs a spec-level change because Claude plugin state is managed through modify templates that blend declarative intent with application-maintained runtime metadata; the expected preservation behavior should be explicit before implementation.

## What Changes

- Replace managed `agentic-tools` leaf plugins with the aggregate plugins now used by the local Claude setup.
- Stop managing `homebrew-formula-cask@agentic-tools`, `pr-prep@agentic-tools`, `prettier-hook@agentic-tools`, and `truenas-extras@agentic-tools` as standalone installed/enabled plugins.
- Manage `brew@agentic-tools`, `engineering@agentic-tools`, `marketplace@agentic-tools`, and `writing-style@agentic-tools` as the desired aggregate plugin set.
- Retain `codex@openai-codex` as a desired managed/enabled non-agentic plugin.
- Stop enabling `clangd-lsp@claude-plugins-official` in managed Claude settings.
- Update installed plugin modify behavior so existing managed plugins preserve current `installPath`, `version`, `gitCommitSha`, `installedAt`, and `lastUpdated` metadata when present.
- Keep fallback plugin metadata only for first-time bootstrap when a managed plugin is absent from the current Claude state.
- Align enabled plugin settings with the aggregate plugin set.
- Keep `known_marketplaces.json` modify-managed and content-preserving, with restricted file permissions.

## Capabilities

### New Capabilities

- `claude-plugin-state`: Defines how chezmoi manages Claude plugin marketplaces, installed plugin metadata, and enabled plugin settings while preserving application-maintained state.

### Modified Capabilities

## Impact

- Affects `home/private_dot_config/claude/plugins/modify_installed_plugins.json`.
- Affects `home/private_dot_config/claude/settings.json.tmpl`.
- May affect rendered `~/.config/claude/plugins/installed_plugins.json` and `~/.config/claude/settings.json` diffs.
- Does not change Homebrew package selection, shell manifest behavior, secret retrieval, or platform support.
- Does not remove existing plugin cache directories directly; it only changes managed Claude plugin state.
