## MODIFIED Requirements

### Requirement: Explicit Vault Context for onepassword

All usages of the chezmoi `onepassword` template function MUST specify an explicit vault identifier when retrieving items from 1Password.

#### Scenario: Service account execution
Given a system authenticated to 1Password using a service account,
When `chezmoi execute-template` or `chezmoi apply` is run,
Then all `onepassword` calls succeed without relying on implicit or default vault resolution.
