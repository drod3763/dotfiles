## Tasks
- [ ] 1. Define and document candidate-selection heuristics for `chezmoidata` migration (duplication, reuse breadth, volatility, and sensitivity boundaries).
- [ ] 2. Produce a baseline inventory of current templates/scripts and classify candidates by domain and migration priority.
- [ ] 3. Define canonical `chezmoidata` file layout, key naming conventions, and schema expectations for the first migration wave.
- [ ] 4. Create an incremental migration plan with explicit phase boundaries and rollback guidance.
- [ ] 5. Document verification workflow for each migration phase (`chezmoi execute-template`, `chezmoi diff`, `chezmoi apply --dry-run`).

## Validation
- Inventory report lists candidate paths with priority and rationale.
- First-wave domain selection is deterministic and reviewable.
- Migration phases include clear pass/fail checks and rollback steps.
- Safety workflow keeps apply preview-first behavior intact.
