## ADDED Requirements
### Requirement: Structured Data Candidate Inventory
The repository SHALL provide a repeatable inventory process that identifies `chezmoidata` migration candidates from templates and scripts.

#### Scenario: Generate prioritized candidate report
- **WHEN** the structured-data inventory process is run
- **THEN** it SHALL output candidate entries with path, domain tag, and priority
- **AND** each candidate SHALL include a rationale based on explicit heuristics

#### Scenario: Classify sensitive versus non-sensitive candidates
- **WHEN** a candidate references secrets or secret-adjacent values
- **THEN** the process SHALL mark it as sensitive
- **AND** it SHALL require explicit review before recommending centralization in shared data

### Requirement: Canonical chezmoidata Organization
The repository SHALL define a canonical `chezmoidata` organization model for shared non-secret configuration.

#### Scenario: Adopt domain-based data files
- **WHEN** a migration wave is planned
- **THEN** selected candidates SHALL map to documented domain data files
- **AND** key naming and data shape conventions SHALL be documented for those domains

#### Scenario: Preserve local readability
- **WHEN** data extraction would reduce readability for a one-off value
- **THEN** that value SHALL be allowed to remain inline
- **AND** the decision rationale SHALL be recorded in migration notes

### Requirement: Incremental DRY Migration Workflow
`chezmoidata` adoption SHALL be executed in phased migrations with behavior-parity and safety checks.

#### Scenario: Validate phase before apply
- **WHEN** a migration phase is completed
- **THEN** template rendering checks SHALL pass
- **AND** `chezmoi diff` and `chezmoi apply --dry-run` SHALL be used before apply

#### Scenario: Keep migration reviewable
- **WHEN** a migration phase is proposed
- **THEN** it SHALL scope changes to a bounded set of domains
- **AND** it SHALL include rollback guidance for that phase
