change-id: refactor-chezmoidata-adoption-plan
title: Plan Structured Data Adoption with chezmoidata
status: proposed

## Why
Template logic and configuration values are currently distributed across many `.tmpl` files, which increases duplication and makes large updates riskier than needed. A structured-data-first approach using `chezmoidata` can reduce drift, improve reuse, and make changes easier to review.

## What Changes
- Add a capability to inventory and score candidates for `chezmoidata` migration using explicit heuristics (duplication count, change frequency, secret-sensitivity boundaries, and cross-template reuse).
- Define a canonical `chezmoidata` organization model for this repository (domain files, naming, shape conventions, and ownership).
- Define phased migration rules that preserve rendered behavior while increasing DRYness.
- Define validation and safety gates for each migration phase (`chezmoi execute-template`, `chezmoi diff`, and `chezmoi apply --dry-run`).

## Impact
- Affected specs: `structured-template-data` (new capability)
- Affected code (implementation stage): `home/.chezmoitemplates/**/*.tmpl`, `home/.chezmoiscripts/**/*.tmpl`, `home/private_dot_config/**/*.tmpl`, and new `home/.chezmoidata*` files
- User-visible outcome: a repeatable plan to centralize reusable non-secret config into `chezmoidata` while preserving template behavior
