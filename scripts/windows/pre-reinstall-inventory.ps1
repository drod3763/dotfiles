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
    installed-apps.csv  Every installed desktop app, with its install location
    store-apps.csv      Store and MSIX packages (not in the Uninstall registry)
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

# 32-bit PowerShell on 64-bit Windows sees a redirected registry and would
# silently miss 64-bit apps, so refuse to run there.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
  throw 'This is 32-bit PowerShell on 64-bit Windows. Run it from 64-bit PowerShell (C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe).'
}

# Network paths have no local volume to compare against, so refuse them up front.
if ($OutDir -match '^(\\\\|//)') {
  throw "OutDir '$OutDir' is a network path. Pick a folder on a local disk that survives the reinstall."
}
# Resolve relative paths (.\inventory) against the current directory before any checks.
$OutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
$outRoot = Split-Path -Qualifier $OutDir
if ($outRoot -ieq $env:SystemDrive) {
  throw "OutDir '$OutDir' is on the system drive ($env:SystemDrive), which the reinstall wipes. Pick a folder on another disk."
}

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

# Check the deepest folder that already exists, so a junction or subst drive
# pointing at C: is refused before anything is created there.
$existing = $OutDir
while ($existing -and -not (Test-Path -LiteralPath $existing)) { $existing = Split-Path -Parent $existing }
try {
  if (-not $existing) { throw "no part of the path exists (is drive $outRoot attached?)" }
  $outVolume = Get-VolumeGuid (Resolve-Path -LiteralPath $existing).ProviderPath
  $systemVolume = Get-VolumeGuid "$env:SystemDrive\"
} catch {
  throw "Could not confirm that '$OutDir' is off the system drive: $($_.Exception.Message)"
}
if ($outVolume -ieq $systemVolume) {
  throw "OutDir '$OutDir' resolves to the system drive ($env:SystemDrive) through a mapped drive or junction. Pick a folder on another disk."
}
# The elevated process reads $env:USERPROFILE, HKCU and winget's user scope.
# If UAC elevated as a different admin account, those belong to that account.
# This runs before anything is written, so a wrong-account run can't overwrite
# a good inventory from an earlier run.
Write-Step 'Checking which account is being inventoried'
$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
try {
  $owners = @(Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop |
      ForEach-Object { $o = Invoke-CimMethod -InputObject $_ -MethodName GetOwner -ErrorAction Stop; if ($o.User) { "$($o.Domain)\$($o.User)" } } |
      Sort-Object -Unique)
} catch {
  throw "Could not confirm which account is signed in: $($_.Exception.Message)"
}
if ($owners.Count -eq 0) { throw "No desktop session found; can't confirm '$me' is the signed-in user." }
if ($owners -notcontains $me) {
  throw "Running as '$me' but the desktop belongs to '$($owners -join "', '")'. Profile, HKCU and winget reports would describe '$me'. Elevate with the same account (gsudo)."
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
# Hold an exclusive lock on OutDir for the whole run, so a second run can't
# overwrite reports or swap driver folders underneath this one. Windows
# releases it, and deletes the file, when this process exits.
$lockPath = Join-Path $OutDir '.inventory.lock'
try {
  $script:outDirLock = New-Object IO.FileStream($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 1, [IO.FileOptions]::DeleteOnClose)
} catch {
  throw "Another inventory run is already writing to '$OutDir'. Wait for it to finish, or pick a different -OutDir."
}
Write-Step "Writing reports to $OutDir"

# Walks a folder without entering junctions or symlinks. Windows PowerShell 5.1
# follows them on -Recurse, which double-counts linked folders and hits the
# deny-listed compatibility junctions (My Music, Application Data, ...).
# Cloud-only files (OneDrive placeholders) report their full size but use no
# disk, so they're totalled separately.
# Only junctions and symlinks count as links. OneDrive placeholders and other
# reparse points (cloud files, dedup) carry the ReparsePoint attribute too but
# hold real data, so they're walked and measured.
function Test-IsLink($Item) {
  ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and ($Item.LinkType -in 'Junction', 'SymbolicLink')
}

# Compatibility junctions (hidden + system, e.g. Application Data) are Windows
# plumbing that point back inside the profile.
function Test-IsCompatJunction($Item) {
  ($Item.Attributes -band [IO.FileAttributes]::Hidden) -and ($Item.Attributes -band [IO.FileAttributes]::System)
}

function Remove-LongPathPrefix([string]$Path) {
  $Path -replace '^\\\\\?\\UNC\\', '\\' -replace '^\\\\\?\\', ''
}

# Links aren't followed, but links you made are written to $Links with their
# target so data they point at (e.g. Documents\Projects -> D:\Projects) isn't missed.
function Measure-Tree([string]$Path, [System.Collections.Generic.List[string]]$Errors, [System.Collections.Generic.List[string]]$Links) {
  $cloudOnly = 0x400000 -bor [int][IO.FileAttributes]::Offline  # FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS | Offline
  $result = [pscustomobject]@{ Bytes = 0.0; CloudBytes = 0.0; Errors = 0; Links = 0 }
  # Windows PowerShell 5.1 can't list folders past MAX_PATH (260) unless
  # LongPathsEnabled is set; a \\?\ prefix bypasses that, and child FullNames keep it.
  if ($Path -match '^\\\\\?\\') { $root = $Path }
  elseif ($Path -match '^\\\\') { $root = '\\?\UNC\' + $Path.Substring(2) }
  else { $root = '\\?\' + $Path }
  $stack = New-Object System.Collections.Generic.Stack[string]
  $stack.Push($root)
  while ($stack.Count) {
    $dir = $stack.Pop()
    $errs = $null
    # @() so an empty folder gives an empty list, not one $null item.
    $items = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue -ErrorVariable errs)
    foreach ($e in @($errs)) {
      if ($e) {
        $Errors.Add("$(Remove-LongPathPrefix "$($e.TargetObject)"): $($e.Exception.Message)"); $result.Errors++
      }
    }
    foreach ($i in $items) {
      if (Test-IsLink $i) {
        if (-not (Test-IsCompatJunction $i)) {
          try { $target = @($i.Target) -join ', ' } catch { $target = '(target unreadable)' }
          $Links.Add("$(Remove-LongPathPrefix $i.FullName) -> $target"); $result.Links++
        }
        continue
      }
      if ($i.PSIsContainer) { $stack.Push($i.FullName) }
      elseif ([int]$i.Attributes -band $cloudOnly) { $result.CloudBytes += $i.Length }
      else { $result.Bytes += $i.Length }
    }
  }
  $result
}

Invoke-Step 'Measuring user profile folders' {
  # Unreadable folders are counted, not hidden: a size that skipped part of a
  # folder is marked incomplete and every unreadable path is written out.
  $unreadable = New-Object System.Collections.Generic.List[string]
  $links = New-Object System.Collections.Generic.List[string]
  $topErrors = $null
  $folders = @(Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue -ErrorVariable topErrors)
  foreach ($err in @($topErrors)) { if ($err) { $unreadable.Add("$($err.TargetObject): $($err.Exception.Message)") } }

  $rows = foreach ($folder in $folders) {
    if (Test-IsLink $folder) {
      # A link you made yourself is listed with its target so the real data isn't missed.
      if (Test-IsCompatJunction $folder) { continue }
      # The table truncates long values, so the full target goes in home-links.txt.
      try { $target = @($folder.Target) -join ', ' } catch { $target = '(target unreadable)' }
      $links.Add("$($folder.FullName) -> $target")
      [pscustomobject]@{ Folder = $folder.Name; GB = 0; CloudOnlyGB = 0; Unreadable = 0; Note = 'link, not counted, see home-links.txt' }
      continue
    }
    $size = Measure-Tree $folder.FullName $unreadable $links
    $notes = @()
    if ($size.Errors) { $notes += 'incomplete: size is a minimum' }
    if ($size.Links) { $notes += "$($size.Links) link(s) not counted, see home-links.txt" }
    if ($size.CloudBytes) { $notes += 'has cloud-only files' }
    [pscustomobject]@{
      Folder      = $folder.Name
      GB          = [math]::Round($size.Bytes / 1GB, 2)
      CloudOnlyGB = [math]::Round($size.CloudBytes / 1GB, 2)
      Unreadable  = $size.Errors
      Note        = $notes -join '; '
    }
  }
  $rows | Sort-Object GB -Descending | Format-Table -AutoSize |
    Out-File -Encoding UTF8 -FilePath (Join-Path $OutDir 'home-sizes.txt') -Width 200

  $linksPath = Join-Path $OutDir 'home-links.txt'
  if ($links.Count) { $links | Out-File -Encoding UTF8 -FilePath $linksPath -Width 400 }
  else { Remove-Item -LiteralPath $linksPath -Force -ErrorAction SilentlyContinue }

  $unreadablePath = Join-Path $OutDir 'home-unreadable.txt'
  if ($unreadable.Count) {
    $unreadable | Out-File -Encoding UTF8 -FilePath $unreadablePath -Width 400
    throw "$($unreadable.Count) path(s) could not be read; sizes are minimums. See home-unreadable.txt"
  }
  Remove-Item -LiteralPath $unreadablePath -Force -ErrorAction SilentlyContinue
}

Invoke-Step 'Recording shell folder locations' {
  Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' |
    Out-File -Encoding UTF8 -FilePath (Join-Path $OutDir 'shell-folders.txt') -Width 300
}

Invoke-Step 'Exporting winget app list' {
  # Write to a temp file and replace winget.json only on success, so a failed
  # rerun can't leave an older export looking current.
  $target = Join-Path $OutDir 'winget.json'
  $temp = "$target.tmp"
  $staleNote = {
    if (Test-Path -LiteralPath $target) {
      $stamp = (Get-Item -LiteralPath $target).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
      "; kept the previous winget.json from $stamp (stale)"
    }
  }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget is not installed$(& $staleNote)" }
  Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
  winget export -o $temp --include-versions --accept-source-agreements | Out-Null
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $temp)) {
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    throw "winget export exited with code $exitCode$(& $staleNote)"
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
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

  $failurePath = Join-Path $OutDir 'installed-apps-unreadable.txt'
  if ($readFailures.Count) {
    $readFailures | ForEach-Object { "$($_.TargetObject): $($_.Exception.Message)" } |
      Out-File -Encoding UTF8 -FilePath $failurePath -Width 400
    throw "$($readFailures.Count) registry key(s) could not be read; installed-apps.csv is incomplete. See installed-apps-unreadable.txt"
  }
  Remove-Item -LiteralPath $failurePath -Force -ErrorAction SilentlyContinue
}

Invoke-Step 'Listing Store and MSIX apps' {
  # Store and sideloaded packages don't appear in the Uninstall registry keys,
  # so they get their own report. -AllUsers needs an elevated shell.
  $appxErrors = $null
  $packages = if ($isAdmin) {
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue -ErrorVariable appxErrors
  } else {
    Get-AppxPackage -ErrorAction SilentlyContinue -ErrorVariable appxErrors
  }
  $packages |
    Select-Object Name, Version, Architecture, Publisher, PackageFamilyName, PackageFullName, SignatureKind, IsFramework, InstallLocation |
    # PackageFullName includes the architecture, so x64/x86/arm64 copies of a
    # framework each keep their row.
    Sort-Object PackageFullName -Unique |
    Export-Csv -Path (Join-Path $OutDir 'store-apps.csv') -NoTypeInformation -Encoding UTF8
  $appxErrors = @($appxErrors | Where-Object { $_ })
  if ($appxErrors.Count) {
    throw "$($appxErrors.Count) package(s) could not be read; store-apps.csv is incomplete: $($appxErrors[0].Exception.Message)"
  }
  if (-not $isAdmin) { throw 'listed only your own packages; run elevated (gsudo) to include all users' }
}

Invoke-Step 'Recording activation status' {
  $output = cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli
  $output | Out-File -Encoding UTF8 -FilePath (Join-Path $OutDir 'activation.txt')
  Assert-NativeSuccess 'slmgr /dli'
}

Invoke-Step 'Exporting third-party drivers' {
  if (-not $isAdmin) { throw 'needs an elevated shell (run with gsudo)' }
  # Export into a fresh folder and swap it in on success, so drivers from an
  # earlier run never mix with this one and a failed run keeps the old export.
  # The old export is set aside as drivers.old and only deleted once the new
  # one is in place, so an interrupted swap never loses both.
  $driverDir = Join-Path $OutDir 'drivers'
  $tempDir = Join-Path $OutDir 'drivers.tmp'
  $oldDir = Join-Path $OutDir 'drivers.old'
  if (Test-Path -LiteralPath $oldDir) {
    # Left by an interrupted swap: bring it back if drivers is missing, else it's stale.
    if (Test-Path -LiteralPath $driverDir) { Remove-Item -LiteralPath $oldDir -Recurse -Force }
    else { Rename-Item -LiteralPath $oldDir -NewName 'drivers' }
  }
  if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
  New-Item -ItemType Directory -Path $tempDir | Out-Null
  try {
    Export-WindowsDriver -Online -Destination $tempDir | Out-Null
  } catch {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }
  $hadOld = Test-Path -LiteralPath $driverDir
  if ($hadOld) { Rename-Item -LiteralPath $driverDir -NewName 'drivers.old' }
  try {
    Rename-Item -LiteralPath $tempDir -NewName 'drivers'
  } catch {
    if ($hadOld) { Rename-Item -LiteralPath $oldDir -NewName 'drivers' -ErrorAction SilentlyContinue }
    throw "couldn't swap in the new export, kept the previous one: $($_.Exception.Message)"
  }
  if ($hadOld) { Remove-Item -LiteralPath $oldDir -Recurse -Force }
}

Invoke-Step 'Listing WSL distros' {
  if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { throw 'WSL is not installed' }
  # wsl.exe writes UTF-16 unless WSL_UTF8=1, so force UTF-8 and decode it as
  # UTF-8. That works whatever the user's environment already sets.
  $previous = [Console]::OutputEncoding
  $previousWslUtf8 = $env:WSL_UTF8
  try {
    $env:WSL_UTF8 = '1'
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    # No 2>&1: in 5.1 with ErrorActionPreference Stop, redirected stderr from a
    # native command becomes a terminating error. Exit code is checked instead.
    $output = wsl --list --verbose
    $exitCode = $LASTEXITCODE
    $output | Out-File -Encoding UTF8 -FilePath (Join-Path $OutDir 'wsl.txt')
    if ($exitCode -ne 0) { throw "wsl --list exited with code $exitCode (no distros installed, or WSL is broken)" }
  } finally {
    [Console]::OutputEncoding = $previous
    $env:WSL_UTF8 = $previousWslUtf8
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
