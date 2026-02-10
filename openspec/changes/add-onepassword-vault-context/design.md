## Overview
This change standardizes all usages of the chezmoi `onepassword` template function to include an explicit vault identifier. The approach is mechanical and low-risk: existing item references remain unchanged, with the vault ID added as an additional argument.

## Current State
- Multiple templates call `onepassword <item-id>` without a vault
- Execution relies on implicit vault resolution, which only works for personal accounts
- Service accounts fail hard without `--vault`

## Proposed Design
- Identify all `onepassword` invocations across templates
- Determine the correct vault for each item (by inspection via `op item get` / `op item list`)
- Update calls to `onepassword <item-id> <vault-id>`

No abstraction or helper is introduced; explicitness is favored for clarity and debuggability.

## Trade-offs
- Slightly more verbose templates
- Vault IDs are now hard-coded (acceptable given stability and clarity)

## Future Considerations
- If vault reuse becomes widespread, a small helper template could centralize vault IDs
- Validation tooling could be added to ensure no vault-less calls are introduced
