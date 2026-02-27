change-id: add-private-config-alignment-plan
title: Plan Alignment Between Local ~/.config and private_dot_config
status: proposed

## Why
The local `~/.config` directory can drift from the repo-managed `home/private_dot_config` source over time as apps update settings or new tools are installed. Without a repeatable delta and alignment workflow, useful local changes can be lost and stale repo config can persist.

## What Changes
- Add a capability to compute a structured delta between local `~/.config` and repo-managed `home/private_dot_config` content.
- Define categorization rules for delta entries (local-only, repo-only, content-different, template-driven/needs-rendering, and intentionally-ignored).
- Require a human-readable alignment plan that recommends one action per item (adopt into repo, keep local-only, or remove from local).
- Define safety constraints so alignment work uses previews (`chezmoi diff`/dry-run) before any local apply.

## Impact
- Affected specs: `config-alignment` (new capability)
- Affected code (implementation stage): `home/private_dot_config/**`, any new audit tooling/scripts, and operator workflow docs
- User-visible outcome: a consistent, reviewable process for bringing local `~/.config` and repo state back into sync
