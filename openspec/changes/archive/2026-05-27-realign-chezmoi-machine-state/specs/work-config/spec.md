## ADDED Requirements

### Requirement: Work machine package inventory is intentionally reconciled

The work machine configuration SHALL codify the current target machine's approved Homebrew formulae and casks in repo-managed declarations so fresh setup reproduces the intended machine baseline instead of an outdated package set.

#### Scenario: Approved target-machine package becomes managed baseline

- **WHEN** a Homebrew formula or cask present on the current target work machine is approved as part of the standard machine setup
- **THEN** the corresponding repo-managed package declaration SHALL be added or updated in the canonical chezmoi data that drives package installation for work-machine profiles
- **AND** a fresh work-machine apply SHALL include that package in the rendered installation behavior

#### Scenario: Stale managed package is no longer part of desired baseline

- **WHEN** a previously managed Homebrew formula or cask is no longer part of the approved target machine baseline
- **THEN** the repo-managed declaration SHALL be removed or guarded so fresh work-machine setup does not reinstall it

### Requirement: Work machine alignment preserves machine and platform boundaries

Package reconciliation SHALL preserve the repository's existing profile and platform boundaries so re-alignment for the current target machine does not unintentionally change personal, transient, headless, Linux, or Windows behavior.

#### Scenario: Work-only package remains scoped to work machines

- **WHEN** a package is added during target-machine reconciliation for work-specific workflows
- **THEN** the managed declaration SHALL remain gated to the appropriate work-machine profile or platform conditions
- **AND** personal-machine setups SHALL NOT begin installing that package unless explicitly intended

#### Scenario: Cross-platform package handling stays explicit

- **WHEN** a reconciled package only applies to macOS Homebrew-managed setups
- **THEN** the managed declaration SHALL keep that platform scope explicit
- **AND** non-macOS profiles SHALL NOT gain the package through the re-alignment change
