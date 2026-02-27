## Context
This repository uses chezmoi templates to render shell aliases, exports, functions, and startup snippets. Behavior is currently split across shared data files and package templates, which increases migration friction when users want to remove or relocate behavior quickly.

## Goals / Non-Goals
- Goals:
  - Declare shell behavior in one file.
  - Support rules on every element (aliases, exports, functions, init).
  - Preserve deterministic output and straightforward precedence.
  - Keep dynamic behavior explicit and safe through a resolver allowlist.
- Non-Goals:
  - Merge package installation metadata into this manifest.
  - Store plaintext secrets in the manifest.
  - Introduce arbitrary code execution from manifest values.

## Decisions
- Decision: Use one static manifest file `home/.chezmoidata/shell_manifest.toml` for shell behavior.
  - Why: one place to add/remove behavior with minimal search cost.

- Decision: Use typed values (`literal` and `dynamic`) instead of inline Go template expressions in data values.
  - Why: explicit intent, safer parsing, and clearer review.

- Decision: Support rules at entry level and per element.
  - Why: enables broad defaults and targeted exceptions without duplicating entries.

- Decision: Aliases/exports use last-writer-wins.
  - Why: simple conflict model that supports deliberate overrides.

- Decision: Keep install metadata in `package_catalog.toml`.
  - Why: avoids coupling package install lifecycle with shell rendering concerns.

## Rules and Ordering Model
1. Evaluate entry rules.
2. Evaluate element rules.
3. Effective eligibility is `entry_rules AND element_rules`.
4. Sort active items by `priority` ascending, then `entry.id`, then element key.
5. Resolve values (`literal` or `dynamic`).
6. Apply merge policy:
   - aliases/exports: last-writer-wins
   - functions/init: append in sorted order

## Resolver Catalog (Initial)
- `source_dir`
- `op_field`
- `coalesce`
- `first_existing_tool`
- `editor_default`
- `init_fzf_zsh`
- `init_fzf_bash`
- `init_zoxide`

## Risks / Trade-offs
- Risk: schema complexity can increase onboarding time.
  - Mitigation: provide concise schema examples and tests for common patterns.
- Risk: hidden override bugs with last-writer-wins.
  - Mitigation: deterministic sort order and explicit tests for precedence.
- Risk: resolver sprawl.
  - Mitigation: keep allowlist small and add resolvers only via spec + tests.

## Migration Plan
1. Add schema + renderer and keep current templates intact.
2. Migrate a first wave of shell behavior into manifest entries.
3. Validate parity and update tests.
4. Remove superseded package shell templates for migrated behavior.

## Open Questions
- Should function/init sections support keyed replacement in addition to append semantics in later phases?
