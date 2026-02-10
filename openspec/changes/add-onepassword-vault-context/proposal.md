change-id: add-onepassword-vault-context
title: Add Explicit Vault Context to All onepassword Usages
status: proposed

## Problem
The dotfiles repository uses the `onepassword` chezmoi template function in multiple locations to fetch secrets and artifacts from 1Password. When executed under a 1Password service account, these calls fail unless an explicit vault is provided. Recent `op` CLI behavior enforces this requirement, causing template execution and `chezmoi apply` to fail.

Currently, vault context is either implicit or missing entirely, which is incompatible with service-account-based automation and headless setups.

## Goal
Ensure all usages of the `onepassword` function in this repository explicitly specify the correct vault, making the configuration compatible with 1Password service accounts and future `op` CLI versions.

## Non-Goals
- Refactoring how secrets are modeled or stored in 1Password
- Changing item IDs, field indices, or secret semantics
- Introducing new secret management systems

## Success Criteria
- All `onepassword` calls include an explicit vault argument
- `chezmoi execute-template` succeeds when authenticated via service account
- No change in rendered output values compared to current behavior
