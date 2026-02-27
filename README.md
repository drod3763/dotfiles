# github.com/drod3763/dotfiles

My dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Installation

### One-line Install (Recommended)

To install these dotfiles on a new machine, run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/drod3763/dotfiles/main/install.sh)"
```

This will:
1. Bootstrap prerequisites (Xcode CLI tools/Homebrew/1Password CLI as needed).
2. Install `chezmoi` locally if missing.
3. Initialize with this repository and apply configuration.

### Advanced Installation (Clone & Run)

If you prefer to clone the repository first or need custom options:

```bash
git clone https://github.com/drod3763/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./install.sh
```

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

| Variable | Description | Default |
|----------|-------------|---------|
| `VERBOSE` | Set to `1` or `true` to enable verbose output from `chezmoi` | `false` |
| `OP_SERVICE_ACCOUNT_TOKEN` | Optional 1Password Service Account token for headless/service-mode secret injection | (Interactive prompt) |

## Features

- **macOS Configuration:** Automates system preferences (Finder, Dock, Safari, etc.).
- **Package Management:** Installs Homebrew packages, casks, and Mac App Store apps (via `mas`).
- **Sleep Prevention:** Uses `caffeinate` during installation to prevent sleep interruptions.
- **Progress Feedback:** Provides clear status updates during long-running tasks.
- **Structured Template Data:** Uses domain-scoped `chezmoidata` files under `home/.chezmoidata/` for reusable catalogs (package catalog, shell manifests, ignore lists, MCP, 1Password mappings).
- **Package-Aware Config:** Derives app config/env inclusion from the package catalog so machine profiles only materialize relevant app settings.

## Formatting

This repo includes multi-language formatting via `treefmt` configuration at `home/treefmt.toml`.

- Run all formatters: `treefmt`
- Nix-based run (if available): `nix run .#treefmt`

Configured formatters include:
- `nixpkgs-fmt` for Nix
- `taplo` for TOML (including `home/private_dot_config/git/config.tmpl` via a dedicated formatter rule)
- `shfmt` for shell scripts
- `prettier` (via `bunx`) for JSON/YAML/Markdown
- `prettier-plugin-go-template` (via `bunx`) for `*.tmpl` Go templates (when the plugin is resolvable in the active environment)

## Testing

Shell script logic tests use `bats-core` with CLI mocks.

- Run test suite: `scripts/run_bats_tests.sh`
- Test files: `tests/bats/**/*.bats`

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
