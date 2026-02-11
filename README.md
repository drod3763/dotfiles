# github.com/drod3763/dotfiles

My dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Installation

### One-line Install (Recommended)

To install these dotfiles on a new machine, run:

```bash
sh -c "$(curl -fsSL https://chezmoi.io/get)" -- init --apply drod3763
```

This will:
1. Install `chezmoi` locally.
2. Initialize with this repository.
3. Apply the configuration (install packages, configure settings).

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
sh -c "$(curl -fsSL https://chezmoi.io/get)" -- init --apply drod3763 --verbose
# or set the environment variable
VERBOSE=1 sh -c "$(curl -fsSL https://chezmoi.io/get)" -- init --apply drod3763
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
