# Project Context

## Purpose
Personal dotfiles repository for managing system configuration files across macOS, Linux, and Windows using [chezmoi](https://www.chezmoi.io/). Provides automated setup of development environments, shell configurations, application preferences, and secret management with hardware key integration.

**Key goals:**
- Consistent development environment across machines
- Automated system setup and package installation
- Secure secret management with YubiKey/age encryption
- Cross-platform support with OS-specific configurations

## Tech Stack
- **Dotfile Manager:** chezmoi 2.43.0
- **Shell:** Zsh with zsh4humans (z4h) v5 framework
- **Scripting:** Bash/Shell, Go templating, Python
- **Runtime Manager:** mise (Go: latest)
- **Package Managers:** Homebrew, mas (Mac App Store), whalebrew
- **Encryption:** age with YubiKey-backed identities
- **Secrets:** 1Password integration
- **Formatters:** treefmt (shfmt, shellcheck, gofmt, nixpkgs-fmt)

## Project Conventions

### Code Style
- **Shell scripts:** Use strict mode (`set -eufo pipefail`)
- **ShellCheck:** Enabled with custom rules (see `shellcheckrc`)
- **Conditionals:** Prefer `[[` over `[`
- **Variables:** Always quote and use braces (`"${var}"`)
- **Indentation:** 2 spaces for shell scripts (via shfmt)
- **Templates:** Use Go templating with chezmoi functions

### Chezmoi Naming Conventions
| Prefix/Suffix | Meaning |
|---------------|---------|
| `dot_` | Creates `.` file (e.g., `dot_zshrc` → `.zshrc`) |
| `private_` | Sets restricted permissions (0600/0700) |
| `encrypted_` | Age-encrypted content |
| `executable_` | Sets executable permission |
| `empty_` | Creates empty file |
| `.tmpl` | Go template file |

### Architecture Patterns
- **Template partials:** Reusable snippets in `.chezmoitemplates/`
- **OS conditionals:** Use `.chezmoiignore` and template conditionals for platform-specific files
- **Feature flags:** `$headless`, `$transient`, `$personal` for machine-specific behavior
- **External files:** Themes and fonts managed via `.chezmoiexternal.toml.tmpl` with auto-refresh
- **Lifecycle scripts:** `run_before`, `run_after`, `run_onchange` for setup automation

### Testing Strategy
- Manual testing on target machines
- ShellCheck for static analysis of shell scripts
- Template validation via `chezmoi execute-template`

### Git Workflow
- Main branch for stable configurations
- Feature branches for significant changes
- Conventional commit messages preferred
- Age-encrypted files committed directly (decrypted on apply)

## Domain Context
- **Primary OS:** macOS (with Linux and Windows support)
- **Shell framework:** zsh4humans provides prompt, completions, and plugin management
- **CLI philosophy:** Modern replacements for classic tools (eza, bat, ripgrep, fd, zoxide)
- **macOS automation:** System preferences configured via `defaults` commands (mathiasbynens/dotfiles style)
- **PopClip extensions:** Custom extensions in `private_Library/Application Support/PopClip/Extensions/`

## Important Constraints
- **chezmoi version:** Minimum 2.43.0 required (see `.chezmoiversion`)
- **Hardware keys:** YubiKey required for decrypting secrets on non-transient machines
- **1Password:** Required for credential retrieval and external file URLs
- **Homebrew:** Required on macOS for package management
- **Go:** Required for chezmoi and mise

## External Dependencies
- **1Password:** Secrets, credentials, and private download URLs
- **Homebrew:** Package installation (50+ brews, 40+ casks)
- **Mac App Store:** Apps installed via `mas`
- **External themes:** Catppuccin (bat, micro, zsh-syntax-highlighting), Delta themes
- **Fonts:** Downloaded from 1Password-stored URL
- **Helper apps:** Luna Display, OpenIn Helper
