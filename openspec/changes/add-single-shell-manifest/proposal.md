change-id: add-single-shell-manifest
title: Add Single Shell Manifest for aliases exports functions and init
status: proposed

## Why
Shell behavior is currently spread across multiple data files and package templates, which makes removal and auditing harder than necessary. A single declarative manifest will make add/remove operations predictable and reviewable.

## What Changes
- Add a single shell manifest file (`home/.chezmoidata/shell_manifest.toml`) that declares aliases, exports, functions, and init snippets.
- Add per-element rule support so every alias/export/function/init item can be conditionally applied.
- Add a typed dynamic resolver catalog in renderer logic so dynamic values remain explicit without embedding Go template syntax in data values.
- Define deterministic rendering precedence and collision handling where aliases/exports use last-writer-wins.
- Keep package install metadata in `home/.chezmoidata/package_catalog.toml`.

## Impact
- Affected specs: `shell-manifest` (new capability)
- Affected code (implementation stage): `home/.chezmoidata/shell_manifest.toml`, `home/.chezmoitemplates/aliases.tmpl`, `home/.chezmoitemplates/exports.tmpl`, `home/.chezmoitemplates/functions.tmpl`, renderer helper templates, and tests
- User-visible outcome: shell behavior can be added or removed from one file while preserving deterministic output
