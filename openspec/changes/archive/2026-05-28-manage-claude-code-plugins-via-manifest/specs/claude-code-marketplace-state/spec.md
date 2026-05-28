## MODIFIED Requirements

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

## ADDED Requirements

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
