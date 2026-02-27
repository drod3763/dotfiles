# Chezmoi Data Schemas

This directory is the source of truth for package selection and shell behavior.

- `home/.chezmoidata/package_catalog.toml` controls package activation and install metadata.
- `home/.chezmoidata/shell_manifest/**/*.toml` controls shell behavior (`aliases`, `exports`, `functions`, `init`).

Current shell manifest folder layout:

- `home/.chezmoidata/shell_manifest/core/` - shared baseline entries
- `home/.chezmoidata/shell_manifest/shell/` - shell-scoped entries (zsh/bash)
- `home/.chezmoidata/shell_manifest/tool/` - tool-scoped entries, including OS-qualified tool/core-utils entries

## `package_catalog.toml` schema

Each package is a `[[package_catalog.packages]]` object.

Core fields:

- `name`: unique package id.
- `os`: `common` | `mac` | `linux`.
- `type`: `common` | `personal` | `work`.
- `target_class`: `all` | `host` | `vm`.

Optional install fields:

- `brew_formula_name`
- `brew_cask_name`
- `brew_tap_name`
- `mas_app_id`, `mas_app_name`
- `linux_pkg_name`

Optional activation gates:

- `when_tool`, `when_not_tool`
- `when_tools` (all), `when_any_tools` (any)
- `when_stat`

Optional config linkage:

- `config_file_locations`: paths used by `.chezmoiignore` to include/exclude config based on active/inactive packages.

## `shell_manifest/**/*.toml` schema

Shell behavior is split across files but merged by chezmoi data.

Top-level shape:

- `[shell_manifest]` (metadata; currently `version`)
- `[shell_manifest.entries.<entry-id>]`

Entry fields:

- `priority` (int, lower renders first)
- `[shell_manifest.entries.<entry-id>.rules]` (optional)
- `aliases`, `exports`, `functions`, `init` blocks (optional)

Rule keys supported:

- `when_os` (array)
- `when_shell` (array)
- `when_personal` (`"true"|"false"|"any"`)
- `when_transient` (`"true"|"false"|"any"`)
- `when_tool`, `when_not_tool`
- `when_tools_all`, `when_tools_any`, `when_not_tools`
- `when_stat`, `when_not_stat`
- `when_stats_all`, `when_stats_any`

Element value shape:

- Literal:
  - `kind = "literal"`
  - `value = "..."` (or multiline string)
- Dynamic (exports currently):
  - `kind = "dynamic"`
  - `resolver = "..."`
  - `omit_if_empty = true` (optional)

Collision behavior:

- `aliases` and `exports`: last-writer-wins by render order.
- `functions` and `init`: appended in render order.

## Walkthrough: add a new package with aliases/exports/functions/init

1. Add package metadata to `home/.chezmoidata/package_catalog.toml`.

Example:

```toml
[[package_catalog.packages]]
name = "mytool"
os = "mac"
type = "common"
target_class = "all"
brew_formula_name = "mytool"
when_tool = "mytool"
config_file_locations = [".config/mytool"]
```

2. Add shell behavior in a new manifest file, typically `home/.chezmoidata/shell_manifest/tool/mytool.toml`.

```toml
[shell_manifest.entries.mytool]
priority = 260

[shell_manifest.entries.mytool.rules]
when_tool = "mytool"

[shell_manifest.entries.mytool.aliases.mt]
kind = "literal"
value = "mytool"

[shell_manifest.entries.mytool.exports.MYTOOL_HOME]
kind = "literal"
value = "${XDG_CONFIG_HOME}/mytool"

[shell_manifest.entries.mytool.functions.mytool_help]
kind = "literal"
value = '''
mytool_help() {
  mytool --help
}
'''

[shell_manifest.entries.mytool.init.mytool]
kind = "literal"
value = "eval \"$(mytool init zsh)\""
```

3. If init is shell-specific, split by shell rules in separate entries.

```toml
[shell_manifest.entries.mytool-init-zsh.rules]
when_tool = "mytool"
when_shell = ["zsh"]
```

4. Validate:

- `chezmoi execute-template < home/.chezmoitemplates/shell_manifest_renderer.tmpl`
- `chezmoi execute-template < home/.chezmoitemplates/aliases.tmpl`
- `chezmoi execute-template < home/.chezmoitemplates/exports.tmpl`
- `chezmoi execute-template < home/.chezmoitemplates/functions.tmpl`
- `chezmoi execute-template < home/.chezmoitemplates/init.tmpl`
- `scripts/run_bats_tests.sh`

5. Apply and verify:

- `chezmoi diff`
- `chezmoi apply --dry-run`
