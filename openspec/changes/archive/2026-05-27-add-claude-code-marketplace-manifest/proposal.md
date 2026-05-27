## Why

Claude Code marketplace source declarations are currently embedded inline in the managed `settings.json` template. This makes adding or removing a marketplace less reviewable than Homebrew taps or formulas, where one typed TOML file declares one managed item.

## What Changes

- Add a Claude Code marketplace manifest under `home/.chezmoidata/` where each marketplace is declared in its own TOML file named after the marketplace.
- Render managed marketplace data from the manifest into Claude Code `extraKnownMarketplaces` settings through the fully managed `settings.json` template.
- Use package-catalog-style `type = "common" | "work" | "personal"` profile filtering for marketplace activation.
- Keep marketplace management Claude Code-specific; Claude Desktop does not support marketplaces and is out of scope.
- Stop managing `known_marketplaces.json`; that file is reserved for Claude default marketplace state and is not the right target for user-managed marketplace declarations.
- Use `extraKnownMarketplaces` as the only managed marketplace declaration surface.
- Keep plugin installation and enabled-plugin selection unchanged; adding a marketplace must not install or enable plugins.

## Capabilities

### New Capabilities

- `claude-code-marketplace-state`: Defines how chezmoi declares, filters, renders, and preserves Claude Code marketplace state.

### Modified Capabilities

- None.

## Impact

- Affects Claude Code configuration templates under `home/private_dot_config/claude/`, specifically the fully managed `settings.json.tmpl`.
- Removes chezmoi management of `~/.config/claude/plugins/known_marketplaces.json` by deleting the corresponding source file.
- Adds new structured data under `home/.chezmoidata/` for marketplace declarations.
- Adds a marketplace renderer template under `home/.chezmoitemplates/`.
- Does not change `plugins/modify_installed_plugins.json`, enabled plugin selection, package installation, secret retrieval, or Claude Desktop behavior.
