## ADDED Requirements

### Requirement: Claude Code plugins are declared as individual manifest files

Desired Claude Code plugin state SHALL be declared in manifest TOML files under `home/.chezmoidata/claude_code/plugins/`, with each file representing exactly one plugin and the file name matching the plugin key.

#### Scenario: Add plugin by adding one file

- **WHEN** a new managed Claude Code plugin is added
- **THEN** the plugin SHALL be declared in a new TOML file named after the plugin key
- **AND** the file SHALL contain desired profile metadata, enablement state, dependency metadata, scope, version, and commit metadata for only that plugin

#### Scenario: Plugin file declares matching plugin key

- **WHEN** the plugin manifest is rendered
- **THEN** each plugin declaration SHALL use a plugin key matching its TOML file name
- **AND** rendering SHALL fail or exclude ambiguous declarations rather than silently applying a mismatched plugin key

#### Scenario: Plugin key identifies marketplace

- **WHEN** a plugin declaration is rendered
- **THEN** the plugin key SHALL use the `plugin@marketplace` form
- **AND** the marketplace suffix SHALL be used when validating marketplace dependencies and owned pruning scopes

### Requirement: Plugin activation uses profile type filtering

The Claude Code plugin manifest SHALL support `type = "common"`, `type = "work"`, and `type = "personal"` filtering with semantics matching marketplace declarations.

#### Scenario: Common plugin is active everywhere

- **WHEN** a plugin declaration has `type = "common"`
- **THEN** the plugin SHALL render as active for both work and personal profiles when its dependencies are available

#### Scenario: Work plugin is active only for work profiles

- **WHEN** a plugin declaration has `type = "work"`
- **AND** chezmoi renders for a non-personal profile
- **THEN** the plugin SHALL render as active when its dependencies are available
- **AND** the plugin SHALL render as inactive for a personal profile

#### Scenario: Personal plugin is active only for personal profiles

- **WHEN** a plugin declaration has `type = "personal"`
- **AND** chezmoi renders for a personal profile
- **THEN** the plugin SHALL render as active when its dependencies are available
- **AND** the plugin SHALL render as inactive for a non-personal profile

### Requirement: Plugin dependencies gate installation and enablement

Each Claude Code plugin declaration SHALL declare dependencies using `depends_on`. Plugins from managed marketplaces SHALL depend on their marketplace using `marketplace:<name>`, and plugins from Claude Code built-in/default marketplaces SHALL depend on that marketplace using `builtin_marketplace:<name>`.

#### Scenario: Plugin depends on active marketplace

- **WHEN** a plugin declaration depends on `marketplace:agentic-tools`
- **AND** the `agentic-tools` marketplace is active for the current profile
- **THEN** the plugin MAY render as active if its own profile type is also active

#### Scenario: Plugin depends on inactive marketplace

- **WHEN** a plugin declaration depends on a marketplace that is inactive for the current profile
- **THEN** the plugin SHALL be omitted from rendered installed plugin reconciliation
- **AND** the plugin SHALL be omitted from rendered enabled plugin settings

#### Scenario: Plugin depends on missing marketplace

- **WHEN** a plugin declaration depends on a marketplace that is not declared in the marketplace manifest
- **THEN** rendering SHALL fail rather than silently installing or enabling the plugin

#### Scenario: Plugin depends on built-in marketplace

- **WHEN** a plugin declaration depends on `builtin_marketplace:claude-plugins-official`
- **THEN** the dependency SHALL be treated as available without requiring a user-managed marketplace declaration
- **AND** the built-in marketplace SHALL NOT be rendered into `extraKnownMarketplaces` only because of that dependency

#### Scenario: Dependency does not match plugin key suffix

- **WHEN** a plugin key uses the `plugin@marketplace` form
- **AND** `depends_on` does not include `marketplace:<marketplace>` or `builtin_marketplace:<marketplace>` for that suffix
- **THEN** rendering SHALL fail rather than accepting an ambiguous marketplace relationship

#### Scenario: Unsupported dependency kind is declared

- **WHEN** a plugin declaration includes a `depends_on` entry with an unsupported dependency kind
- **THEN** rendering SHALL fail rather than ignoring that dependency

### Requirement: Enabled plugin settings render from the plugin manifest

Claude Code `settings.json` `enabledPlugins` SHALL be rendered from active user-scoped plugin manifest entries whose `enabled` value is true.

#### Scenario: Active enabled plugin appears in settings

- **WHEN** a plugin declaration is active for the current profile and dependencies
- **AND** the declaration has `enabled = true`
- **AND** the declaration has `scope = "user"`
- **THEN** rendered `settings.json` SHALL include that plugin under `enabledPlugins`

#### Scenario: Active disabled plugin is installed but not enabled

- **WHEN** a plugin declaration is active for the current profile and dependencies
- **AND** the declaration has `enabled = false`
- **THEN** rendered installed plugin reconciliation SHALL include that plugin
- **AND** rendered `settings.json` SHALL NOT include that plugin under `enabledPlugins`

#### Scenario: Inactive plugin is omitted from settings

- **WHEN** a plugin declaration is inactive for the current profile or dependencies
- **THEN** rendered `settings.json` SHALL NOT include that plugin under `enabledPlugins`

