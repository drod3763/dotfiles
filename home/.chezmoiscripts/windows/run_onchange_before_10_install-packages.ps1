# Windows packages. Named 10_ so it runs before 90_bootstrap-age-identities,
# which needs op. A failed install exits non-zero so chezmoi does not record
# this run_onchange script as done and the next apply retries it.
$ErrorActionPreference = 'Stop'

# winget's "a package version is already installed" result under --no-upgrade.
$alreadyInstalled = 0x8A150061 -bor 0
$failed = New-Object System.Collections.Generic.List[string]

function Install-WingetPackage([string]$Id) {
  & winget install --id $Id --exact --no-upgrade --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $alreadyInstalled) {
    [Console]::Error.WriteLine("winget install $Id failed (exit $LASTEXITCODE).")
    $failed.Add($Id)
  }
}

Install-WingetPackage 'gerardog.gsudo'
# 1Password CLI (op): age identity bootstrap and the onepassword template lookups.
Install-WingetPackage 'AgileBits.1Password.CLI'
# mise provides the repo's hook linters (gitleaks, shellcheck) via mise.toml.
Install-WingetPackage 'jdx.mise'

# PSScriptAnalyzer is a PowerShell module, so mise cannot manage it; the
# pre-commit hook uses it to lint the Windows chezmoi scripts.
if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
  Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
}

if ($failed.Count -gt 0) {
  throw "Package install failed: $($failed -join ', '). Re-run chezmoi apply to retry."
}
