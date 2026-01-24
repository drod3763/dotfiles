## ADDED Requirements

### Requirement: Work Machine Package Management
The work machine configuration SHALL include all developer tools, AI assistants, and productivity applications required for work development workflows.

#### Scenario: Fresh work machine setup
- **WHEN** chezmoi is applied on a work machine (hostname `P6H9DQX16L` or `personal = false`)
- **THEN** all work-specific Homebrew formulae and casks SHALL be installed
- **AND** common packages shared across all machines SHALL also be installed

#### Scenario: Work-specific AI tooling
- **WHEN** the work machine package script runs
- **THEN** AI coding assistants (Cursor, OpenCode, Antigravity, Pipemind) SHALL be installed
- **AND** these tools SHALL NOT be installed on personal machines

#### Scenario: Work-specific cloud and DevOps tooling
- **WHEN** the work machine package script runs
- **THEN** cloud CLI tools (Azure CLI, Okta AWS CLI, Pulumi) SHALL be installed
- **AND** Kubernetes tooling (helm, kubectx, kubectl, tilt) SHALL be installed
- **AND** Docker Desktop and related tools SHALL be installed

#### Scenario: Work-specific JavaScript/Node tooling
- **WHEN** the work machine package script runs
- **THEN** JavaScript runtimes and tools (Bun) SHALL be installed
- **AND** these complement the common Node.js toolchain

### Requirement: Common CLI Utilities
The dotfiles SHALL install a standard set of CLI utilities on all machines, with work-specific additions for development workflows.

#### Scenario: Common CLI tools on all machines
- **WHEN** chezmoi is applied on any machine
- **THEN** core CLI utilities SHALL be installed: age, bat, chezmoi, eza, fd, ffmpeg, fzf, git, ripgrep, etc.
- **AND** general-purpose tools SHALL be installed: gh, go, jq, yq, glow, pandoc, pipx, uv, yazi, treefmt, opencode

#### Scenario: Terminal emulator preference
- **WHEN** chezmoi is applied
- **THEN** ghostty SHALL be installed as the primary terminal emulator

### Requirement: Work Machine Application Suite
The work machine SHALL include productivity and development applications specific to work workflows.

#### Scenario: Window management and navigation
- **WHEN** the work machine is set up
- **THEN** window management tools (Aerospace, Homerow, Mouseless, Hammerspoon) SHALL be installed
- **AND** BetterDisplay for display management SHALL be installed

#### Scenario: Development applications
- **WHEN** the work machine is set up
- **THEN** development tools SHALL be installed: Bruno (API client), DevToys, GitKraken, JetBrains Toolbox
- **AND** code editors/IDEs SHALL be managed: Cursor, VS Code, Zed

#### Scenario: Hardware integration
- **WHEN** the work machine has connected peripherals
- **THEN** hardware management apps SHALL be installed: Chrysalis (keyboard), Elgato Stream Deck, Mac Mouse Fix, YubiKey Manager