#### Scenario: Project scoped plugin is not globally enabled

- **WHEN** a plugin declaration is active for the current profile and dependencies
- **AND** the declaration has `enabled = true`
- **AND** the declaration has `scope = "project"`
- **THEN** rendered installed plugin reconciliation SHALL include that plugin
- **AND** rendered `settings.json` SHALL NOT include that plugin under `enabledPlugins`

## MODIFIED Requirements

### Requirement: Existing Claude plugin metadata is preserved

The installed plugin modify template SHALL preserve application-maintained metadata for active manifest plugins that already exist in the current Claude state.

#### Scenario: Existing active manifest plugin has current metadata

- **WHEN** an active plugin manifest entry already exists in `installed_plugins.json`
- **THEN** chezmoi SHALL preserve that plugin entry's current `installPath`, `version`, `gitCommitSha`, `installedAt`, and `lastUpdated` values
- **AND** chezmoi SHALL NOT rewrite current plugin metadata to manifest seed metadata

#### Scenario: Active manifest plugin is absent

- **WHEN** an active plugin manifest entry is absent from `installed_plugins.json`
- **THEN** chezmoi SHALL add the plugin using manifest seed metadata
- **AND** chezmoi SHALL seed `installedAt` and `lastUpdated` with the current render timestamp

### Requirement: Unknown Claude plugin state is preserved

The Claude installed plugin modify template SHALL preserve plugin entries that are outside active owned marketplace pruning scopes. Project-scoped plugin entries SHALL be treated as local state and preserved.

#### Scenario: Unmanaged plugin exists outside owned marketplaces

- **WHEN** `installed_plugins.json` contains a plugin not listed in the active plugin manifest
- **AND** the plugin's marketplace suffix is not an active marketplace with `owned = true`
- **THEN** chezmoi SHALL preserve that plugin entry in the rendered output

#### Scenario: Unmanaged plugin exists inside owned marketplace

- **WHEN** `installed_plugins.json` contains a plugin not listed in the active plugin manifest
- **AND** the plugin's marketplace suffix is an active marketplace with `owned = true`
- **AND** the installed plugin entry has `scope = "user"`
- **THEN** chezmoi SHALL remove that plugin entry from the rendered output

#### Scenario: Project-scoped plugin exists inside owned marketplace

- **WHEN** `installed_plugins.json` contains a plugin not listed in the active plugin manifest
- **AND** the plugin's marketplace suffix is an active marketplace with `owned = true`
- **AND** the installed plugin entry has `scope = "project"`
- **THEN** chezmoi SHALL preserve that plugin entry in the rendered output

### Requirement: Managed Claude plugin inventory matches the approved machine baseline

The Claude plugin configuration SHALL encode the approved target machine plugin inventory through individual plugin manifest TOML files, rendered enabled plugin settings, and installed plugin reconciliation.

#### Scenario: Approved marketplace-backed plugin is managed consistently

- **WHEN** a Claude plugin on the current target machine is approved for managed use
- **THEN** the plugin identifier SHALL be represented by an individual plugin manifest TOML file
- **AND** the plugin manifest SHALL declare its required marketplace dependency
- **AND** rendered enabled plugin settings SHALL include the plugin when it is active and intended to be enabled by default
- **AND** the installed plugin modify template SHALL seed or preserve the plugin as managed state when active

#### Scenario: Plugin excluded from approved baseline is not newly managed

- **WHEN** a Claude plugin present on the current target machine is not approved for the managed baseline
- **THEN** chezmoi SHALL NOT add that plugin to the managed enabled-plugin set
- **AND** chezmoi SHALL NOT add a new managed install seed for that plugin unless an individual plugin manifest entry explicitly declares it

## REMOVED Requirements

### Requirement: Managed Claude plugins use aggregate agentic-tools entries

**Reason**: The approved plugin inventory is moving from hardcoded spec lists to individual plugin manifest files.

**Migration**: Current aggregate `agentic-tools` plugin selections SHALL be represented as plugin TOML entries under `home/.chezmoidata/claude_code/plugins/` when they remain desired.

### Requirement: Desired non-agentic Claude plugins are explicit

**Reason**: Explicit desired plugin selection is now provided by the plugin manifest model for all plugin sources, not by separate non-agentic special cases.

**Migration**: Desired non-agentic plugins such as `codex@openai-codex` SHALL be represented as individual plugin TOML entries.

### Requirement: Claude marketplace state remains content-preserving

**Reason**: Claude Code marketplace source declarations are covered by `claude-code-marketplace-state`, and `known_marketplaces.json` is no longer managed by chezmoi for this use case.

**Migration**: Marketplace availability SHALL be rendered through `settings.json` `extraKnownMarketplaces`; Claude-maintained `known_marketplaces.json` remains outside managed plugin state.

### Requirement: Claude plugin reconciliation preserves existing metadata behavior

**Reason**: Metadata preservation is now covered by the updated existing metadata and owned-pruning requirements.

**Migration**: Existing plugin metadata preservation SHALL continue for active manifest plugins, while owned marketplace pruning SHALL remove omitted plugins from explicitly owned scopes.
