## ADDED Requirements

### Requirement: Private Config Delta Inventory
The dotfiles workflow SHALL provide a repeatable inventory that compares local `~/.config` content against repository-managed `home/private_dot_config` targets.

#### Scenario: Produce categorized delta
- **WHEN** an operator runs the config alignment inventory on a machine
- **THEN** each discovered path SHALL be classified as one of: `local-only`, `repo-only`, `different`, `matched`, or `ignored`
- **AND** the output SHALL include both the local target path and the corresponding repository source path when available

#### Scenario: Handle chezmoi path conventions
- **WHEN** repository paths include chezmoi naming conventions (for example `dot_`, `private_`, or `.tmpl`)
- **THEN** the inventory SHALL normalize those paths to the intended `~/.config` target before classification

### Requirement: Alignment Recommendation Plan
The workflow SHALL generate an explicit recommendation plan from the delta inventory to guide safe synchronization.

#### Scenario: Recommend per-path actions
- **WHEN** the delta inventory contains non-matching entries
- **THEN** each entry SHALL include exactly one recommended action: `adopt-to-repo`, `keep-local`, or `remove-local-drift`
- **AND** each recommendation SHALL include a short rationale

#### Scenario: Protect sensitive and machine-specific data
- **WHEN** an entry is likely sensitive or machine-specific
- **THEN** the recommendation plan SHALL default to `keep-local` unless explicitly approved for promotion

### Requirement: Safe Alignment Workflow
The alignment process SHALL require preview validation before applying repository updates.

#### Scenario: Preview before apply
- **WHEN** an operator chooses to apply approved recommendations
- **THEN** they SHALL run preview checks (including `chezmoi diff` and/or dry-run apply) before final apply
- **AND** the workflow SHALL avoid automatic in-place mutation of local `~/.config` files during the planning step
