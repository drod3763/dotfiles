## Why

The target machine has drifted from the chezmoi source of truth across managed package selections and Claude-managed plugin state. This change defines the expected alignment so the repo can be updated intentionally instead of relying on ad hoc machine-by-machine fixes.

## What Changes

- Audit and update the work machine's declared package and application set so managed Homebrew formulae, casks, and related machine-specific tooling match the current target machine where that state should become canonical.
- Reconcile Claude plugin management with the target machine's desired installed and enabled plugin state, including marketplace-backed plugins managed by chezmoi.
- Document the intended scope and non-goals for this re-alignment so implementation stays focused on declared state, not broad refactors of unrelated dotfiles behavior.
- Preserve existing security and profile boundaries, including machine-specific rules, private data handling, and current secret-management workflows.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `work-config`: Update work-machine package and application requirements to match the current target machine's intended Homebrew-managed tools and apps.
- `claude-plugin-state`: Update managed Claude plugin expectations so installed and enabled plugin state reflects the current desired machine setup.

## Impact

- Affected areas include `home/.chezmoidata/` package and machine data, rendered package-installation behavior, and Claude plugin state templates or data sources.
- Verification will require comparing chezmoi-managed package/plugin declarations against the current machine state, then validating rendered output and dry-run behavior.
- No secret format, hardware-key workflow, or cross-platform support model changes are intended.
