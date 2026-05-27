## 1. Manifest Data Model

- [x] 1.1 Add `home/.chezmoidata/claude_marketplace_manifest/` with one TOML file per currently managed Claude Code marketplace.
- [x] 1.2 Ensure each marketplace TOML file name matches the marketplace key declared inside the file.
- [x] 1.3 Encode marketplace `type` values as `common`, `work`, or `personal` without adding `target_class` fields.
- [x] 1.4 Preserve existing marketplace source forms as either `source = "github"` with `repo` or `source = "git"` with `url`.

## 2. Marketplace Renderer

- [x] 2.1 Add `home/.chezmoitemplates/claude_marketplace_manifest_renderer.tmpl` to resolve active managed marketplaces from manifest data.
- [x] 2.2 Implement profile filtering for `common`, `work`, and `personal` marketplace types.
- [x] 2.3 Render settings-oriented marketplace source data for `extraKnownMarketplaces`.
- [x] 2.4 Do not render install locations, `lastUpdated`, known marketplace entries, or known marketplace state from this manifest.
- [x] 2.5 Keep marketplace declaration keys aligned with their TOML file names by convention and review.

## 3. Template Integration

- [x] 3.1 Keep `home/private_dot_config/claude/settings.json.tmpl` fully managed and render `extraKnownMarketplaces` from the marketplace renderer.
- [x] 3.2 Confirm the fully managed settings template keeps the existing managed settings and plugin selection semantics.
- [x] 3.3 Remove `home/private_dot_config/claude/plugins/modify_private_known_marketplaces.json` so chezmoi stops managing `~/.config/claude/plugins/known_marketplaces.json`.
- [x] 3.4 Confirm `home/private_dot_config/claude/plugins/modify_installed_plugins.json` and enabled plugin selection remain unchanged except for incidental formatting if any.

## 4. Verification

- [x] 4.1 Run `mise exec -- openspec validate add-claude-code-marketplace-manifest --strict`.
- [x] 4.2 Render the fully managed settings template and confirm output is valid JSON.
- [x] 4.3 Confirm the rendered settings output includes active marketplaces and omits profile-inactive marketplaces.
- [x] 4.4 Run `chezmoi diff` or `chezmoi apply --dry-run` to review rendered Claude Code marketplace changes.
- [x] 4.5 Use targeted `chezmoi diff` and semantic JSON comparison to confirm settings marketplaces and plugins have no unintended additions or removals.
