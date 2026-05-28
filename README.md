# github.com/drod3763/dotfiles

My dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Installation

### One-line Install (Recommended)

To install these dotfiles on a new machine, run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/drod3763/dotfiles/main/install.sh)"
```

This will:

1. Bootstrap base prerequisites (Xcode CLI tools/Homebrew as needed).
2. Install `chezmoi` locally if missing.
3. Initialize with this repository and apply configuration.
4. During `chezmoi apply`, run a pre-read hook that installs `1password-cli` and `age` when needed.

### Advanced Installation (Clone & Run)

If you prefer to clone the repository first or need custom options:

```bash
git clone git@github.com:drod3763/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./install.sh
```

## Common Chezmoi Commands

- `chezmoi diff` - preview changes without applying them
- `chezmoi apply --dry-run` - simulate an apply run safely
- `chezmoi apply` - copy rendered files into the home directory
- `chezmoi status` - show managed files that differ from source state
- `chezmoi edit ~/.zshrc` - edit the source template for a managed destination file
- `chezmoi execute-template < home/.chezmoitemplates/functions.tmpl` - inspect rendered template output
- `chezmoi data` - inspect the full template data context used during rendering

## Options & Environment Variables

### Verbose Installation

By default, the installation script runs quietly. To see detailed output from `chezmoi` operations:

**Via script:**

```bash
./install.sh --verbose
# or
./install.sh -v
```

**Via curl:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/drod3763/dotfiles/main/install.sh)" -- --verbose
# or set the environment variable
VERBOSE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/drod3763/dotfiles/main/install.sh)"
```

### Configuration Variables

The installation script respects the following environment variables:

| Variable                   | Description                                                                         | Default                                |
| -------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------- |
| `VERBOSE`                  | Set to `1` or `true` to enable verbose output from `chezmoi`                        | `false`                                |
| `OP_SERVICE_ACCOUNT_TOKEN` | Optional 1Password Service Account token for headless/service-mode secret injection | (Interactive prompt during apply hook) |

## Features

- **Cross-Platform Structure:** OS-specific hooks and templates live under `home/.chezmoiscripts/{macOS,windows,linux}`.
- **macOS Configuration:** Automates system preferences (Finder, Dock, Safari, etc.).
- **Package Management:** Installs Homebrew packages, casks, and Mac App Store apps (via `mas`).
- **Sleep Prevention:** Uses `caffeinate` during installation to prevent sleep interruptions.
- **Progress Feedback:** Provides clear status updates during long-running tasks.
- **Structured Template Data:** Uses domain-scoped `chezmoidata` files under `home/.chezmoidata/` for reusable catalogs (package catalog, shell manifests, ignore lists, MCP, 1Password mappings).
- **Package-Aware Config:** Derives app config/env inclusion from the package catalog so machine profiles only materialize relevant app settings.

## Formatting

This repo includes multi-language formatting via `treefmt` configuration at `home/treefmt.toml`.

- Run all formatters: `mise exec -- treefmt --config-file home/treefmt.toml`
- Format specific files: `mise exec -- treefmt --config-file home/treefmt.toml <path>...`

Configured formatters include:

- `nixpkgs-fmt` for Nix
- `taplo` for TOML (including `home/private_dot_config/git/config.tmpl` via a dedicated formatter rule)
- `shfmt` for shell scripts
- `prettier` (via `bunx`) for JSON/YAML/Markdown
- `prettier-plugin-go-template` (via `bunx`) for `*.tmpl` Go templates (when the plugin is resolvable in the active environment)

## Testing

Shell script logic and rendered-template checks use `bats-core` with CLI mocks.

- Run test suite: `scripts/run_bats_tests.sh`
- Test files: `tests/bats/**/*.bats`
- Rendered shell checks: `tests/bats/scripts/check_rendered_shell_templates.bats`

## OpenSpec

Proposal-driven changes live under `openspec/`, with repo-specific helper workflows under `.agent/workflows/`.

