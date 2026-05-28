## Context

Claude Code marketplace sources are currently managed through TOML files under `home/.chezmoidata/claude_marketplace_manifest/` and rendered into `home/private_dot_config/claude/settings.json.tmpl` as `extraKnownMarketplaces`. Plugin selection still uses two less reviewable surfaces: hardcoded `enabledPlugins` entries in `settings.json.tmpl` and a large `home/private_dot_config/claude/plugins/modify_installed_plugins.json` template with inline managed plugin maps.

The current installed plugin modify template preserves existing Claude-maintained metadata to avoid diff churn and to avoid forcing stale fallback metadata over locally updated plugin entries. That preservation behavior is still valuable, but the desired plugin inventory should be declared as data so additions, removals, profile filtering, and marketplace dependencies are visible in small TOML files.

## Goals / Non-Goals

**Goals:**

- Put Claude Code marketplace and plugin data under a shared `home/.chezmoidata/claude_code/` namespace.
- Keep one TOML file per marketplace and one TOML file per desired plugin.
- Require explicit marketplace ownership metadata so pruning behavior is visible during review.
- Drive `settings.json` `enabledPlugins` from active plugin TOML.
- Keep `installed_plugins.json` modify-managed so existing plugin metadata remains stable.
- Use plugin `depends_on` to gate installation and enablement on active marketplace availability.
- Make missing plugin TOML remove installed plugins only for explicitly owned marketplace scopes.
- Add helper skills that guide future marketplace and plugin additions without making the skills the source of truth.

**Non-Goals:**

- Do not full-replace `installed_plugins.json`.
- Do not manage Claude Code `known_marketplaces.json`.
- Do not infer plugin installation from marketplace availability alone.
- Do not prune plugins from unowned marketplace scopes.
- Do not clean plugin cache directories from disk.
- Do not change package installation, shell manifest behavior, secret retrieval, or Claude Desktop behavior.

## Decisions

### Decision: Use a shared Claude Code data namespace

Marketplace declarations will move from `home/.chezmoidata/claude_marketplace_manifest/` to `home/.chezmoidata/claude_code/marketplaces/`. Plugin declarations will live under `home/.chezmoidata/claude_code/plugins/`.

Rationale:

- Marketplace and plugin state are part of the same Claude Code plugin ecosystem.
- A shared namespace avoids adding another top-level `.chezmoidata` domain for every Claude Code feature.
- The directory split still keeps marketplace availability separate from plugin selection.

Alternatives considered:

- Keep the existing marketplace path and add a separate plugin path. Rejected because the old path name reflects only the first marketplace extraction and does not leave a clean home for plugin state.

### Decision: Require explicit marketplace ownership

Each marketplace TOML file will include `owned = true` or `owned = false`. Owned marketplaces define pruning scopes for installed plugins. Unowned marketplaces can be made available without pruning local plugins from that marketplace.

Rationale:

- Pruning by omission is useful only when the repository intentionally owns the plugin inventory for a marketplace.
- Explicit ownership makes deletion behavior visible in review.
- Defaulting ownership would make accidental plugin removal more likely.

Alternatives considered:

- Treat all managed marketplaces as owned. Rejected because marketplace availability does not always mean chezmoi owns every plugin from that marketplace.
- Treat ownership as implicit from plugin `depends_on`. Rejected because dependency availability and pruning ownership are different policies.

### Decision: Keep installed plugins modify-managed

`installed_plugins.json` will remain a `chezmoi:modify-template`. The template will read current plugin state, preserve existing metadata for active manifest plugins, seed missing manifest plugins, and remove omitted user-scoped plugins only inside active owned marketplace scopes. Project-scoped plugin entries remain local state and are preserved.

Rationale:

- Full replacement would require rendering `installedAt` and `lastUpdated` every time or hardcoding deterministic timestamps.
- Render-time timestamps would create perpetual `chezmoi diff` noise.
- Deterministic timestamps would be stable but misleading as install metadata.
- Modify-management keeps existing metadata stable while still letting TOML own desired plugin selection.

Alternatives considered:

- Full-replace `installed_plugins.json`. Rejected because timestamp and metadata churn would make diffs noisy.
- Preserve all unknown plugin state forever. Rejected for user-scoped plugins in owned marketplaces because deleting a plugin TOML should remove that plugin from managed user state.

### Decision: Plugin TOML declares identity, dependency, and seed metadata

