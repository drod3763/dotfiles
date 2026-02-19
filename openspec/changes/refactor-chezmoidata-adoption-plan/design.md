## Context
This repo uses many Go templates and lifecycle scripts to manage cross-platform dotfiles. Repeated literals and repeated structured blocks (package lists, endpoint maps, environment exports, and service metadata) are currently authored inline in templates. This proposal introduces a data-first planning model so implementation can migrate low-risk, high-value areas first.

## Goals / Non-Goals
- Goals:
  - Define how to identify and prioritize `chezmoidata` migration candidates.
  - Standardize where shared data lives and how templates reference it.
  - Keep migration incremental and behavior-preserving.
- Non-Goals:
  - Complete full migration in one change.
  - Change secret backends or 1Password item semantics.
  - Replace all template logic with data where logic is still clearer.

## Decisions
- Decision: Use a scored inventory before refactoring.
  - Why: Avoid broad churn and prioritize data that yields highest DRY benefit with lowest risk.
  - Alternatives considered:
    - Big-bang migration across all templates (rejected: high risk and hard review).
    - Opportunistic migration during unrelated edits (rejected: inconsistent outcomes).

- Decision: Keep secrets out of `chezmoidata` values by default.
  - Why: `chezmoidata` should primarily hold reusable non-secret structure; secret retrieval remains explicit in templates or encrypted files.
  - Alternatives considered:
    - Store secret references directly in shared data (accepted only for future explicit exceptions with review).

- Decision: Migrate in phases with parity checks.
  - Why: Rendering parity and safe apply workflow are more important than migration speed.
  - Alternatives considered:
    - One-phase migration with post-hoc fixes (rejected: fragile rollback path).

## Risks / Trade-offs
- Risk: Over-normalization can hide intent and reduce readability.
  - Mitigation: Require a readability check per migration and keep one-off values inline.
- Risk: Data shape churn may create noisy diffs.
  - Mitigation: Define stable key naming and sorted deterministic structures.
- Risk: Mixed old/new patterns during transition can confuse contributors.
  - Mitigation: Document migration status and preferred pattern per domain.

## Migration Plan
1. Build candidate inventory with scoring and domain tags.
2. Define canonical data model and file layout for top-priority domains.
3. Migrate first wave (high-score, low-risk domains) with render parity validation.
4. Review outcomes, update heuristics, and execute next wave.

## Open Questions
- Should package metadata for Homebrew/mas be split by machine profile in data files or remain profile-filtered in template logic?
- Which domains should be explicitly excluded from `chezmoidata` centralization for readability or locality?