- List active changes: `mise exec -- openspec list`
- List current specs: `mise exec -- openspec spec list --long`
- Validate a change or spec: `mise exec -- openspec validate <item> --strict`

## Template Data Layout

Shared template data is split by domain in `home/.chezmoidata/*.toml`.

Schema reference and onboarding guide:

- `docs/chezmoidata.md`

- `shell_manifest/apps/*.toml` - one file per cask package catalog entry (plus app-owned shell entries)
- `shell_manifest/mas/*.toml` - one file per Mac App Store package catalog entry
- `shell_manifest/taps/*.toml` - one file per Homebrew tap package catalog entry
- `shell_manifest/tool/*.toml` - tool/formula package entries plus tool-owned shell entries
- `shell_manifest/**/*.toml` - split shell behavior manifest files (aliases, exports, functions, init)
- `mcp.toml` - shared MCP server definitions
- `onepassword.toml` - centralized item/vault mappings and field identifiers

## Destination Paths

Chezmoi source files in this repo are rendered and copied into your home directory.

- `home/dot_zshrc.tmpl` becomes `~/.zshrc`
- `home/dot_bashrc.tmpl` becomes `~/.bashrc`
- `home/private_dot_config/...` becomes `~/.config/...`
- `home/private_Library/...` becomes `~/Library/...`
- `home/.chezmoiscripts/...` are lifecycle scripts executed by chezmoi during apply, not copied as normal config files

When tracing behavior, check both the source path in this repo and the destination path under `$HOME`.

## Shell Manifest Architecture

The shell manifest under `home/.chezmoidata/shell_manifest/` is the primary source of truth for shell behavior in this repo.

- Shell functions, aliases, exports, and init snippets are generally defined in `shell_manifest/**/*.toml`, not directly in `zshrc` or bash rc files.
- `home/.chezmoitemplates/shell_manifest_renderer.tmpl` merges active manifest entries based on rules like shell, OS, installed tools, and personal/work context.
- `home/.chezmoitemplates/{functions,aliases,exports,init}.tmpl` render those merged entries into shell section files.
- `home/private_dot_config/zsh/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` primarily source those rendered sections.
- Tool-owned shell functions are commonly defined in `home/.chezmoidata/shell_manifest/tool/*.toml`.

If you need to trace a shell function or alias, start with `home/.chezmoidata/shell_manifest/**/*.toml`, then follow the render path through `shell_manifest_renderer.tmpl` and the section templates.

## Secrets and 1Password

Templates avoid hardcoded secrets and use centralized mappings from `home/.chezmoidata/onepassword.toml`.

- Vault aliases are used (`dev`, `work`) instead of raw vault IDs in templates.
- Helpers in `home/.chezmoitemplates/` resolve values by stable field id/label and URL label.
- On macOS with 1Password app installed, chezmoi uses `onepassword.mode = "account"`; otherwise it falls back to `"service"` mode.
- Service account token (`OP_SERVICE_ACCOUNT_TOKEN`) is optional and primarily for headless/CI/service-mode workflows.
- Age identities are bootstrapped from `home/.chezmoidata/onepassword.toml` (`[[onepassword.age_identities]]`) into `~/.config/chezmoi/age-identities/` before apply.

## Package-Centric Configuration

Package behavior is defined by package catalog entries embedded across `home/.chezmoidata/shell_manifest/{apps,mas,taps,tool}/*.toml` and shell entries across `home/.chezmoidata/shell_manifest/**/*.toml`.

- Each package declares lifecycle metadata (`os`, `type`, `target_class`) and install identifiers (`brew_formula_name`, `brew_cask_name`, `mas_app_id`, `linux_pkg_name`).
- Config path inclusion/exclusion is derived from package `config_file_locations` via `home/.chezmoiignore`.
- Shell aliases/exports/functions/init are declared via shell manifest entries in `home/.chezmoidata/shell_manifest/**/*.toml`.
- Active package sets are computed by `home/.chezmoitemplates/package_catalog_resolver.tmpl` and consumed by install/config templates and ignore resolution.

This supports a package-centric lifecycle with shell behavior defined in declarative manifest data.
