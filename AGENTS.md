# Chezmoi Dotfiles - Agent Instructions

## Repository Overview

This is a sophisticated chezmoi-managed dotfiles repository with cross-platform support, templating, encryption, and spec-driven development via OpenSpec.

## Shell Manifest First

The shell manifest under `home/.chezmoidata/shell_manifest/` is central to this repository.

- Treat `shell_manifest/**/*.toml` as the primary source of truth for shell functions, aliases, exports, and init snippets.
- When tracing a shell command or function, check the shell manifest data before assuming it lives in `zshrc`, `functions.tmpl`, or rendered dotfiles.
- `home/.chezmoitemplates/{functions,aliases,exports,init}.tmpl` are render layers, not the canonical source of most shell behavior.
- `home/private_dot_config/zsh/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` source rendered shell sections; they usually do not contain the real function definitions.
- Tool-specific shell behavior is commonly defined in `home/.chezmoidata/shell_manifest/tool/*.toml`.

## Build/Test/Lint Commands

### Primary Commands

```bash
# Format all files (primary linting command)
nix run .#treefmt

# Check shell scripts for issues
nix run .#shellcheck

# Validate chezmoi templates
chezmoi execute-template < file.tmpl

# Test changes without applying
chezmoi diff

# Apply changes safely
chezmoi apply --dry-run
chezmoi apply
```

### Common Chezmoi Commands

```bash
# Preview pending changes
chezmoi diff

# Simulate apply without writing files
chezmoi apply --dry-run

# Render and copy managed files into $HOME
chezmoi apply

# Show managed files that differ from source state
chezmoi status

# Edit the source template for a destination file
chezmoi edit ~/.zshrc

# Inspect full template data
chezmoi data
```

### Single Test Commands

```bash
# Validate specific template
chezmoi execute-template < home/dot_zshrc.tmpl

# Check specific shell script
nix run .#shellcheck -- home/.chezmoiscripts/macOS/run_onchange_before_install-packages.sh.tmpl

# Format specific file
nix run .#treefmt -- home/dot_zshrc.tmpl
```

### Development Workflow

```bash
# Add new dotfile
chezmoi add ~/.config/example

# Edit with template syntax
chezmoi edit ~/.config/example

# Preview changes
chezmoi diff

# Apply changes
chezmoi apply
```

## Code Style Guidelines

### Shell Scripts

```bash
#!/bin/bash
set -euo pipefail  # Always use strict mode
```

**Indentation**: 2 spaces (enforced by shfmt)
**Conditionals**: Prefer `[[` over `[`
**Variables**: Always quote and brace: `"${var}"`
**Functions**: Use snake_case naming
**Comments**: Use `#` for single line, avoid block comments

### Go Templates (Chezmoi)

**Syntax**: Standard Go template syntax with chezmoi functions
**Variables**: Use `{{ .variable }}` for chezmoi variables
**Logic**: `{{ if eq .os "darwin" }}...{{ end }}` for platform detection
**Includes**: Use `{{- template "aliases.tmpl" . -}}` for reusability
**Spacing**: Remove extra whitespace with `{{-` and `-}}`

### File Naming Conventions

| Prefix/Suffix | Purpose                            | Example                |
| ------------- | ---------------------------------- | ---------------------- |
| `dot_`        | Creates dotfiles                   | `dot_zshrc` → `.zshrc` |
| `private_`    | Restricted permissions (0600/0700) | `private_dot_config`   |
| `encrypted_`  | Age-encrypted content              | `encrypted_ssh_config` |
| `executable_` | Executable permissions             | `executable_script`    |
| `.tmpl`       | Go template file                   | `config.tmpl`          |

### Configuration Patterns

**Feature flags**: Use `$headless`, `$transient`, `$personal` for machine types
**External files**: Manage via `.chezmoiexternal.toml.tmpl`
**Lifecycle scripts**: Use `run_before`, `run_after`, `run_onchange` hooks
**Platform detection**: Use `{{ if eq .os "darwin" }}` for macOS-specific code

## Error Handling

### Shell Scripts

- Always use `set -euo pipefail`
- Check command existence: `if command -v brew >/dev/null 2>&1; then`
- Handle failures gracefully with explicit error messages
- Use `>&2` for error output

### Templates

- Provide default values: `{{ or .variable "default" }}`
- Check for required variables: `{{ if not .variable }}{{ error "variable required" }}{{ end }}`
- Use conditional rendering for optional features

