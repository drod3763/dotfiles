## 1. Marketplace Data Migration

- [x] 1.1 Create `home/.chezmoidata/claude_code/marketplaces/` and move existing marketplace TOML entries from `home/.chezmoidata/claude_marketplace_manifest/` into the new namespace.
- [x] 1.2 Update each marketplace declaration to use `claude_code.marketplaces` and include explicit `owned = true` or `owned = false` metadata.
- [x] 1.3 Preserve existing marketplace `type`, `source`, `repo`, and `url` semantics during migration.
- [x] 1.4 Remove the legacy `home/.chezmoidata/claude_marketplace_manifest/` source files after render parity is confirmed.

## 2. Plugin Manifest Data

- [x] 2.1 Create `home/.chezmoidata/claude_code/plugins/` with one TOML file per approved managed plugin.
- [x] 2.2 Encode each plugin as `claude_code.plugins."plugin@marketplace"` with `type`, `enabled`, `depends_on`, `scope`, `version`, and `git_commit_sha`.
- [x] 2.3 Ensure each plugin `depends_on` includes `marketplace:<marketplace>` or `builtin_marketplace:<marketplace>` matching the plugin key suffix.
- [x] 2.4 Represent current desired work-only, personal-only, and common plugin selections through plugin TOML instead of hardcoded template maps.

## 3. Renderers

- [x] 3.1 Update or replace the marketplace renderer to read `claude_code.marketplaces`, require explicit ownership, and render active marketplace data for `extraKnownMarketplaces`.
- [x] 3.2 Add a Claude Code plugin renderer that resolves active plugin entries, enabled plugin keys, install seed entries, and active owned marketplace scopes.
- [x] 3.3 Implement validation failures for unsupported plugin types, unsupported dependency kinds, missing managed marketplace dependencies, and dependency/key marketplace mismatches.
- [x] 3.4 Keep renderer output deterministic by sorting marketplace and plugin keys.

## 4. Template Integration

- [x] 4.1 Update `home/private_dot_config/claude/settings.json.tmpl` to render `enabledPlugins` from active user-scoped plugin manifest data.
- [x] 4.2 Update `home/private_dot_config/claude/settings.json.tmpl` to render `extraKnownMarketplaces` from the migrated marketplace renderer.
- [x] 4.3 Update `home/private_dot_config/claude/plugins/modify_installed_plugins.json` to seed active plugin manifest entries while preserving current metadata for existing entries.
- [x] 4.4 Update `modify_installed_plugins.json` to remove omitted user-scoped installed plugins only when their marketplace suffix is an active owned marketplace scope.
- [x] 4.5 Confirm inactive profile or dependency-gated plugins are omitted from both installed plugin reconciliation and enabled plugin settings.

## 5. Helper Skills

- [x] 5.1 Add an `add-claude-code-marketplace` skill that guides agents to add marketplace TOML with explicit `owned`, profile type, and source metadata.
- [x] 5.2 Add an `add-claude-code-plugin` skill that guides agents to add plugin TOML with `depends_on`, enablement, scope, version, and commit metadata.
- [x] 5.3 Mirror the helper skills across the repository skill directories used by Claude, opencode, and agent workflows.
- [x] 5.4 Keep helper skills procedural and reference validation commands rather than duplicating renderer policy.

## 6. Verification

- [x] 6.1 Run `mise exec -- openspec validate manage-claude-code-plugins-via-manifest --strict`.
- [x] 6.2 Render `home/private_dot_config/claude/settings.json.tmpl` with `chezmoi execute-template` and validate the output as JSON.
- [x] 6.3 Render or dry-run `~/.config/claude/plugins/installed_plugins.json` and validate the output as JSON.
- [x] 6.4 Verify common, work, and personal marketplace and plugin filtering with override data where practical.
- [x] 6.5 Verify `enabled = false` keeps a plugin installed but omits it from `enabledPlugins`.
- [x] 6.6 Verify missing plugin TOML prunes installed plugins only for active owned marketplace scopes.
- [x] 6.7 Verify missing or inactive marketplace dependencies prevent plugin installation and enablement.
- [x] 6.8 Run `chezmoi diff` or `chezmoi apply --dry-run` to review the rendered Claude Code changes.
- [x] 6.9 Run formatting and focused tests relevant to changed templates and helper skill markdown.
