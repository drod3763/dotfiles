## Tasks
1. Inventory all `onepassword` usages across the repository using search tooling
2. For each unique item ID, identify the owning vault in 1Password
3. Group usages by vault where applicable
4. Update templates to include the correct vault ID as the second argument
5. Validate templates with `chezmoi execute-template`
6. Run `chezmoi diff` to confirm no unintended output changes
7. Apply and test on a machine authenticated via service account

## Validation
- All templates render successfully under service account auth
- No `op` CLI errors related to missing vault context
