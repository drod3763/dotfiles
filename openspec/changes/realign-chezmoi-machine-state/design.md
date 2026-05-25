## Context

The current repo already manages most machine state declaratively, but the requested re-alignment is spread across two different domains. Work-machine package and application expectations live in repo-managed package data and shell-manifest-backed package metadata under `home/.chezmoidata/`, while Claude plugin state is split between `home/private_dot_config/claude/settings.json.tmpl` and modify-managed plugin marketplace and installed-plugin templates under `home/private_dot_config/claude/plugins/`.

The immediate problem is drift: the current target machine has become the practical source of truth for some Homebrew-managed tools, casks, and Claude plugins, while chezmoi still defines an older desired state. This change needs to bring those declarations back into sync without turning the repo into a blind export of every local package or plugin.

Constraints:

- Keep chezmoi as the source of truth after the audit.
- Preserve work versus personal profile rules and existing platform guards.
- Preserve modify-managed Claude metadata behavior so application-maintained plugin fields are not churned.
- Avoid introducing new secret flows, private data formats, or shell-manifest architecture changes.

## Goals / Non-Goals

**Goals:**

- Audit the current target machine's Homebrew and Claude plugin state and translate the approved differences into repo-managed declarations.
- Keep package declarations in their existing canonical locations under `home/.chezmoidata/`.
- Keep Claude plugin declarations consistent across enabled settings, installed plugin seeds, and known marketplaces.
- Make the resulting desired state testable with rendered output and chezmoi dry runs.

**Non-Goals:**

- Automatically import every package, cask, plugin, or marketplace found on the machine.
- Refactor unrelated shell-manifest structure or package catalog modeling.
- Change secret storage, 1Password usage, age encryption, or hardware-key requirements.
- Normalize cross-platform package policy beyond what is required to represent the current target machine's intended state.

## Decisions

### Decision: Use the current target machine as audit input, not as a direct export source

Implementation will inspect the current machine state for Homebrew packages, casks, and Claude plugin data, then promote only the approved items into chezmoi-managed declarations.

Rationale:

- This matches the request to re-align against the current machine.
- It avoids encoding accidental local-only state.

Alternatives considered:

- Export the full machine state into the repo. Rejected because it would capture noise and weaken declarative review.
- Ignore the machine and only trim existing repo state. Rejected because it would miss intentional drift that should become canonical.

### Decision: Keep package alignment in existing package data and shell-manifest package definitions

Package changes will be expressed by updating the existing Homebrew-backed package declarations under `home/.chezmoidata/` rather than adding a new reconciliation layer.

Rationale:

- The repo already uses package metadata in canonical data files.
- This keeps rendered installation behavior and package ownership easy to review.

Alternatives considered:

- Add a separate machine-inventory file. Rejected because it would duplicate package source-of-truth concerns.

### Decision: Reconcile Claude plugin state across all three managed surfaces together

Any approved Claude plugin change will be reflected in:

- `home/private_dot_config/claude/settings.json.tmpl` for enabled plugin state
- `home/private_dot_config/claude/plugins/modify_installed_plugins.json` for installed plugin seeding and profile-specific removals
- `home/private_dot_config/claude/plugins/modify_private_known_marketplaces.json` for marketplace presence

Rationale:

- Plugin enablement, installed seed state, and marketplace availability must agree or fresh setup and modify-managed updates diverge.
- The existing modify templates already preserve application-maintained metadata for known plugins, so they are the right place to encode desired inventory.

Alternatives considered:

- Update only enabled settings. Rejected because missing install seeds or marketplaces would leave bootstrap incomplete.
- Replace modify-managed templates with static JSON. Rejected because it would overwrite application-maintained metadata and create churn.

### Decision: Verify alignment with rendered outputs and dry-run behavior

Implementation should compare the current machine inventory against repo declarations, update the declarations, and then verify with rendered template checks plus `chezmoi diff` or `chezmoi apply --dry-run`.

Rationale:

- The important outcome is declared-state parity, not just edited source files.

## Risks / Trade-offs

- [Risk] The current machine may contain temporary or experimental packages and plugins. → Mitigation: treat machine inventory as audit input and require intentional inclusion in managed declarations.
- [Risk] Work versus personal profile rules may accidentally broaden or narrow package/plugin installation. → Mitigation: keep profile conditions explicit and verify both managed removals and additions where templates branch on `.personal`.
- [Risk] Claude plugin updates may drift between enabled settings, installed plugins, and marketplaces. → Mitigation: update all three surfaces together and review for consistent plugin identifiers.
- [Risk] Package changes could have lifecycle side effects on fresh setup. → Mitigation: validate rendered output and use chezmoi dry-run checks before implementation is considered complete.

## Migration Plan

1. Capture the target machine's current Homebrew and Claude plugin state.
2. Decide which differences represent the intended baseline.
3. Update repo-managed package and Claude plugin declarations only for approved differences.
4. Validate rendered plugin output and package-install behavior with dry-run checks.

## Open Questions

- Whether any current target-machine packages should remain intentionally unmanaged.
- Whether any currently installed Claude plugins are temporary experiments that should be preserved locally but omitted from managed state.
