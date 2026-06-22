---
name: template-formatter
description: Keep render-only chezmoi templates formatter-clean by comparing rendered original vs rendered formatted output, then applying equivalent line-level edits back to templates.
---

# Template Formatter

## When To Use
- Any change to render-only templates listed in `tmp/templated_format_render_only.txt`.
- Any formatter-rule change that affects rendered output (for example `home/treefmt.toml`).
- Any request to make template source match formatter output without flattening template logic.

> Note: `*.toml.tmpl` files are handled automatically by `[formatter.toml-template]`
> in `home/treefmt.toml` (`scripts/format_toml_template.js`), which renders the
> template and maps `taplo` formatting back onto the static TOML lines. This skill
> covers the remaining render-only templates (shell, json, yaml) and any manual
> reconciliation. `home/.chezmoi.toml.tmpl` is hand-maintained (excluded from both
> template formatters) because it never renders via `execute-template`.

## Guardrails
- Never overwrite template logic with rendered output.
- Keep edits source-level and minimal (whitespace, indentation, trim markers, comment placement).
- Treat `home/private_dot_config/git/config.tmpl` as TOML-style with `taplo --force`.
- Treat `home/dot_bash_profile.tmpl` and `home/dot_bashrc.tmpl` as shell (`shfmt`), not TOML.
- For files with unsupported formatters, report `none` and skip instead of forcing unsafe transforms.

## Workflow
1. Generate template lists with `.claude/skills/template-formatter/resources/generate_template_format_lists.sh`.
2. Read render-only list from `tmp/templated_format_render_only.txt`.
3. For each file, render an original copy into `tmp/rendered_template_compare/original/...` using `chezmoi execute-template --source <repo>`.
4. Copy to `tmp/rendered_template_compare/formatted/...` and run mapped formatter:
   - JSON/YAML: `bunx prettier --write`
   - TOML: `taplo format`
   - Shell: `shfmt -s -w -i 2`
   - Git config template: `taplo format --force` on a temporary `.toml` filename
5. Diff original vs formatted (`git diff --no-index`) and store per-file diffs in `tmp/rendered_template_compare/diffs/...`.
6. Apply only the equivalent line-level style changes back to template source.
7. Re-run the render/diff pass until changed count is zero for all renderable files.

## Success Criteria
- `tmp/rendered_template_compare/summary.json` shows `changed: false` for all renderable templates.
- Any non-renderable template (for example prompt-dependent) is explicitly listed with a clear render error.
- Template behavior remains unchanged (formatting-only source edits).
