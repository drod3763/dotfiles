# Just starting a file here....
winget install gerardog.gsudo
# mise provides the repo's hook linters (gitleaks, shellcheck) via mise.toml.
winget install jdx.mise

# PSScriptAnalyzer is a PowerShell module, so mise cannot manage it; the
# pre-commit hook uses it to lint the Windows chezmoi scripts.
if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
  Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
}
