---
name: add-claude-code-marketplace
description: Add Claude Code marketplace TOML under home/.chezmoidata/claude_code/marketplaces. Use when adding marketplace repos, extraKnownMarketplaces entries, or Claude Code marketplace sources to chezmoi.
---

# Add Claude Code Marketplace

## When To Use

- The user asks to add a Claude Code marketplace.
- The user provides a marketplace repo or Git URL for Claude Code plugins.
- The user wants a new `extraKnownMarketplaces` source managed by chezmoi.

## Steps

1. Collect missing fields: marketplace name, `type`, `owned`, source kind, and `repo` or `url`.
2. Add one TOML file at `home/.chezmoidata/claude_code/marketplaces/<name>.toml`.
3. Use the namespace `claude_code.marketplaces."<name>"`.
4. Require `type = "common"`, `type = "work"`, or `type = "personal"`.
5. Require explicit `owned = true` or `owned = false`.
6. Use `source = "github"` with `repo = "owner/name"`, or `source = "git"` with `url = "..."`.
7. Do not hand-edit `known_marketplaces.json`. On macOS/Linux it is not managed; on Windows `home/dot_claude/plugins/modify_known_marketplaces.json` registers each marketplace and `.chezmoiexternal.toml.tmpl` clones it (via `claude_code_windows_marketplaces.tmpl`).
   - Optional: `ssh = true` on a private GitHub marketplace makes Windows clone it over SSH (1Password agent) instead of HTTPS. SSH marketplaces are not externals: `home/.chezmoiscripts/windows/run_after_clone-private-marketplaces.ps1.tmpl` clones them after apply (once the 1Password `agent.toml` exists), and they are registered on the next apply once the checkout exists.
   - Retiring on Windows: `~/.claude` files are merged, not fully rendered. A marketplace whose `type` makes it inactive on a machine, and plugins of an `owned` marketplace that are deleted from the manifest, are removed on the next apply. Deleting a marketplace TOML leaves no record of it, so on each Windows machine also run `claude plugin marketplace remove <name>`.
8. Render `home/private_dot_config/claude/settings.json.tmpl` and validate JSON.

## Template

```toml
[claude_code.marketplaces."agentic-tools"]
type = "common"
owned = true
source = "github"
repo = "drod3763/agentic-tools"
```

## Rules

- Marketplace availability does not imply plugin installation.
- Set `owned = true` only when chezmoi owns the desired plugin inventory for that marketplace.
- Set `owned = false` when the marketplace should be available but local plugins from it should not be pruned by omission.
