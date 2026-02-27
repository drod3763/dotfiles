## Tasks
- [x] 1. Define shell-manifest schema with entries for aliases, exports, functions, and init snippets.
- [x] 2. Define rule schema available at entry level and per element, with effective evaluation as entry rules AND element rules.
- [x] 3. Implement shared renderer flow for rule filtering, stable ordering, value resolution, and merge/appending behavior.
- [x] 4. Implement dynamic resolver allowlist with fail-fast behavior for unknown resolvers or missing required arguments.
- [x] 5. Wire `aliases.tmpl`, `exports.tmpl`, `functions.tmpl`, and init rendering to manifest output.
- [x] 6. Migrate shell behavior into manifests under `home/.chezmoidata/shell_manifest/` while preserving behavior.
- [x] 7. Add tests for per-element rules, resolver behavior, deterministic ordering, and aliases/exports last-writer-wins policy.
- [x] 8. Validate with `openspec validate add-single-shell-manifest --strict`, `scripts/run_bats_tests.sh`, `chezmoi diff`, and `chezmoi apply --dry-run`.

## Validation
- Manifest-driven render output remains deterministic for identical context.
- Aliases/exports collisions resolve by last-writer-wins according to documented ordering.
- Dynamic resolver errors are explicit and fail rendering.
- Install metadata is resolved from `package_catalog` blocks in manifest files.
