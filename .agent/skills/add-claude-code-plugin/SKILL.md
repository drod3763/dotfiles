---
name: add-claude-code-plugin
description: Add Claude Code plugin TOML under home/.chezmoidata/claude_code/plugins. Use when installing, enabling, disabling, or managing Claude Code plugins via chezmoi.
---

# Add Claude Code Plugin

## When To Use

- The user asks to add, install, enable, or disable a Claude Code plugin.
- The user provides a plugin key like `plugin@marketplace`.
- The user wants plugin state managed by chezmoi.

## Steps

1. Collect missing fields: plugin key, `type`, `enabled`, dependency, `scope`, `version`, and `git_commit_sha`.
2. Add one TOML file at `home/.chezmoidata/claude_code/plugins/<plugin@marketplace>.toml`.
3. Use the namespace `claude_code.plugins."<plugin@marketplace>"`.
4. Require `type = "common"`, `type = "work"`, or `type = "personal"`.
5. Set `enabled = true` to include a user-scoped plugin in `settings.json enabledPlugins`; set `enabled = false` to install but not enable.
6. Use `depends_on = ["marketplace:<marketplace>"]` for managed marketplaces.
7. Use `depends_on = ["builtin_marketplace:claude-plugins-official"]` only for Claude Code built-in/default marketplace plugins.
8. Use `scope = "user"` unless there is a concrete reason to do otherwise.
9. Render `settings.json.tmpl` and dry-run or diff `installed_plugins.json` to validate behavior.

## Template

```toml
[claude_code.plugins."brew@agentic-tools"]
type = "common"
enabled = true
depends_on = ["marketplace:agentic-tools"]
scope = "user"
version = "9f582fcb4322"
git_commit_sha = "461fae051db15a65bfca58a9cf649682f40d307b"
```

## Rules

- Do not infer all plugins from a marketplace are desired.
- The plugin key must use `plugin@marketplace` form.
- The dependency must match the marketplace suffix in the plugin key.
- Deleting a plugin TOML removes that plugin only inside active owned marketplace scopes.
- Project-scoped plugins are reconciled in `installed_plugins.json` but are not written into global `settings.json enabledPlugins`.
- Existing installed plugin metadata is preserved by the modify template when the plugin is already installed.