Plugin TOML files will declare the plugin key, `type`, `enabled`, `depends_on`, `scope`, `version`, and `git_commit_sha`. The renderer will derive the plugin name and marketplace from the `plugin@marketplace` key, derive the default install path from marketplace, plugin name, and version, and seed `installedAt` and `lastUpdated` with the current render timestamp only when adding a missing plugin entry.

Plugins from managed marketplaces will use `marketplace:<name>` dependencies. Plugins from Claude Code built-in/default marketplaces that should not be rendered into `extraKnownMarketplaces`, such as `claude-plugins-official`, will use `builtin_marketplace:<name>` dependencies.

Example:

```toml
[claude_code.plugins."brew@agentic-tools"]
type = "common"
enabled = true
depends_on = ["marketplace:agentic-tools"]
scope = "user"
version = "9f582fcb4322"
git_commit_sha = "461fae051db15a65bfca58a9cf649682f40d307b"
```

Rationale:

- The TOML stays focused on desired state and stable seed metadata.
- Existing metadata remains in Claude state when present.
- New entries can still bootstrap on a fresh machine.
- The dependency list makes marketplace availability requirements explicit.

Alternatives considered:

- Store `installed_at` and `last_updated` in TOML. Rejected because they are generated metadata, not desired plugin selection.
- Store explicit `install_path` for every plugin. Rejected because current entries follow a derivable cache path; an override can be added later if needed.
- Force built-in/default marketplaces into `extraKnownMarketplaces`. Rejected because `extraKnownMarketplaces` should remain for user-managed marketplace declarations, while Claude owns default marketplace discovery state.

### Decision: Render enabled plugins from active plugin TOML

`settings.json.tmpl` will consume rendered plugin manifest data and set `enabledPlugins` from active user-scoped plugin declarations where `enabled = true`. Active plugin evaluation includes profile filtering and dependency availability. Project-scoped plugin entries can be preserved or seeded in `installed_plugins.json`, but they are not written into the global `settings.json` enabled-plugin map.

Rationale:

- Enabled plugin selection should use the same source of truth as installed plugin selection.
- `enabled = false` supports installed-but-disabled plugins without removing install state.
- Project-scoped plugin enablement belongs to project state rather than global user settings.

Alternatives considered:

- Keep enabled plugins hardcoded in `settings.json.tmpl`. Rejected because it keeps plugin selection split across multiple review surfaces.

### Decision: Add helper skills as workflow aids

Add `add-claude-code-marketplace` and `add-claude-code-plugin` skills to the repository skill directories. The skills will guide agents to create TOML entries, ask for missing fields, and run validation. They will not encode policy that belongs in specs or renderers.

Rationale:

- Marketplace and plugin additions are common enough to benefit from repeatable guidance.
- Skills can reduce mistakes around `owned`, `depends_on`, and validation without becoming the source of truth.

Alternatives considered:

- Rely only on docs/specs. Rejected because agents already use skills for repo-specific workflows.

## Risks / Trade-offs

- [Risk] Owned marketplace pruning could remove a locally useful plugin. Mitigation: require explicit `owned` metadata and prune only active owned marketplace scopes.
- [Risk] Dependency typos could silently omit plugins. Mitigation: renderers SHALL fail on unsupported dependency kinds and missing marketplace dependencies.
- [Risk] Moving marketplace data paths could change rendered settings output. Mitigation: perform semantic JSON comparison of `extraKnownMarketplaces` before and after migration.
- [Risk] Modify-template logic may become complex. Mitigation: keep renderer outputs small, use deterministic sorted keys, and add focused tests for add, preserve, prune, and dependency cases.
- [Risk] Helper skills could drift from implementation. Mitigation: keep skills procedural and reference the TOML schema and validation commands instead of duplicating renderer behavior.

## Migration Plan

1. Create `home/.chezmoidata/claude_code/marketplaces/` and move existing marketplace TOML entries into the new namespace with explicit `owned` values.
2. Add plugin TOML entries for the current approved managed plugin baseline.
3. Replace or update the marketplace renderer to read from `claude_code.marketplaces`.
4. Add a plugin renderer for active plugin keys, enabled plugin settings, owned marketplace scopes, and install seed entries.
5. Update `settings.json.tmpl` to render `enabledPlugins` and `extraKnownMarketplaces` from renderer outputs.
6. Update `modify_installed_plugins.json` to use the plugin renderer for additions and owned-scope removals while preserving current metadata.
7. Add helper skills for marketplace and plugin additions.
8. Validate templates and compare rendered JSON for expected marketplace, plugin, and profile behavior.

## Open Questions

- None currently.
