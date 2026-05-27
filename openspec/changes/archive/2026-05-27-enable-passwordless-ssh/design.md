## Context

The repository currently has no managed SSH server setup beyond shell-facing SSH client helpers in `home/.chezmoidata/shell_manifest/tool/ssh.toml`. `authorized_keys` is managed by chezmoi for this machine, so the daemon setup must run after chezmoi has copied or rendered it before disabling password-based login.

This change is security-sensitive because it modifies remote login behavior. The implementation should be small, explicit, and guarded for the target platform/profile. macOS is the immediate target for this machine; other platforms should safely skip unless support is intentionally added.

## Goals / Non-Goals

**Goals:**

- Enable SSH public-key login through chezmoi-managed lifecycle automation.
- Disable password-based SSH login when the platform supports doing so without weakening key-based access.
- Apply the agreed SSH hardening policy: `PubkeyAuthentication yes`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `PermitEmptyPasswords no`, `AllowUsers {{ .chezmoi.username }}`, `MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`, and `AllowAgentForwarding no`.
- Keep private keys, passwords, and credentials out of the repository.
- Make the script idempotent enough to re-run safely, or use a run-onchange trigger if configuration content changes.
- Validate rendered template behavior with `chezmoi execute-template` or `chezmoi apply --dry-run` before applying.

**Non-Goals:**

- Managing private SSH keys or embedding secret key material in chezmoi source.
- Replacing the existing SSH shell manifest entry or refactoring SSH client behavior.
- Adding broad cross-platform SSH server automation unless required during implementation.
- Managing network firewall/router exposure or remote access beyond the local SSH daemon configuration.

## Decisions

1. Use an after-apply chezmoi lifecycle script for daemon configuration.

   A script under `home/.chezmoiscripts/` is the right fit because enabling Remote Login and updating SSH daemon settings are machine state changes, not destination dotfiles. It should run after chezmoi has copied/rendered destination files so `~/.ssh/authorized_keys` can be present before password authentication is disabled. A `run_onchange_after_` script is preferable because the managed SSH daemon policy should be re-applied when the script changes.

   Alternative considered: managing `/etc/ssh/sshd_config` as a chezmoi destination file. That is too invasive for macOS and risks clobbering OS-managed defaults.

2. Prefer macOS-native controls for enabling SSH service.

   On macOS, the implementation should use system facilities such as `systemsetup -setremotelogin on` and the platform's SSH daemon configuration files. The script should clearly skip non-macOS platforms until Linux or Windows support is specified.

   Alternative considered: using Homebrew OpenSSH. That would introduce service/package drift and is unnecessary for the built-in daemon.

3. Keep authorized keys copied before daemon setup.

   The user has `authorized_keys` managed by chezmoi. The SSH hardening script should not manage private keys, but it should assume the public authorized keys file may be copied or rendered earlier in the same apply and verify the destination file before disabling password authentication.

   Alternative considered: running daemon setup before chezmoi copies destination files. That risks checking stale or missing authorized keys and could disable password authentication before key login is available.

4. Make password login hardening explicit and reversible.

   The script should configure public-key authentication and disable password authentication where possible, while preserving a clear rollback path. It should also apply the agreed hardening controls for keyboard-interactive authentication, root login, empty passwords, login user restriction, auth retry limits, grace time, X11 forwarding, and agent forwarding. It should avoid destructive rewrites and prefer a managed include/drop-in or targeted update over replacing the whole daemon config.

   Alternative considered: only enabling Remote Login. That would leave password authentication policy ambiguous and fail the security goal of passwordless SSH.

5. Restrict SSH login to the target account, not the client account.

   `AllowUsers` should render from `{{ .chezmoi.username }}` so each target machine allows SSH login only as the account that applied chezmoi there. This does not require the connecting machine's local username to match; clients can still connect with `ssh rendered-user@host`.

   Alternative considered: hardcoding a username. That would break machines where the target account name differs.

## Risks / Trade-offs

- SSH daemon configuration differs across macOS versions -> Use platform checks, verify commands exist, and keep edits narrowly scoped.
- Disabling password login could lock out remote access if key auth is not working -> Run after destination files are copied, require or verify an existing non-empty `~/.ssh/authorized_keys` before applying hardening, and keep rollback instructions simple.
- Disabling agent forwarding may break hop-through workflows -> Make the setting explicit in the managed policy so it can be consciously changed if needed later.
- Chezmoi lifecycle scripts can produce surprising side effects -> Make the script idempotent, guarded, and explicit about skipped platforms.
- Managing system files may require sudo -> Prefer commands/files that clearly fail with actionable messages when privileges are missing.
- Existing local SSH configuration may contain custom settings -> Avoid replacing whole config files; use a managed block/drop-in where supported.
