# First-Wave Candidate Inventory Draft

## Scoring Rubric (Draft)
- Reuse breadth (0-3): number of templates/scripts that reuse the same structure.
- Duplication weight (0-3): amount of repeated literals or repeated structured blocks.
- Volatility (0-2): expected change frequency over a quarter.
- Sensitivity modifier (-3 to 0): secrets or secret-adjacent data lower first-wave priority.
- Migration complexity modifier (-2 to 0): heavy conditional logic lowers first-wave priority.

Priority formula (draft):
`priority = reuse + duplication + volatility + sensitivity_modifier + complexity_modifier`

## First-Wave Candidates (Low-Risk, High-DRY)

| Domain | Source Path | Proposed chezmoidata Location | Priority (draft) | Rationale |
|---|---|---|---:|---|
| macOS package catalogs | `home/.chezmoiscripts/macOS/run_onchange_before_install-packages.sh.tmpl` | `home/dot_chezmoidata/packages/macos.{yaml,toml}` | 8 | Large repeated lists (`taps`, `brews`, `casks`, `mas`) and profile slicing are ideal for structured catalogs. |
| shell exports metadata | `home/.chezmoitemplates/exports.tmpl` | `home/dot_chezmoidata/env/exports.{yaml,toml}` | 7 | Central map patterns already exist; data extraction can reduce duplication and simplify tool-specific toggles. |
| MCP non-secret endpoints | `home/private_dot_config/claude/encrypted_private_mcp-servers.json.tmpl.age`, `home/dot_cursor/private_mcp.json.tmpl` | `home/dot_chezmoidata/mcp/endpoints.{yaml,toml}` | 6 | Shared endpoint/service definitions can be centralized while keeping token retrieval in templates. |
| alias catalog (non-shell-specific entries) | `home/.chezmoitemplates/aliases.tmpl` | `home/dot_chezmoidata/shell/aliases.{yaml,toml}` | 5 | Alias data is mostly declarative and can be split from shell-specific render conditions. |

## Wave 2 Candidates (Needs Additional Review)

| Domain | Source Path | Why Deferred |
|---|---|---|
| 1Password field-index mappings | `home/private_dot_config/npm/executable_npmrc.tmpl`, `home/private_dot_config/dotnet/dot_nuget/NuGet/private_NuGet.Config.tmpl`, `home/.chezmoitemplates/exports.tmpl` | Secret-adjacent references and field-index fragility require stricter modeling decisions before centralization. |
| zsh function bodies | `home/.chezmoitemplates/functions.tmpl` | Mixed declarative and imperative logic; migrate only metadata first, not function bodies. |

## Draft Data Shape Conventions
- Domain-first files under `home/dot_chezmoidata/<domain>/...`.
- Stable keys (snake_case) and deterministic ordering for review-friendly diffs.
- Keep secrets and secret retrieval expressions in templates/encrypted files unless explicitly approved.
- Keep profile overlays (`personal`, `transient`, OS) as data attributes where possible.

## Verification Checklist Per Candidate
- `chezmoi execute-template` passes for impacted templates/scripts.
- `chezmoi diff` is limited to expected refactor deltas.
- `chezmoi apply --dry-run` shows no destructive surprises.
- Existing rendered behavior matches baseline for representative machine profiles.
