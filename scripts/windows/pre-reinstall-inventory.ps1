#Requires -Version 5.1
<#
.SYNOPSIS
  Read-only inventory of a Windows install before wiping it.

.DESCRIPTION
  Writes reports about what lives on C: to an output folder (default E:\pre-reinstall),
  which should be on a disk that survives the reinstall. Nothing on the system is changed.

  Reports:
    home-sizes.txt      Size of each folder in your user profile
    shell-folders.txt   Where Desktop/Documents/Downloads etc. point
    winget.json         Apps winget can reinstall (winget import -i winget.json)
    installed-apps.csv  Every installed app, with its install location
    activation.txt      How Windows is activated (digital license vs. product key)
    drivers\            Third-party drivers (admin only)
    wsl.txt             WSL distros

.EXAMPLE
  gsudo powershell -ExecutionPolicy Bypass -File .\pre-reinstall-inventory.ps1
  gsudo powershell -ExecutionPolicy Bypass -File .\pre-reinstall-inventory.ps1 -OutDir D:\inventory
#>
[CmdletBinding()]
param(
  [string]$OutDir = 'E:\pre-reinstall'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "[inventory] $Message" -ForegroundColor Cyan
}

function Invoke-Step([string]$Name, [scriptblock]$Action) {
  Write-Step $Name
  try {
    & $Action
  } catch {
    Write-Warning "${Name} failed: $($_.Exception.Message)"
    $script:failures += $Name
  }
}

# Windows PowerShell 5.1 does not throw when a native command exits nonzero,
# so every native call checks $LASTEXITCODE through this helper.
function Assert-NativeSuccess([string]$Command) {
  if ($LASTEXITCODE -ne 0) { throw "$Command exited with code $LASTEXITCODE" }
}

$script:failures = @()
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)

$outRoot = Split-Path -Qualifier $OutDir
if ($outRoot -ieq $env:SystemDrive) {
  throw "OutDir '$OutDir' is on the system drive ($env:SystemDrive), which the reinstall wipes. Pick a folder on another disk."
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Step "Writing reports to $OutDir"

Invoke-Step 'Measuring user profile folders' {
  Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
    ForEach-Object {
      $bytes = [double](Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
      [pscustomobject]@{ Folder = $_.Name; GB = [math]::Round($bytes / 1GB, 2) }
    } |
    Sort-Object GB -Descending |
    Format-Table -AutoSize |
    Out-File -FilePath (Join-Path $OutDir 'home-sizes.txt') -Width 200
}

Invoke-Step 'Recording shell folder locations' {
  Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' |
    Out-File -FilePath (Join-Path $OutDir 'shell-folders.txt') -Width 300
}

Invoke-Step 'Exporting winget app list' {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'winget is not installed' }
  # Write to a temp file and replace winget.json only on success, so a failed
  # rerun can't leave an older export looking current.
  $target = Join-Path $OutDir 'winget.json'
  $temp = "$target.tmp"
  Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
  winget export -o $temp --include-versions --accept-source-agreements | Out-Null
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $temp)) {
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    $message = "winget export exited with code $exitCode"
    if (Test-Path -LiteralPath $target) {
      $stamp = (Get-Item -LiteralPath $target).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
      $message += "; kept the previous winget.json from $stamp (stale)"
    }
    throw $message
  }
  Move-Item -LiteralPath $temp -Destination $target -Force
}

Invoke-Step 'Listing installed apps' {
  $keys = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName } |
    Select-Object DisplayName,
      @{ n = 'DisplayVersion'; e = { if ($_.PSObject.Properties['DisplayVersion']) { $_.DisplayVersion } } },
      @{ n = 'InstallLocation'; e = { if ($_.PSObject.Properties['InstallLocation']) { $_.InstallLocation } } } |
    Sort-Object DisplayName -Unique |
    Export-Csv -Path (Join-Path $OutDir 'installed-apps.csv') -NoTypeInformation
}

Invoke-Step 'Recording activation status' {
  $output = cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli
  $output | Out-File -FilePath (Join-Path $OutDir 'activation.txt')
  Assert-NativeSuccess 'slmgr /dli'
}

Invoke-Step 'Exporting third-party drivers' {
  if (-not $isAdmin) { throw 'needs an elevated shell (run with gsudo)' }
  $driverDir = Join-Path $OutDir 'drivers'
  New-Item -ItemType Directory -Force -Path $driverDir | Out-Null
  Export-WindowsDriver -Online -Destination $driverDir | Out-Null
}

Invoke-Step 'Listing WSL distros' {
  if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { throw 'WSL is not installed' }
  # wsl.exe writes UTF-16; let PowerShell decode it.
  $previous = [Console]::OutputEncoding
  try {
    [Console]::OutputEncoding = [Text.Encoding]::Unicode
    # No 2>&1: in 5.1 with ErrorActionPreference Stop, redirected stderr from a
    # native command becomes a terminating error. Exit code is checked instead.
    $output = wsl --list --verbose
    $exitCode = $LASTEXITCODE
    $output | Out-File -FilePath (Join-Path $OutDir 'wsl.txt')
    if ($exitCode -ne 0) { throw "wsl --list exited with code $exitCode (no distros installed, or WSL is broken)" }
  } finally {
    [Console]::OutputEncoding = $previous
  }
}

Write-Host ''
if ($script:failures.Count -eq 0) {
  Write-Step "Done. Reports are in $OutDir"
} else {
  Write-Step "Done with $($script:failures.Count) skipped step(s): $($script:failures -join ', ')"
}
Write-Step 'Send home-sizes.txt, shell-folders.txt and activation.txt for review.'
