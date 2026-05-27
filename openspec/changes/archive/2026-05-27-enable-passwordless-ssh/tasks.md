## 1. Implementation Shape

- [x] 1.1 Inspect existing chezmoi lifecycle script naming and platform guard patterns under `home/.chezmoiscripts/`.
- [x] 1.2 Decide whether the SSH setup should be `run_once_after_` or `run_onchange_after_` based on whether managed daemon settings must be reapplied after script changes.
- [x] 1.3 Identify the machine/profile condition that should enable passwordless SSH for this machine without affecting unrelated hosts.

## 2. Passwordless SSH Lifecycle Script

- [x] 2.1 Add a guarded executable after-apply chezmoi lifecycle script for passwordless SSH setup on supported macOS machines.
- [x] 2.2 Have the script verify `~/.ssh/authorized_keys` exists and is non-empty before disabling password authentication.
- [x] 2.3 Enable macOS Remote Login using native system tooling when it is not already enabled.
- [x] 2.4 Apply narrowly scoped SSH daemon settings for `PubkeyAuthentication yes`, `PasswordAuthentication no`, and `KbdInteractiveAuthentication no` without replacing unrelated local configuration.
- [x] 2.5 Apply hardening settings for `PermitRootLogin no`, `PermitEmptyPasswords no`, `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`, and `AllowAgentForwarding no`.
- [x] 2.6 Render `AllowUsers` from the target machine's chezmoi username rather than hardcoding a single username.
- [x] 2.7 Leave TCP forwarding unchanged unless a later change explicitly disables it.
- [x] 2.8 Make unsupported platforms or unselected machines exit safely without modifying SSH daemon configuration.
- [x] 2.9 Include clear messages for skipped, already-configured, failed-prerequisite, and changed states.

## 3. Validation

- [x] 3.1 Render the new lifecycle script with `chezmoi execute-template` if it is templated.
- [x] 3.2 Run `nix run .#shellcheck -- <script-path>` for the new shell script.
- [x] 3.3 Run `nix run .#treefmt -- <changed-files>` or `nix run .#treefmt` to format changed files.
- [ ] 3.4 Run `chezmoi apply --dry-run` to verify the change is safe before applying.
- [x] 3.5 Run `mise exec -- openspec validate enable-passwordless-ssh --strict` to validate the OpenSpec change.

## 4. Operational Verification

- [x] 4.1 Apply the chezmoi change on the target machine after dry-run succeeds.
- [ ] 4.2 Verify SSH public-key login works from an expected client.
- [ ] 4.3 Verify password SSH login is disabled or rejected according to the platform's supported behavior.
- [x] 4.4 Document rollback steps or the managed file/block to remove if remote login needs to be disabled later.
