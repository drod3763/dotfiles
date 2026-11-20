#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

# Black-box tests for home/.chezmoiscripts/windows/run_before_90_bootstrap-age-identities.ps1.tmpl.
# The template is rendered against a throwaway source dir and config, then run in
# a child pwsh whose USERPROFILE (and so $HOME) is a temp folder and whose `op` is
# a stub serving fixture keys. The real keyring and 1Password are never touched.

# Pester runs BeforeAll variables inside the It blocks, which the analyzer cannot
# see, and the New-/Set- helpers only touch the test drive.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in Pester It blocks.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helpers write only to TestDrive.')]
param()

BeforeDiscovery {
  $script:onWindows = $IsWindows
}

Describe 'bootstrap-age-identities' -Skip:(-not $onWindows) {
  BeforeAll {
    $repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel).Trim()
    $template = Join-Path $repoRoot 'home/.chezmoiscripts/windows/run_before_90_bootstrap-age-identities.ps1.tmpl'
    $chezmoi = (Get-Command chezmoi -CommandType Application | Select-Object -First 1).Source
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    $root = Join-Path $TestDrive 'fixture'
    $sourceDir = Join-Path $root 'source'
    $stubDir = Join-Path $root 'stub'
    New-Item -ItemType Directory -Force -Path $sourceDir, $stubDir | Out-Null

    # Serves `op item get <item> ...` from <OP_STUB_DIR>\<item>.txt; a missing
    # file is a failed lookup (op exits nonzero for a missing item or a denied prompt).
    Set-Content -LiteralPath (Join-Path $stubDir 'op.cmd') -Encoding ascii -Value @(
      '@echo off'
      'if exist "%OP_STUB_DIR%\%3.txt" (type "%OP_STUB_DIR%\%3.txt" & exit /b 0)'
      'exit /b 1'
    )

    function New-TestKey([string]$Name) {
      $path = Join-Path $root "$Name.key"
      & $chezmoi age-keygen -o $path 2>$null | Out-Null
      [pscustomobject]@{
        Identity  = (Get-Content -LiteralPath $path | Where-Object { $_ -like 'AGE-SECRET-KEY-*' })
        Recipient = (& $chezmoi age-keygen -y $path).Trim()
      }
    }
    $keyA = New-TestKey 'a'
    $keyB = New-TestKey 'b'
    $keyC = New-TestKey 'c'

    # The two encrypted sources the script verifies, readable with A or B only.
    $encryptConfig = Join-Path $root 'encrypt.toml'
    [IO.File]::WriteAllText($encryptConfig, "encryption = `"age`"`n[age]`n    recipients = [`"$($keyA.Recipient)`", `"$($keyB.Recipient)`"]`n", $utf8)
    $plain = Join-Path $root 'plain.txt'
    [IO.File]::WriteAllText($plain, "secret`n", $utf8)
    foreach ($relative in 'private_dot_ssh/encrypted_config.tmpl.age', 'private_dot_config/private_1Password/private_ssh/encrypted_private_agent.toml.age') {
      $target = Join-Path $sourceDir $relative
      New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
      & $chezmoi --config $encryptConfig --source $sourceDir --persistent-state (Join-Path $root 'encrypt.state') encrypt --output $target $plain
      if ($LASTEXITCODE -ne 0) { throw "Could not encrypt fixture $relative." }
    }

    # Renders the template with two 1Password sources, `age-a` and `age-b`.
    # -WithoutOp renders with a PATH that has no op, as on a machine without the CLI.
    function New-BootstrapScript([switch]$WithoutOp) {
      $data = Join-Path $root 'data.json'
      @{ onepassword = @{
          vaults         = @{ dev = 'vault-id' }
          age_identities = @(@{ item = 'age-a'; vault = 'dev' }, @{ item = 'age-b'; vault = 'dev' })
        }
      } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $data -Encoding utf8
      $config = Join-Path $root 'render.toml'
      [IO.File]::WriteAllText($config, '', $utf8)
      $out = Join-Path $root ($(if ($WithoutOp) { 'bootstrap-noop.ps1' } else { 'bootstrap.ps1' }))
      $savedPath = $env:PATH
      try {
        $env:PATH = if ($WithoutOp) {
          "$(Split-Path $chezmoi);$env:SystemRoot\System32"
        } else {
          "$stubDir;$savedPath"
        }
        $rendered = Get-Content -Raw -LiteralPath $template |
          & $chezmoi --config $config --source $sourceDir --persistent-state (Join-Path $root 'render.state') --override-data-file $data execute-template
        if ($LASTEXITCODE -ne 0) { throw 'Could not render the bootstrap template.' }
      } finally {
        $env:PATH = $savedPath
      }
      [IO.File]::WriteAllText($out, ($rendered -join "`n"), $utf8)
      $out
    }
    $bootstrapScript = New-BootstrapScript
    $noOpScript = New-BootstrapScript -WithoutOp

    # Runs a rendered script for $HomeDir. $Items maps a 1Password item to the
    # credential op returns; items left out fail the lookup.
    function Invoke-Bootstrap([string]$HomeDir, [hashtable]$Items = @{}, [string]$ScriptPath = $bootstrapScript) {
      $itemDir = Join-Path $HomeDir 'op-items'
      Remove-Item -LiteralPath $itemDir -Recurse -Force -ErrorAction SilentlyContinue
      New-Item -ItemType Directory -Force -Path $itemDir | Out-Null
      foreach ($name in $Items.Keys) {
        [IO.File]::WriteAllText((Join-Path $itemDir "$name.txt"), "$($Items[$name])`n", $utf8)
      }
      $psi = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
      foreach ($arg in '-NoProfile', '-NonInteractive', '-File', $ScriptPath) { $psi.ArgumentList.Add($arg) }
      $psi.Environment['USERPROFILE'] = $HomeDir
      $psi.Environment['PATH'] = "$stubDir;$env:PATH"
      $psi.Environment['OP_STUB_DIR'] = $itemDir
      $psi.Environment['CHEZMOI_EXECUTABLE'] = $chezmoi
      $psi.RedirectStandardError = $true
      $psi.RedirectStandardOutput = $true
      $process = [Diagnostics.Process]::Start($psi)
      $stderr = $process.StandardError.ReadToEndAsync()
      $null = $process.StandardOutput.ReadToEnd()
      $process.WaitForExit()
      [pscustomobject]@{ ExitCode = $process.ExitCode; Log = $stderr.Result }
    }

    function Get-KeyText([string[]]$Lines) { ($Lines -join "`n") + "`n" }
    $pairItems = @{ 'age-a' = $keyA.Identity; 'age-b' = $keyB.Identity }
    $identitiesText = Get-KeyText $keyA.Identity, $keyB.Identity
    $recipientsText = Get-KeyText $keyA.Recipient, $keyB.Recipient

    function Get-AgeDir([string]$HomeDir) { Join-Path $HomeDir '.config\chezmoi\age-identities' }
    function Set-KeyFile([string]$HomeDir, [string]$Name, [string]$Text, [Text.Encoding]$Encoding = $utf8) {
      $dir = Get-AgeDir $HomeDir
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
      [IO.File]::WriteAllText((Join-Path $dir $Name), $Text, $Encoding)
    }
    function Get-KeyFileBase64([string]$HomeDir, [string]$Name) {
      [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path (Get-AgeDir $HomeDir) $Name)))
    }
    function ConvertTo-Base64([string]$Text) { [Convert]::ToBase64String($utf8.GetBytes($Text)) }
    function Get-Leftover([string]$HomeDir) {
      @(Get-ChildItem -LiteralPath (Get-AgeDir $HomeDir) -Force -File |
          Where-Object { $_.Name -like '*.partial' -or $_.Name -like '*.bak' } |
          ForEach-Object Name)
    }
    $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    function Test-OwnerOnly([string]$Path) {
      $acl = Get-Acl -LiteralPath $Path
      $sids = @($acl.Access | ForEach-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]) })
      $acl.AreAccessRulesProtected -and $sids.Count -gt 0 -and -not ($sids | Where-Object { $_ -ne $userSid })
    }
  }

  BeforeEach {
    $homeDir = Join-Path $TestDrive "home-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Force -Path $homeDir | Out-Null
  }

  Context 'with no keyring' {
    It 'writes both keys from 1Password as UTF-8 LF files restricted to the user' {
      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      Get-KeyFileBase64 $homeDir 'identities.txt' | Should -Be (ConvertTo-Base64 $identitiesText)
      Get-KeyFileBase64 $homeDir 'recipients.txt' | Should -Be (ConvertTo-Base64 $recipientsText)
      Get-Leftover $homeDir | Should -BeNullOrEmpty
      Test-OwnerOnly (Get-AgeDir $homeDir) | Should -BeTrue
    }

    It 'fails without writing when a 1Password lookup fails' {
      $result = Invoke-Bootstrap $homeDir @{ 'age-a' = $keyA.Identity }

      $result.ExitCode | Should -Be 1
      $result.Log | Should -Match '1 of 2 source\(s\) failed \(age-b:vault-id\)'
      Join-Path (Get-AgeDir $homeDir) 'identities.txt' | Should -Not -Exist
    }

    It 'fails without writing when the 1Password keys cannot decrypt the files' {
      $result = Invoke-Bootstrap $homeDir @{ 'age-a' = $keyC.Identity; 'age-b' = $keyC.Identity }

      $result.ExitCode | Should -Be 1
      $result.Log | Should -Match 'cannot decrypt the managed files'
      Join-Path (Get-AgeDir $homeDir) 'identities.txt' | Should -Not -Exist
      Get-Leftover $homeDir | Should -BeNullOrEmpty
    }
  }

  Context 'with a working keyring' {
    BeforeEach {
      Set-KeyFile $homeDir 'identities.txt' $identitiesText
      Set-KeyFile $homeDir 'recipients.txt' $recipientsText
    }

    It 'leaves files in sync with 1Password unwritten' {
      $files = 'identities.txt', 'recipients.txt' | ForEach-Object { Join-Path (Get-AgeDir $homeDir) $_ }
      $files | ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc = [datetime]'2020-01-01' }

      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      $files | ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc | Should -Be ([datetime]'2020-01-01') }
    }

    It 'keeps the keyring and continues when a 1Password lookup fails' {
      $result = Invoke-Bootstrap $homeDir @{ 'age-a' = $keyA.Identity }

      $result.ExitCode | Should -Be 0
      $result.Log | Should -Match 'still decrypt the managed files'
      Get-KeyFileBase64 $homeDir 'identities.txt' | Should -Be (ConvertTo-Base64 $identitiesText)
    }

    It 'treats a credential that is not an age key as a failed lookup' {
      $result = Invoke-Bootstrap $homeDir @{ 'age-a' = $keyA.Identity; 'age-b' = 'not-a-key' }

      $result.ExitCode | Should -Be 0
      $result.Log | Should -Match 'age-b:vault-id is not a valid age identity'
      Get-KeyFileBase64 $homeDir 'identities.txt' | Should -Be (ConvertTo-Base64 $identitiesText)
    }

    It 'keeps the keyring when the 1Password keys cannot decrypt the files' {
      $result = Invoke-Bootstrap $homeDir @{ 'age-a' = $keyC.Identity; 'age-b' = $keyC.Identity }

      $result.ExitCode | Should -Be 0
      $result.Log | Should -Match 'cannot decrypt the managed files'
      Get-KeyFileBase64 $homeDir 'identities.txt' | Should -Be (ConvertTo-Base64 $identitiesText)
      Get-KeyFileBase64 $homeDir 'recipients.txt' | Should -Be (ConvertTo-Base64 $recipientsText)
      Get-Leftover $homeDir | Should -BeNullOrEmpty
    }

    It 'removes backups and scratch files an interrupted run left behind' {
      Set-KeyFile $homeDir 'identities.txt.bak' (Get-KeyText $keyC.Identity)
      Set-KeyFile $homeDir 'recipients.txt.bak' (Get-KeyText $keyC.Recipient)
      Set-KeyFile $homeDir 'identities.txt.partial' (Get-KeyText $keyC.Identity)

      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      Get-Leftover $homeDir | Should -BeNullOrEmpty
    }

    It 'restricts files with wider access, hidden ones included' {
      $hidden = Join-Path (Get-AgeDir $homeDir) 'hidden.txt'
      [IO.File]::WriteAllText($hidden, 'x', $utf8)
      (Get-Item -LiteralPath $hidden).Attributes = 'Hidden'
      $acl = Get-Acl -LiteralPath $hidden
      $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'Read', 'Allow')))
      Set-Acl -LiteralPath $hidden -AclObject $acl

      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      Test-OwnerOnly $hidden | Should -BeTrue
      Test-OwnerOnly (Join-Path (Get-AgeDir $homeDir) 'identities.txt') | Should -BeTrue
    }
  }

  Context 'with a keyring that differs from 1Password' {
    It 'rewrites a UTF-16 CRLF copy to the exact bytes' {
      Set-KeyFile $homeDir 'identities.txt' ($identitiesText -replace "`n", "`r`n") ([Text.Encoding]::Unicode)
      Set-KeyFile $homeDir 'recipients.txt' $recipientsText

      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      Get-KeyFileBase64 $homeDir 'identities.txt' | Should -Be (ConvertTo-Base64 $identitiesText)
      Get-Leftover $homeDir | Should -BeNullOrEmpty
    }

    It 'drops a key rotated out of 1Password' {
      Set-KeyFile $homeDir 'identities.txt' (Get-KeyText $keyA.Identity, $keyB.Identity, $keyC.Identity)
      Set-KeyFile $homeDir 'recipients.txt' (Get-KeyText $keyA.Recipient, $keyB.Recipient, $keyC.Recipient)

      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      Get-KeyFileBase64 $homeDir 'identities.txt' | Should -Be (ConvertTo-Base64 $identitiesText)
      Get-KeyFileBase64 $homeDir 'recipients.txt' | Should -Be (ConvertTo-Base64 $recipientsText)
      Get-Leftover $homeDir | Should -BeNullOrEmpty
    }

    It 'repairs a missing recipients file' {
      Set-KeyFile $homeDir 'identities.txt' $identitiesText

      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      Get-KeyFileBase64 $homeDir 'recipients.txt' | Should -Be (ConvertTo-Base64 $recipientsText)
    }

    It 'replaces a keyring that no longer decrypts' {
      Set-KeyFile $homeDir 'identities.txt' (Get-KeyText $keyC.Identity)
      Set-KeyFile $homeDir 'recipients.txt' (Get-KeyText $keyC.Recipient)

      $result = Invoke-Bootstrap $homeDir $pairItems

      $result.ExitCode | Should -Be 0 -Because $result.Log
      Get-KeyFileBase64 $homeDir 'identities.txt' | Should -Be (ConvertTo-Base64 $identitiesText)
    }
  }

  Context 'rendered without op on PATH' {
    It 'keeps an existing keyring' {
      Set-KeyFile $homeDir 'identities.txt' $identitiesText

      $result = Invoke-Bootstrap $homeDir $pairItems -ScriptPath $noOpScript

      $result.ExitCode | Should -Be 0
      $result.Log | Should -Match 'op\) is not on PATH; keeping the existing identities'
    }

    It 'fails with instructions when there is no keyring' {
      $result = Invoke-Bootstrap $homeDir $pairItems -ScriptPath $noOpScript

      $result.ExitCode | Should -Be 1
      $result.Log | Should -Match 'winget AgileBits.1Password.CLI'
    }
  }
}
