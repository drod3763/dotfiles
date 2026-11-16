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

# The drive letter alone can lie: a subst drive or a junction on E: can point
# back at C:. Resolve both paths to their backing volume GUID and compare those.
# Any failure to resolve stops the script rather than guessing.
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class InventoryVolume {
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);

  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle, StringBuilder buffer, uint length, uint flags);

  // Returns the \\?\Volume{GUID}\... path, after following subst drives and reparse points.
  public static string FinalVolumePath(string path) {
    const uint ShareAll = 7, OpenExisting = 3, BackupSemantics = 0x02000000, VolumeNameGuid = 1;
    using (SafeFileHandle handle = CreateFileW(path, 0, ShareAll, IntPtr.Zero, OpenExisting, BackupSemantics, IntPtr.Zero)) {
      if (handle.IsInvalid) throw new Win32Exception();
      StringBuilder buffer = new StringBuilder(4096);
      uint length = GetFinalPathNameByHandleW(handle, buffer, (uint)buffer.Capacity, VolumeNameGuid);
      if (length == 0 || length >= buffer.Capacity) throw new Win32Exception();
      return buffer.ToString();
    }
  }
}
'@

function Get-VolumeGuid([string]$Path) {
  $final = [InventoryVolume]::FinalVolumePath($Path)
  if ($final -notmatch '^\\\\\?\\Volume\{[0-9a-fA-F-]+\}') { throw "could not resolve the volume for '$Path' (got '$final')" }
  $Matches[0]
}

try {
  $outVolume = Get-VolumeGuid (Resolve-Path -LiteralPath $OutDir).ProviderPath
  $systemVolume = Get-VolumeGuid "$env:SystemDrive\"
} catch {
  throw "Could not confirm that '$OutDir' is off the system drive: $($_.Exception.Message)"
}
if ($outVolume -ieq $systemVolume) {
  throw "OutDir '$OutDir' resolves to the system drive ($env:SystemDrive) through a mapped drive or junction. Pick a folder on another disk."
}
Write-Step "Writing reports to $OutDir"

Invoke-Step 'Measuring user profile folders' {
  # Unreadable folders are counted, not hidden: a size that skipped part of a
  # folder is marked incomplete and every unreadable path is written out.
  $unreadable = New-Object System.Collections.Generic.List[string]
  $topErrors = $null
  $folders = Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue -ErrorVariable topErrors
  foreach ($err in @($topErrors)) { if ($err) { $unreadable.Add("$($err.TargetObject): $($err.Exception.Message)") } }

  $rows = foreach ($folder in $folders) {
    $scanErrors = $null
    $bytes = [double](Get-ChildItem -LiteralPath $folder.FullName -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable scanErrors |
      Measure-Object -Property Length -Sum).Sum
    $scanErrors = @($scanErrors | Where-Object { $_ })
    foreach ($err in $scanErrors) { $unreadable.Add("$($err.TargetObject): $($err.Exception.Message)") }
    [pscustomobject]@{
      Folder     = $folder.Name
      GB         = [math]::Round($bytes / 1GB, 2)
      Unreadable = $scanErrors.Count
      Note       = if ($scanErrors.Count) { 'incomplete: size is a minimum' } else { '' }
    }
  }
  $rows | Sort-Object GB -Descending | Format-Table -AutoSize |
    Out-File -FilePath (Join-Path $OutDir 'home-sizes.txt') -Width 200

  $unreadablePath = Join-Path $OutDir 'home-unreadable.txt'
  if ($unreadable.Count) {
    $unreadable | Out-File -FilePath $unreadablePath -Width 400
    throw "$($unreadable.Count) path(s) could not be read; sizes are minimums. See home-unreadable.txt"
  }
  Remove-Item -LiteralPath $unreadablePath -Force -ErrorAction SilentlyContinue
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
  $regErrors = $null
  $entries = Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue -ErrorVariable regErrors
  # A missing Uninstall key (common for HKCU) is fine; anything else is a
  # failed read that would silently drop apps from the list.
  $readFailures = @($regErrors | Where-Object {
      $_ -and -not ($_.Exception -is [System.Management.Automation.ItemNotFoundException]) })
  $csvPath = Join-Path $OutDir 'installed-apps.csv'
  $entries |
    Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName } |
    Select-Object DisplayName,
      @{ n = 'DisplayVersion'; e = { if ($_.PSObject.Properties['DisplayVersion']) { $_.DisplayVersion } } },
      @{ n = 'InstallLocation'; e = { if ($_.PSObject.Properties['InstallLocation']) { $_.InstallLocation } } },
      @{ n = 'Scope'; e = {
          if ($_.PSPath -match 'HKEY_CURRENT_USER') { 'user' }
          elseif ($_.PSPath -match 'WOW6432Node') { 'machine-32bit' }
          else { 'machine' } } } |
    # Deduplicate on the whole identity so side-by-side versions and
    # per-user/machine installs of the same app each keep a row.
    Sort-Object DisplayName, DisplayVersion, InstallLocation, Scope -Unique |
    Export-Csv -Path $csvPath -NoTypeInformation

  $failurePath = Join-Path $OutDir 'installed-apps-unreadable.txt'
  if ($readFailures.Count) {
    $readFailures | ForEach-Object { "$($_.TargetObject): $($_.Exception.Message)" } |
      Out-File -FilePath $failurePath -Width 400
    throw "$($readFailures.Count) registry key(s) could not be read; installed-apps.csv is incomplete. See installed-apps-unreadable.txt"
  }
  Remove-Item -LiteralPath $failurePath -Force -ErrorAction SilentlyContinue
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

# Exit nonzero when any step failed so callers can't mistake a partial
# inventory for a complete one.
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
