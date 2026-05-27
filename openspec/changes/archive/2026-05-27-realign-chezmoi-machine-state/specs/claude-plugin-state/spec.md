## ADDED Requirements

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
