## Context

Claude plugin state is currently managed under `home/private_dot_config/claude/` with a mix of full templates and modify templates. `settings.json.tmpl` declares enabled plugins, while `plugins/modify_installed_plugins.json` reads the current `installed_plugins.json`, overlays a hardcoded managed plugin map, and writes the modified result.

The current managed map still declares old `agentic-tools` leaf plugins such as `homebrew-formula-cask`, `pr-prep`, `prettier-hook`, and `truenas-extras`. The local Claude state now uses aggregate plugins such as `brew`, `engineering`, `marketplace`, and `writing-style`, with hash-versioned install paths. As a result, `chezmoi diff` proposes reinstalling old leaf plugin entries and rewriting existing aggregate plugin metadata to stale fallback values.

`known_marketplaces.json` is already modify-managed by `plugins/modify_private_known_marketplaces.json`, preserves existing marketplace entries, and primarily enforces known marketplace presence plus private file permissions.

## Goals / Non-Goals

**Goals:**

- Make the managed Claude plugin set match the aggregate `agentic-tools` plugin model while retaining desired non-agentic plugins such as Codex.
- Remove old leaf plugins from the managed installed and enabled plugin state.
- Stop enabling `clangd-lsp@claude-plugins-official` as part of the managed Claude settings.
- Preserve current plugin metadata for managed plugins when Claude has already installed them.
- Keep deterministic fallback metadata for first-time bootstrap on a new machine.
- Keep `known_marketplaces.json` modify-managed and content-preserving.
- Keep the change limited to Claude plugin state management.

**Non-Goals:**

- Do not change Homebrew package selection or shell manifest package metadata.
- Do not remove plugin cache directories from disk.
- Do not redesign all Claude configuration management.
- Do not introduce new dependencies or secret retrieval behavior.
- Do not change PopClip plist management.

## Decisions

1. Manage aggregate plugin keys instead of old leaf plugin keys.

   The managed aggregate `agentic-tools` set should include `brew@agentic-tools`, `engineering@agentic-tools`, `marketplace@agentic-tools`, and `writing-style@agentic-tools`. The old leaf plugins should be removed from both the installed plugin managed map and the enabled plugin template because their behavior is covered by the aggregate plugins.

   Alternative considered: keep both aggregate and leaf plugins for compatibility. This would preserve redundant state and continue creating noisy diffs, so it is rejected.

2. Preserve current metadata before using fallback metadata.

   For each managed plugin, the modify template should look up the current plugin entry and preserve `installPath`, `version`, `gitCommitSha`, `installedAt`, and `lastUpdated` when present. Fallback metadata remains useful for first-time bootstrap when the plugin key does not yet exist.

   Alternative considered: pin exact versions in source. This improves reproducibility but fights application-managed updates and is the source of the current stale hash/semver drift.

3. Keep Codex managed and enabled, but stop enabling clangd.

   `codex@openai-codex` remains desired Claude plugin state and should continue to be managed/enabled. `clangd-lsp@claude-plugins-official` is no longer desired in the managed enabled set and should not be re-enabled by chezmoi.

   Alternative considered: mirror every locally enabled plugin. This would keep `clangd-lsp` unintentionally and make the managed set less intentional, so only Codex is retained from the non-agentic local drift.

4. Keep the installed plugin modify template as the integration point.

   The existing `chezmoi:modify-template` structure is appropriate because Claude owns parts of `installed_plugins.json`. The implementation should adjust the managed map and merge behavior rather than replacing the file with a static template.

   Alternative considered: stop managing `installed_plugins.json`. That would reduce drift but lose bootstrap behavior on new machines.

5. Leave marketplace content preservation intact.

   `known_marketplaces.json` should continue preserving existing entries while ensuring managed marketplace definitions exist. The current proposal does not need to remove `openai-codex` from known marketplaces because marketplace history is application-managed and harmless when not enabled.

   Alternative considered: prune marketplaces to exactly match settings. This risks removing useful history and is not required to solve the old-plugin reinstall problem.

## Risks / Trade-offs

- Preserving current metadata reduces reproducibility. Mitigation: keep fallback seed metadata for first install and rely on enabled plugin intent for the desired plugin set.
- Existing local plugin cache entries may remain even after old leaf plugins are unmanaged. Mitigation: this proposal only manages JSON state; cache cleanup can be manual or a separate change if needed.
- Hash-versioned plugins may update independently across machines. Mitigation: preserve current metadata per machine and avoid forcing downgrades through chezmoi.
- Template changes could accidentally drop unrelated plugin entries. Mitigation: retain the `deepCopy $current` modify-template pattern and validate with focused `chezmoi diff` commands.
