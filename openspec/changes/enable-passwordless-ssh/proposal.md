## Why

This machine has `authorized_keys` managed by chezmoi and local configuration updates, but the remaining SSH daemon setup is not yet managed by chezmoi. Capturing passwordless SSH as a change keeps the security-sensitive server configuration repeatable, reviewable, and guarded by machine/profile conditions instead of relying on ad hoc manual edits.

## What Changes

- Add a passwordless SSH setup capability for machines that should accept key-based SSH logins.
- Manage the required SSH server configuration through chezmoi lifecycle automation, likely via a guarded run-once or run-onchange script.
- Ensure the setup enables public-key authentication while disabling password-based remote login where supported.
- Apply agreed hardening settings: disable keyboard-interactive login, root login, empty passwords, X11 forwarding, and agent forwarding; restrict SSH logins to the rendered chezmoi username; set `MaxAuthTries 3` and `LoginGraceTime 20`.
- Preserve secret hygiene by relying on chezmoi-managed public `authorized_keys` content and avoiding plaintext private keys or credentials.
- Keep the implementation scoped to this machine/profile and avoid broad shell manifest, package manifest, or unrelated SSH client refactors.

## Capabilities

### New Capabilities

- `passwordless-ssh`: Defines how chezmoi enables and verifies SSH server passwordless login behavior on supported machines.

### Modified Capabilities

None.

## Impact

- Affected domains: chezmoi lifecycle scripts, SSH server configuration, platform/profile guards, and rendered/applied machine state.
- Rendered files may include a new executable chezmoi script under `home/.chezmoiscripts/` and, if needed, restricted SSH-related source files under `home/private_dot_ssh/`.
- Secret retrieval is not expected to change; private keys and credentials remain outside plaintext source.
- Platform behavior should be explicit, with macOS support prioritized for this machine and unsupported platforms safely skipped unless intentionally added.
