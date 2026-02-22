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
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password Service Account token for secret injection | (Interactive prompt) |

## Features

- **macOS Configuration:** Automates system preferences (Finder, Dock, Safari, etc.).
- **Package Management:** Installs Homebrew packages, casks, and Mac App Store apps (via `mas`).
- **Sleep Prevention:** Uses `caffeinate` during installation to prevent sleep interruptions.
- **Progress Feedback:** Provides clear status updates during long-running tasks.
- **Structured Template Data:** Uses domain-scoped `chezmoidata` files under `home/.chezmoidata/` for reusable catalogs (exports, packages, aliases, functions, MCP, 1Password mappings).

## Formatting

This repo includes multi-language formatting via `treefmt` configuration at `home/treefmt.toml`.

- Run all formatters: `treefmt`
- Nix-based run (if available): `nix run .#treefmt`

Configured formatters include:
- `nixpkgs-fmt` for Nix
- `taplo` for TOML
- `shfmt` for shell scripts
- `prettier` (via `bunx`) for JSON/YAML/Markdown
- `prettier-plugin-go-template` (via `bunx`) for `*.tmpl` Go templates

## Testing

Shell script logic tests use `bats-core` with CLI mocks.

- Run test suite: `scripts/run_bats_tests.sh`
- Test files: `tests/bats/*.bats`

## Template Data Layout

Shared template data is split by domain in `home/.chezmoidata/*.toml`.

- `exports.toml` - environment export rules
- `packages.toml` - package catalogs and install rules
- `aliases.toml` - alias catalog and conditional overlays
- `functions.toml` - function toggles/rules
- `mcp.toml` - shared MCP server definitions
- `onepassword.toml` - centralized item/vault mappings and field identifiers

## Secrets and 1Password

Templates avoid hardcoded secrets and use centralized mappings from `home/.chezmoidata/onepassword.toml`.

- Vault aliases are used (`dev`, `work`) instead of raw vault IDs in templates.
- Helpers in `home/.chezmoitemplates/` resolve values by stable field id/label and URL label.
- 1Password service account access is required for secret-backed template rendering.
