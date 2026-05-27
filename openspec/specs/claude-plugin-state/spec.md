# claude-plugin-state Specification

## Purpose

Define how chezmoi manages Claude plugin marketplaces, installed plugin metadata, and enabled plugin settings while preserving application-maintained state.

## Requirements

### Requirement: Managed Claude plugins use aggregate agentic-tools entries

The Claude plugin configuration SHALL manage aggregate `agentic-tools` plugin entries instead of obsolete leaf plugin entries when rendering installed and enabled plugin state.

#### Scenario: Aggregate plugins are managed

- **WHEN** chezmoi renders Claude plugin installed and enabled state for a personal machine
- **THEN** the managed plugin set SHALL include `brew@agentic-tools`, `engineering@agentic-tools`, `marketplace@agentic-tools`, and `writing-style@agentic-tools`

#### Scenario: Obsolete leaf plugins are not managed

- **WHEN** chezmoi renders Claude plugin installed and enabled state
- **THEN** the managed plugin set SHALL NOT add `homebrew-formula-cask@agentic-tools`, `pr-prep@agentic-tools`, `prettier-hook@agentic-tools`, or `truenas-extras@agentic-tools`

### Requirement: Existing Claude plugin metadata is preserved

The installed plugin modify template SHALL preserve application-maintained metadata for managed plugins that already exist in the current Claude state.

#### Scenario: Existing managed plugin has current metadata

- **WHEN** a managed plugin already exists in `installed_plugins.json`
- **THEN** chezmoi SHALL preserve that plugin entry's current `installPath`, `version`, `gitCommitSha`, `installedAt`, and `lastUpdated` values
- **AND** chezmoi SHALL NOT rewrite hash-versioned plugin metadata to fallback semver metadata

#### Scenario: Managed plugin is absent

- **WHEN** a managed plugin is absent from `installed_plugins.json`
- **THEN** chezmoi SHALL add the plugin using fallback seed metadata for first-time bootstrap

### Requirement: Desired non-agentic Claude plugins are explicit

The Claude plugin configuration SHALL explicitly retain desired non-agentic plugins and SHALL NOT infer desired state from every locally enabled plugin.

#### Scenario: Codex remains managed and enabled

- **WHEN** chezmoi renders Claude plugin installed and enabled state
- **THEN** the managed plugin set SHALL include `codex@openai-codex`
- **AND** the enabled plugin settings SHALL include `codex@openai-codex`

#### Scenario: Clangd is not enabled by managed settings

- **WHEN** chezmoi renders Claude enabled plugin settings
- **THEN** the enabled plugin settings SHALL NOT include `clangd-lsp@claude-plugins-official`

### Requirement: Unknown Claude plugin state is preserved

The Claude installed plugin modify template SHALL preserve plugin entries that are not explicitly managed or explicitly removed by machine profile rules.

#### Scenario: Unmanaged plugin exists locally

- **WHEN** `installed_plugins.json` contains a plugin not listed in the managed plugin set
- **THEN** chezmoi SHALL preserve that plugin entry in the rendered output

### Requirement: Claude marketplace state remains content-preserving

The Claude known marketplace configuration SHALL remain modify-managed and preserve existing marketplace entries while ensuring managed marketplaces exist.

#### Scenario: Existing marketplace metadata changes locally

- **WHEN** `known_marketplaces.json` contains an existing managed marketplace with a current `lastUpdated` value
- **THEN** chezmoi SHALL preserve the current `lastUpdated` value
- **AND** chezmoi SHALL keep the marketplace source and install location aligned with managed definitions

#### Scenario: Extra marketplace exists locally

- **WHEN** `known_marketplaces.json` contains an extra marketplace not listed in the managed marketplace set
- **THEN** chezmoi SHALL preserve that marketplace entry unless a profile rule explicitly removes it

### Requirement: Managed Claude plugin inventory matches the approved machine baseline

The Claude plugin configuration SHALL explicitly encode the approved target machine plugin inventory across managed enabled settings, installed plugin seed state, and known marketplaces.

#### Scenario: Approved marketplace-backed plugin is managed consistently

- **WHEN** a Claude plugin on the current target machine is approved for managed use
- **THEN** the plugin identifier SHALL be represented in managed enabled plugin settings when it is intended to be enabled by default
- **AND** the installed plugin modify template SHALL seed the plugin as managed state
- **AND** the known marketplace configuration SHALL include the plugin's marketplace when the plugin depends on one

#### Scenario: Plugin excluded from approved baseline is not newly managed

- **WHEN** a Claude plugin present on the current target machine is not approved for the managed baseline
- **THEN** chezmoi SHALL NOT add that plugin to the managed enabled-plugin set
- **AND** chezmoi SHALL NOT add a new managed install seed for that plugin unless a profile rule explicitly requires it

### Requirement: Claude plugin reconciliation preserves existing metadata behavior

Re-alignment of the managed Claude plugin inventory SHALL preserve the repository's existing modify-managed behavior for current plugin and marketplace metadata.

#### Scenario: Existing managed plugin metadata is retained during reconciliation

- **WHEN** a managed plugin already exists in the current Claude installed plugin state
- **THEN** chezmoi SHALL continue preserving the plugin entry's current application-maintained metadata fields during rendering
- **AND** reconciling the desired inventory SHALL NOT force fallback seed metadata over current values

#### Scenario: Extra local marketplace state remains preserved unless explicitly managed otherwise

- **WHEN** the current Claude marketplace state contains entries outside the approved managed set
- **THEN** chezmoi SHALL preserve those entries unless a profile rule or explicit managed removal requires otherwise
