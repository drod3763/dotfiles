# claude-code-marketplace-state Specification

## Purpose

Define how chezmoi declares and renders Claude Code marketplace sources while preserving Claude-managed marketplace and plugin selection state.

## Requirements

### Requirement: Claude Code marketplaces are declared as individual manifest files

Claude Code marketplace state SHALL be declared in manifest TOML files under `home/.chezmoidata/claude_code/marketplaces/`, with each file representing exactly one marketplace and the file name matching the marketplace name.

#### Scenario: Add marketplace by adding one file

- **WHEN** a new managed Claude Code marketplace is added
- **THEN** the marketplace SHALL be declared in a new TOML file named after that marketplace under `home/.chezmoidata/claude_code/marketplaces/`
- **AND** the file SHALL contain the marketplace source, profile metadata, and ownership metadata for only that marketplace

#### Scenario: Marketplace file declares matching marketplace key

- **WHEN** the marketplace manifest is rendered
- **THEN** each marketplace declaration SHALL use a marketplace key matching its TOML file name
- **AND** rendering SHALL fail or exclude ambiguous declarations rather than silently applying a mismatched marketplace name

### Requirement: Marketplace activation uses profile type filtering

The Claude Code marketplace manifest SHALL support `type = "common"`, `type = "work"`, and `type = "personal"` filtering with semantics matching package and tap declarations.

#### Scenario: Common marketplace is active everywhere

- **WHEN** a marketplace declaration has `type = "common"`
- **THEN** the marketplace SHALL render as active for both work and personal profiles

#### Scenario: Work marketplace is active only for work profiles

- **WHEN** a marketplace declaration has `type = "work"`
- **AND** chezmoi renders for a non-personal profile
- **THEN** the marketplace SHALL render as active
- **AND** the marketplace SHALL render as inactive for a personal profile

#### Scenario: Personal marketplace is active only for personal profiles

- **WHEN** a marketplace declaration has `type = "personal"`
- **AND** chezmoi renders for a personal profile
- **THEN** the marketplace SHALL render as active
- **AND** the marketplace SHALL render as inactive for a non-personal profile

#### Scenario: Target class does not affect marketplaces

- **WHEN** Claude Code marketplace state is rendered
- **THEN** renderer behavior SHALL NOT depend on `target_class`, host class, VM class, or transient machine class

### Requirement: Marketplace state is Claude Code-specific

Managed marketplace state SHALL target Claude Code marketplace support and SHALL NOT imply Claude Desktop marketplace support.

#### Scenario: Claude Desktop-only configuration is not targeted

- **WHEN** Claude configuration is rendered for marketplace state
- **THEN** the marketplace manifest SHALL be treated as Claude Code marketplace state
- **AND** the change SHALL NOT add Claude Desktop-specific marketplace behavior

### Requirement: Marketplace sources preserve Claude source schema

Each marketplace declaration SHALL explicitly preserve the Claude source schema as either a GitHub repository source or a raw Git URL source.

#### Scenario: GitHub source marketplace renders owner repo

- **WHEN** a marketplace declaration uses `source = "github"` and a `repo` value
- **THEN** rendered marketplace state SHALL contain `source.source = "github"`
- **AND** rendered marketplace state SHALL contain the declared `source.repo` value

#### Scenario: Git source marketplace renders raw URL

- **WHEN** a marketplace declaration uses `source = "git"` and a `url` value
- **THEN** rendered marketplace state SHALL contain `source.source = "git"`
- **AND** rendered marketplace state SHALL contain the declared `source.url` value

#### Scenario: Source form is not inferred from repository visibility

- **WHEN** a marketplace repository is private or public
- **THEN** the renderer SHALL preserve the source form declared in the manifest
- **AND** the renderer SHALL NOT convert between `github` and `git` source forms based on repository visibility

### Requirement: Manifest renders settings marketplace declarations

The Claude Code marketplace manifest SHALL render the managed marketplace source data used by `settings.json` `extraKnownMarketplaces`.

#### Scenario: Active marketplace appears in settings marketplaces

- **WHEN** a managed marketplace is active for the current profile
- **THEN** rendered `settings.json` SHALL include that marketplace under `extraKnownMarketplaces`
- **AND** the rendered settings entry SHALL include the marketplace source data

#### Scenario: Inactive marketplace is omitted from settings marketplaces

- **WHEN** a managed marketplace is inactive for the current profile
- **THEN** rendered `settings.json` SHALL NOT include that marketplace under `extraKnownMarketplaces`

### Requirement: Known marketplace state is not managed by chezmoi

Chezmoi SHALL NOT manage Claude Code `known_marketplaces.json`; user-managed marketplace declarations SHALL be rendered only through `settings.json` `extraKnownMarketplaces`.

#### Scenario: Known marketplace state remains outside manifest rendering

- **WHEN** marketplace manifest data is rendered
- **THEN** the manifest SHALL NOT render `known_marketplaces.json` state
- **AND** chezmoi SHALL NOT manage the `known_marketplaces.json` destination for this marketplace use case

#### Scenario: Claude default marketplace state is left to Claude

- **WHEN** Claude Code maintains default marketplace state, install locations, or `lastUpdated` metadata
- **THEN** chezmoi SHALL leave that state outside the managed marketplace manifest process

### Requirement: Marketplace availability does not select plugins

Adding or activating a Claude Code marketplace SHALL NOT install plugins, enable plugins, remove installed plugins, or otherwise change plugin selection.

#### Scenario: Marketplace added without plugin selection

- **WHEN** a marketplace declaration is added to the manifest
- **THEN** rendered installed plugin state SHALL remain unchanged by that marketplace declaration
- **AND** rendered enabled plugin settings SHALL remain unchanged by that marketplace declaration

#### Scenario: Plugin manifest remains separate

- **WHEN** plugin installation or enabled-plugin selection needs to change
- **THEN** that change SHALL be handled outside the Claude Code marketplace manifest

### Requirement: Marketplace ownership is explicit

Each Claude Code marketplace declaration SHALL explicitly declare whether chezmoi owns plugin inventory for that marketplace using `owned = true` or `owned = false`.

#### Scenario: Owned marketplace declares pruning scope

- **WHEN** a marketplace declaration has `owned = true`
- **THEN** rendered plugin reconciliation SHALL treat that marketplace as an owned pruning scope
- **AND** installed plugins from that marketplace MAY be removed when no active plugin manifest entry declares them

#### Scenario: Unowned marketplace preserves local plugin state

- **WHEN** a marketplace declaration has `owned = false`
- **THEN** rendered plugin reconciliation SHALL NOT prune installed plugins from that marketplace only because they are missing from the plugin manifest

#### Scenario: Ownership is omitted

- **WHEN** a marketplace declaration does not include `owned`
- **THEN** rendering SHALL fail rather than defaulting ownership behavior

### Requirement: Marketplace data uses the Claude Code namespace

Claude Code marketplace manifest data SHALL use the `claude_code.marketplaces` TOML namespace.

#### Scenario: Marketplace data renders from Claude Code namespace

- **WHEN** marketplace data is rendered
- **THEN** the renderer SHALL read marketplace entries from `claude_code.marketplaces`
- **AND** the renderer SHALL NOT require the legacy `claude_marketplace_manifest.marketplaces` namespace

#### Scenario: Legacy marketplace namespace is not the desired source

- **WHEN** implementation migrates marketplace data
- **THEN** marketplace declarations SHALL be moved out of the legacy `home/.chezmoidata/claude_marketplace_manifest/` location
- **AND** rendered `settings.json` marketplace semantics SHALL remain equivalent except for explicitly added ownership metadata
