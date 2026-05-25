## 1. Audit Current Machine State

- [ ] 1.1 Capture the current target machine's Homebrew formula, cask, and tap inventory and compare it against the repo's existing work-machine package declarations under `home/.chezmoidata/`.
- [ ] 1.2 Capture the current Claude enabled plugins, installed plugins, and known marketplaces and compare them against `home/private_dot_config/claude/settings.json.tmpl`, `home/private_dot_config/claude/plugins/modify_installed_plugins.json`, and `home/private_dot_config/claude/plugins/modify_private_known_marketplaces.json`.
- [ ] 1.3 Decide which package and Claude plugin differences are intentional baseline changes versus local-only drift that should remain unmanaged.

## 2. Reconcile Work Machine Package Declarations

- [ ] 2.1 Update the canonical package declarations under `home/.chezmoidata/` so approved Homebrew formulae and casks from the target machine are represented for the correct work-machine and platform scopes.
- [ ] 2.2 Remove or re-scope stale work-machine package declarations that no longer belong in the approved target-machine baseline.
- [ ] 2.3 Run `chezmoi diff` and `chezmoi apply --dry-run` to verify the reconciled package declarations render the intended install behavior without broad profile regressions.

## 3. Reconcile Claude Plugin Managed State

- [ ] 3.1 Update `home/private_dot_config/claude/settings.json.tmpl` so the managed enabled plugin set matches the approved target-machine baseline.
- [ ] 3.2 Update `home/private_dot_config/claude/plugins/modify_installed_plugins.json` and `home/private_dot_config/claude/plugins/modify_private_known_marketplaces.json` so managed installed plugins and marketplaces stay consistent with the approved baseline and existing profile rules.
- [ ] 3.3 Run `chezmoi execute-template < home/private_dot_config/claude/settings.json.tmpl` and render or dry-run checks for the Claude plugin modify templates to confirm plugin identifiers, marketplace coverage, and metadata-preserving behavior remain correct.

## 4. Validate and Finish

- [ ] 4.1 Run `nix run .#treefmt` on the changed files and fix any formatting issues.
- [ ] 4.2 Run `mise exec -- openspec validate realign-chezmoi-machine-state --strict` to verify the change artifacts remain valid.
- [ ] 4.3 Review the final diff to confirm the change only re-aligns approved package and Claude plugin state and does not alter secrets or unrelated machine behavior.
