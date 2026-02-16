## Tasks
- [x] 1. Define the inventory scope and normalization rules between local `~/.config` paths and `home/private_dot_config` paths (including chezmoi naming conventions like `dot_`, `private_`, and `.tmpl`).
- [x] 2. Implement a repeatable delta report that classifies each config path as local-only, repo-only, different, ignored, matched, or template-driven.
- [x] 3. Generate an alignment plan from the delta report with one recommendation per path: adopt to repo, keep local-only, or remove local drift.
- [x] 4. Add filtering for sensitive or machine-specific paths to avoid proposing unsafe sync actions.
- [x] 5. Document the operator workflow to run delta, review plan, and apply changes safely with preview commands.

## Validation
- Delta report can be generated on macOS for the current machine without modifying files.
- Alignment recommendations are deterministic across repeated runs with unchanged inputs.
- `chezmoi diff` remains clean after applying only approved alignment updates.
- No plaintext secrets are introduced to tracked files during alignment.