## Import/Include Patterns

### Template Includes

```go
{{- template "aliases.tmpl" . -}}
{{- template "functions.tmpl" . -}}
{{- template "path.tmpl" . -}}
{{- template "exports.tmpl" . -}}
```

### Shell Script Sourcing

```bash
if [[ -f "${HOME}/.config/aliases" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.config/aliases"
fi
```

## Security Practices

- Use `private_` prefix for sensitive files (automatically sets 0600/0700)
- Encrypt secrets with `encrypted_` prefix using age
- Never commit plaintext secrets
- Use 1Password integration for credential storage
- Hardware key requirements for non-transient machines

## Platform-Specific Guidelines

### macOS (Darwin)

- Use `defaults` command for system preferences
- Configure Finder, Dock, and system settings
- Use Homebrew for package management
- Handle PopClip extensions and Mac App Store apps

### Linux

- Use appropriate package manager (paru, apt, etc.)
- Adapt paths and configurations for Linux filesystem hierarchy
- Consider different desktop environments

### Windows

- Keep PowerShell hooks under `home/.chezmoiscripts/windows/`
- Prefer native PowerShell patterns for Windows setup/remove flows
- Keep Windows-specific logic out of shared shell templates

## OpenSpec Integration

- All changes should follow spec-driven development
- Run OpenSpec commands via `mise exec -- openspec ...` (avoid relying on global PATH)
- Use `openspec/changes/` for proposals
- Reference `openspec/specs/` for capability definitions
- Follow existing AI agent workflows in `.agent/`

## File Organization

- `home/` - Main dotfiles directory
- `home/.chezmoiscripts/` - Platform-specific setup scripts
- `home/.chezmoidata/` - Domain-scoped template data and package manifests
- `home/.chezmoidata/shell_manifest/` - Canonical shell behavior definitions for aliases, exports, functions, and init
- `home/.chezmoitemplates/` - Reusable template partials
- `home/private_*` - Restricted permission files
- `.agent/workflows/` - Repository-specific OpenSpec helper workflows
- `openspec/` - Specifications and change proposals
- `flake.nix` - Nix flakes configuration

## Destination Mapping

- Files under `home/` render into `$HOME`
- `home/dot_zshrc.tmpl` maps to `~/.zshrc`
- `home/dot_bashrc.tmpl` maps to `~/.bashrc`
- `home/private_dot_config/...` maps to `~/.config/...`
- `home/private_Library/...` maps to `~/Library/...`
- `home/.chezmoiscripts/...` are chezmoi lifecycle hooks, not ordinary copied config files

## Common Patterns

### Adding New Configuration

1. Add file with appropriate prefix (`dot_`, `private_`, etc.)
2. Create template if needed (add `.tmpl` extension)
3. Update `.chezmoiexternal.toml.tmpl` if external file
4. Add platform-specific logic if needed
5. Test with `chezmoi diff` before applying

### Tracing Shell Behavior

1. Start with `home/.chezmoidata/shell_manifest/**/*.toml`
2. Check the relevant entry under `shell_manifest.entries.*`
3. Use `home/.chezmoitemplates/shell_manifest_renderer.tmpl` to understand how entries are merged and filtered
4. Use `home/.chezmoitemplates/{functions,aliases,exports,init}.tmpl` to see where the rendered sections come from
5. Only then inspect `dot_zshrc.tmpl`, `dot_bashrc.tmpl`, or rendered files for sourcing behavior

### Platform Detection

```go
{{ if eq .os "darwin" }}# macOS specific{{ end }}
{{ if eq .os "linux" }}# Linux specific{{ end }}
{{ if eq .distribution "arch" }}# Arch Linux specific{{ end }}
```

### Feature Detection

```go
{{ if lookPath "brew" }}# Homebrew available{{ end }}
{{ if lookPath "git" }}# Git available{{ end }}
```

## Quality Tools

- **treefmt**: Multi-language formatter (primary formatting tool)
- **shellcheck**: Static shell analysis with custom rules
- **chezmoi**: Template validation and diff capabilities
- **nix flake**: Reproducible development environment

## Testing Approach

- Manual testing on target machines
- Template validation via `chezmoi execute-template`
- Static analysis via shellcheck
- Dry-run with `chezmoi apply --dry-run`
- Platform-specific testing on macOS/Linux/Windows
