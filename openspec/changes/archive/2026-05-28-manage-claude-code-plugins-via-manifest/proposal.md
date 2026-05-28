## Why

Claude Code plugin selection is currently split between inline `settings.json` entries and a large installed-plugin modify template. This makes plugin additions, removals, profile filtering, and marketplace dependencies harder to review than other manifest-driven dotfiles state.

## What Changes

- Move Claude Code marketplace declarations into `home/.chezmoidata/claude_code/marketplaces/` so Claude Code marketplace and plugin data share one domain namespace.
- Add explicit `owned = true|false` marketplace metadata to control whether installed plugins from a marketplace are pruned by omission.
- Add Claude Code plugin declarations under `home/.chezmoidata/claude_code/plugins/`, with one TOML file per desired plugin.
- Render Claude Code enabled plugin settings from the plugin manifest instead of hardcoded inline settings entries.
- Keep `installed_plugins.json` modify-managed, but drive managed additions and owned-marketplace removals from plugin TOML.
- Add plugin `depends_on` support so plugins only install or enable when required marketplaces are available for the active profile.
- Preserve existing installed plugin metadata for active desired plugins, while seeding new managed plugin entries with current render-time metadata.
- Add helper skills for safely adding Claude Code marketplaces and plugins to the chezmoi config.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `claude-code-marketplace-state`: Marketplace manifests move into the `claude_code` data namespace and gain explicit ownership metadata for plugin pruning.
- `claude-plugin-state`: Plugin installation and enabled-plugin selection become manifest-driven, dependency-gated, and prune owned marketplace plugins by omission.

## Impact

- Affects Claude Code config templates under `home/private_dot_config/claude/`, especially `settings.json.tmpl` and `plugins/modify_installed_plugins.json`.
- Adds structured data under `home/.chezmoidata/claude_code/marketplaces/` and `home/.chezmoidata/claude_code/plugins/`.
- Updates renderer templates under `home/.chezmoitemplates/` for marketplace and plugin state.
- Adds helper skill files under the repository skill directories used by Claude, opencode, and agent workflows.
- Does not change package installation, shell manifest behavior, secret retrieval, Claude Desktop behavior, or plugin cache cleanup on disk.
