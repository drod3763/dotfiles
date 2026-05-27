# passwordless-ssh Specification

## Purpose

TBD - created by syncing change enable-passwordless-ssh. Update Purpose after archive.

## Requirements

### Requirement: Passwordless SSH setup is managed by chezmoi

The system SHALL provide a chezmoi-managed lifecycle mechanism for enabling SSH public-key login on supported machines.

#### Scenario: Supported machine applies passwordless SSH setup

- **WHEN** chezmoi applies on a supported machine selected for passwordless SSH
- **THEN** the system runs SSH daemon setup after destination files have been copied or rendered
- **AND** the system enables the local SSH service for public-key login
- **AND** the setup is repeatable without duplicating managed configuration

#### Scenario: Authorized keys copied before hardening

- **WHEN** `authorized_keys` is managed or updated by chezmoi during apply
- **THEN** the passwordless SSH setup evaluates `~/.ssh/authorized_keys` only after that file has been copied or rendered
- **AND** password authentication hardening is not applied before the authorized keys prerequisite can be satisfied

#### Scenario: Unsupported platform is skipped

- **WHEN** chezmoi applies on a platform that the passwordless SSH setup does not support
- **THEN** the system SHALL NOT modify SSH daemon configuration
- **AND** the script reports that the platform is skipped or exits successfully without side effects

### Requirement: Password authentication is disabled when key login is available

The system SHALL disable password-based SSH authentication on supported machines only after key-based login prerequisites are present.

#### Scenario: Authorized keys exist before hardening

- **WHEN** the target machine has a non-empty `~/.ssh/authorized_keys`
- **THEN** the system configures SSH daemon policy to allow public-key authentication
- **AND** the system disables password authentication where supported by the platform
- **AND** the system disables keyboard-interactive authentication where supported by the platform

#### Scenario: Authorized keys are missing

- **WHEN** the target machine does not have a usable `~/.ssh/authorized_keys`
- **THEN** the system SHALL NOT disable password authentication
- **AND** the setup exits with an actionable message explaining the missing prerequisite

### Requirement: SSH secrets remain outside plaintext source

The system SHALL NOT store private SSH keys, passwords, or other SSH credentials in plaintext repository files as part of passwordless SSH setup.

#### Scenario: Repository source is reviewed

- **WHEN** the passwordless SSH change is inspected in chezmoi source
- **THEN** it contains only public configuration, scripts, or references needed to configure the SSH daemon
- **AND** it does not introduce plaintext private key material or passwords

### Requirement: SSH daemon changes are narrowly scoped and reversible

The system SHALL apply SSH daemon configuration using targeted managed changes rather than replacing unrelated local configuration.

#### Scenario: Existing SSH daemon configuration is present

- **WHEN** the target machine already has SSH daemon configuration
- **THEN** the system preserves unrelated existing settings
- **AND** the managed passwordless SSH settings can be identified and removed or changed during rollback

### Requirement: SSH access is hardened beyond passwordless login

The system SHALL apply the agreed SSH hardening policy on supported machines selected for passwordless SSH.

#### Scenario: Hardened daemon policy is applied

- **WHEN** the target machine satisfies passwordless SSH prerequisites
- **THEN** the SSH daemon configuration includes `PubkeyAuthentication yes`
- **AND** it includes `PasswordAuthentication no`
- **AND** it includes `KbdInteractiveAuthentication no`
- **AND** it includes `PermitRootLogin no`
- **AND** it includes `PermitEmptyPasswords no`
- **AND** it includes `MaxAuthTries 3`
- **AND** it includes `LoginGraceTime 20`
- **AND** it includes `X11Forwarding no`
- **AND** it includes `AllowAgentForwarding no`

#### Scenario: Login account is restricted to the rendered target user

- **WHEN** the SSH hardening policy is rendered for a target machine
- **THEN** the SSH daemon configuration restricts `AllowUsers` to the rendered chezmoi username for that target
- **AND** it does not hardcode a username that would apply incorrectly across machines

#### Scenario: TCP forwarding remains available by default

- **WHEN** the SSH hardening policy is applied
- **THEN** the system does not disable TCP forwarding unless a later change explicitly opts into that restriction
