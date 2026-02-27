## ADDED Requirements

### Requirement: Single Shell Manifest Source
The repository SHALL provide one manifest file that declares aliases, exports, functions, and init snippets for shell behavior.

#### Scenario: Declare shell behavior in one file
- **WHEN** shell behavior is added or removed
- **THEN** the change SHALL be made in `home/.chezmoidata/shell_manifest.toml`
- **AND** shell render templates SHALL consume this manifest as the source for shell behavior

#### Scenario: Keep manifest values static and typed
- **WHEN** values are authored in the manifest
- **THEN** values SHALL use typed data forms such as `literal` and `dynamic`
- **AND** raw inline Go template expressions SHALL NOT be required in manifest values

### Requirement: Per-Element Rules
Each manifest element SHALL support conditional rule evaluation, with entry-level defaults and element-level refinements.

#### Scenario: Evaluate effective eligibility
- **WHEN** an element is considered for rendering
- **THEN** effective eligibility SHALL be computed as entry rules AND element rules
- **AND** the element SHALL be rendered only when the effective rule set passes

#### Scenario: Support standard conditions
- **WHEN** rules are defined
- **THEN** the rule model SHALL support OS, shell, personal/transient profile, tool presence/absence, and file-stat conditions

### Requirement: Dynamic Resolver Allowlist
Dynamic manifest values SHALL resolve through an allowlisted resolver catalog implemented in renderer logic.

#### Scenario: Resolve known dynamic values
- **WHEN** an element value is marked as `dynamic`
- **THEN** the renderer SHALL resolve it using the named resolver and required arguments
- **AND** the resolved value SHALL be rendered as a string output value

#### Scenario: Fail on invalid resolver usage
- **WHEN** a resolver name is unknown or required resolver arguments are missing
- **THEN** rendering SHALL fail with a descriptive error
- **AND** ambiguous partial output SHALL NOT be accepted

### Requirement: Deterministic Ordering and Merge Policy
Rendered shell output SHALL be deterministic for identical inputs and SHALL apply explicit precedence semantics.

#### Scenario: Apply aliases and exports precedence
- **WHEN** multiple active elements define the same alias or export key
- **THEN** the renderer SHALL apply ordering by priority and stable tie-breakers
- **AND** aliases/exports collision handling SHALL use last-writer-wins

#### Scenario: Compose functions and init snippets deterministically
- **WHEN** multiple active elements define functions or init snippets
- **THEN** the renderer SHALL append them in deterministic sorted order
- **AND** output SHALL be reproducible for identical inputs

### Requirement: Keep Install Metadata in Package Catalog
Shell manifest adoption SHALL NOT change package installation metadata ownership.

#### Scenario: Preserve package installation source
- **WHEN** shell manifest rendering is implemented
- **THEN** package installation metadata SHALL remain in `home/.chezmoidata/package_catalog.toml`
- **AND** shell manifest changes SHALL not alter package install selection behavior by themselves
