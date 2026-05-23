## ADDED Requirements

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
