## Context

Claude Code marketplace source declarations are currently represented inline in `home/private_dot_config/claude/settings.json.tmpl` under `extraKnownMarketplaces`. The existing `home/private_dot_config/claude/plugins/modify_private_known_marketplaces.json` source manages `~/.config/claude/plugins/known_marketplaces.json`, but that destination is for Claude default marketplace state and is not the right target for user-managed marketplace declarations.

This duplication makes marketplace additions less reviewable than Homebrew taps and formulas, where each managed item is declared as a small TOML file with `type = "common" | "work" | "personal"`. Claude Desktop does not support marketplaces, so this change must remain scoped to Claude Code marketplace state and must not imply any plugin installation or enablement.

## Goals / Non-Goals

**Goals:**

- Make each managed Claude Code marketplace a standalone TOML declaration under `home/.chezmoidata/`.
- Require the TOML file name to match the marketplace name for easy add/remove review.
- Use `type` profile filtering consistent with package and tap declarations.
- Render `extraKnownMarketplaces` from manifest data through the fully managed settings template.
- Stop managing `known_marketplaces.json` and rely on `extraKnownMarketplaces` for user-managed marketplace declarations.
- Keep source declarations explicit as either Claude's `github` plus `repo` shape or `git` plus `url` shape.

**Non-Goals:**

- Do not manage installed plugins or enabled plugins from this manifest.
- Do not add a plugin manifest or plugin renderer in this change.
- Do not render or reconcile `known_marketplaces.json` from this manifest.
- Do not add `target_class` filtering for marketplaces.
- Do not change Claude Desktop configuration behavior.
- Do not normalize GitHub marketplaces from `github` source form to raw `git` URLs, or the reverse.
- Do not change package installation, shell manifest behavior, secrets, or lifecycle scripts.

## Decisions

### Decision: Use one file per marketplace

Each marketplace will be declared in a TOML file under a dedicated data directory such as `home/.chezmoidata/claude_marketplace_manifest/`. The file name will match the marketplace name, for example `agentic-tools.toml` declares `agentic-tools`.

Rationale:

- This mirrors the review shape of package and tap declarations.
- Adding a marketplace becomes a single-file data change plus renderer behavior already in place.
- It avoids common/work/personal grouping files that become large and hide individual marketplace ownership.

Alternatives considered:

- Group marketplaces into common, work, and personal files. Rejected because the repository's package and tap pattern uses one managed item per TOML declaration with `type` metadata.

### Decision: Filter marketplaces by `type`, not `target_class`

Marketplace activation will support `type = "common"`, `type = "work"`, and `type = "personal"`, matching package-catalog profile semantics. The renderer will not consider `target_class` because Claude Code marketplace availability is not tied to host versus transient class in the desired model.

Rationale:

- The important distinction is work versus personal marketplace availability.
- Avoiding `target_class` keeps the manifest smaller and prevents package-install concerns from leaking into Claude Code marketplace state.

Alternatives considered:

- Reuse the full package-catalog filter model. Rejected because `target_class` is explicitly not part of this marketplace policy.

### Decision: Keep the manifest Claude Code-specific

Marketplace state will be treated as Claude Code state only. The renderer and specs will describe Claude Code marketplaces, not generic Claude or Claude Desktop marketplaces.

Rationale:

- Claude Desktop does not support marketplaces.
- The existing marketplace files are under Claude's config directory, but the behavior applies to Claude Code's plugin marketplace feature.

Alternatives considered:

- Use generic Claude naming. Rejected because it obscures the product boundary and could imply unsupported Claude Desktop behavior.

### Decision: Render only settings marketplace declarations

A renderer template will resolve manifest data into a JSON object containing active managed marketplaces and settings-oriented marketplace source data. The fully managed settings template will consume this output for `extraKnownMarketplaces`. The renderer will not write install locations, `lastUpdated`, inactive removals, or known marketplace state.

Rationale:

- `extraKnownMarketplaces` is the appropriate non-restrictive declaration surface for this use case.
- Avoiding known marketplace state keeps the manifest focused on user-managed marketplace discoverability instead of reconciling Claude-maintained default marketplace state.

Alternatives considered:

- Render `known_marketplaces.json` as well. Rejected because the private known marketplace path is restrictive and not the desired marketplace declaration mechanism for this use case.

### Decision: Remove chezmoi management of `known_marketplaces.json`

The implementation will stop managing `~/.config/claude/plugins/known_marketplaces.json` by removing the corresponding source file, rather than leaving an unused modify template in place.

Rationale:

- Keeping the source file would continue touching state that is not intended for this use case.
- Deleting the source file makes the ownership boundary explicit: chezmoi manages `extraKnownMarketplaces`, while Claude owns its known marketplace state.

Alternatives considered:

- Keep the file but stop feeding it manifest data. Rejected because it would still manage a destination that should be left to Claude.

### Decision: Preserve source schema exactly

Marketplace declarations will explicitly encode the Claude source shape. A marketplace may use `source = "github"` with `repo = "owner/name"`, or `source = "git"` with `url = "git@github.com:owner/name.git"` or another Git URL.

Rationale:

- Existing state already uses both source forms.
- Private/public repository visibility does not determine the source form.
- Normalization could change Claude Code behavior without adding value to this manifest extraction.

Alternatives considered:

- Convert all GitHub repositories to `github` source form. Rejected because raw Git URL entries may be intentional.
- Convert private GitHub repositories to SSH Git URLs. Rejected because privacy is not a reliable source-form rule.

## Risks / Trade-offs

- [Risk] Renderer output may not match existing inline template output. -> Mitigation: compare rendered settings output before and after migration.
- [Risk] A marketplace could be declared active but no plugin is intentionally selected. -> Mitigation: codify that marketplace availability SHALL NOT install or enable plugins.
- [Risk] Profile filtering could omit a desired marketplace from settings on the wrong profile. -> Mitigation: test common, work, and personal type behavior through rendered `settings.json` output.
- [Risk] Moving inline data into many files increases file count. -> Mitigation: one file per marketplace improves reviewability and matches existing tap/formula conventions.

## Migration Plan

1. Add marketplace TOML files for the current managed marketplace baseline.
2. Add a renderer that produces active marketplace source data from those TOML files.
3. Update `settings.json.tmpl` to consume rendered `extraKnownMarketplaces` data.
4. Remove the source file that currently manages `~/.config/claude/plugins/known_marketplaces.json`.
5. Verify rendered settings output against current behavior for work and personal profile expectations.

## Open Questions

- None currently.
