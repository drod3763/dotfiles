## Context
This repository already manages many `~/.config` targets through chezmoi files under `home/private_dot_config/**`. Local config continues to evolve outside the repo, and there is no single workflow that inventories drift and translates it into an explicit alignment plan.

The change focuses on planning and repeatable analysis, not automatic mutation.

## Goals / Non-Goals
- Goals:
  - Produce a consistent delta between local `~/.config` and repo-managed `private_dot_config` files.
  - Categorize drift in a way that is actionable for future commits.
  - Keep sensitive data handling explicit and safe.
- Non-Goals:
  - Auto-applying all detected differences.
  - Refactoring existing template logic unrelated to drift.
  - Reorganizing every config path in one pass.

## Decisions
- Decision: Use path normalization based on chezmoi naming rules before comparing files.
  - Why: Repository paths (for example `dot_` and `.tmpl`) do not map 1:1 to filesystem targets.
- Decision: Treat delta generation and alignment recommendation as separate steps.
  - Why: Keeps detection objective and allows human review before action.
- Decision: Include an ignore/exception mechanism for machine-specific artifacts.
  - Why: Some local files should never be promoted to shared dotfiles.

## Risks / Trade-offs
- Risk: False positives from template-rendered files vs source templates.
  - Mitigation: Classify template-driven entries explicitly and require rendered-preview verification.
- Risk: Sensitive values accidentally copied from local configs.
  - Mitigation: Require manual review and preserve `private_`/`encrypted_` handling patterns.
- Risk: Overly broad alignment that changes behavior across machine types.
  - Mitigation: Keep recommendations tagged by machine context (`personal`, `transient`, OS) where detectable.

## Migration Plan
1. Build inventory and produce initial delta report.
2. Review and approve per-path recommendations.
3. Apply small, grouped updates to repo-managed config.
4. Validate with `chezmoi diff` and dry-run apply before rollout.

## Open Questions
- Which local subpaths should be permanently excluded from alignment (cache, telemetry, lockfiles)?
- Should alignment output be committed as an artifact (for example under `openspec/changes/...`) or generated ad hoc?
