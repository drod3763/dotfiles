function Test-IsElevated {
  return (New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()))
    .IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ((Test-IsElevated) -eq $false) {
  Write-Warning "This script requires local admin privileges. Elevating..."
  gsudo "& '$($MyInvocation.MyCommand.Source)'" $args
  if ($LastExitCode -eq 999 ) {
    Write-error 'Failed to elevate.'
  }
  return
}

Get-AppxPackage -AllUsers Microsoft.549981C3F5F10 | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.BingWeather | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.GetHelp | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.Getstarted | Remove-AppPackage
Get-AppxPackage -AllUsers Microsoft.Microsoft3DViewer | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.MicrosoftOfficeHub | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.MicrosoftSolitaireCollection | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.MicrosoftStickyNotes | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.MixedReality.Portal | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.MSPaint | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.People | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.ScreenSketch | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.SkypeApp | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.StorePurchaseApp | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.WindowsAlarms | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.WindowsCalculator | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.WindowsCamera | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.WindowsCommunicationsApps | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.WindowsFeedbackHub | Remove-AppPackage
Get-AppxPackage -AllUsers Microsoft.WindowsMaps | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.Windows.Photos | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.WindowsSoundRecorder | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.WindowsStore | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.XboxApp | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.XboxGameOverlay | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.XboxGamingOverlay | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.XboxIdentityProvider | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.XboxSpeechToTextOverlay | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.Xbox.TCUI | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.YourPhone | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.ZuneMusic | Remove-AppxPackage
Get-AppxPackage -AllUsers Microsoft.ZuneVideo | Remove-AppxPackage