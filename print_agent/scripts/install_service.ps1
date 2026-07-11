# Installs Print Worker Hub to Program Files and registers auto-start on every boot.
# MUST run as Administrator (right-click install_hub.bat -> Run as administrator).

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run install_hub.bat as Administrator."
}

$TaskName = "PrintWorkerHub"
$InstallDir = Join-Path ${env:ProgramFiles} "PrintWorkerHub"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Source: script next to print_agent.exe (zip root) or Release folder parent
$SourceDir = $ScriptDir
if (-not (Test-Path (Join-Path $SourceDir "print_agent.exe"))) {
  $releaseCandidate = Join-Path $ScriptDir "..\..\build\windows\x64\runner\Release"
  if (Test-Path (Join-Path $releaseCandidate "print_agent.exe")) {
    $SourceDir = (Resolve-Path $releaseCandidate).Path
  } else {
    throw "print_agent.exe not found next to installer scripts."
  }
}

Write-Host "Installing Print Worker Hub to $InstallDir ..."
if (Test-Path $InstallDir) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  Get-Process print_agent -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Path (Join-Path $SourceDir "*") -Destination $InstallDir -Recurse -Force

$ExePath = Join-Path $InstallDir "print_agent.exe"
if (-not (Test-Path $ExePath)) {
  throw "Installation failed: print_agent.exe missing in $InstallDir"
}

# Firewall - allow LAN/web clients to reach port 9280
$fwRule = "Print Worker Hub (TCP 9280)"
$existingRule = Get-NetFirewallRule -DisplayName $fwRule -ErrorAction SilentlyContinue
if ($existingRule) {
  Remove-NetFirewallRule -DisplayName $fwRule
}
New-NetFirewallRule -DisplayName $fwRule `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9280 `
  -Profile Private,Domain | Out-Null

# Remove old scheduled task if present
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Run as the installing user — Bluetooth pairing is per-user on Windows (SYSTEM cannot connect).
$RunAsUser = "$env:USERDOMAIN\$env:USERNAME"
$action = New-ScheduledTaskAction -Execute $ExePath -Argument "--headless" -WorkingDirectory $InstallDir
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 1)

$taskParams = @{
  TaskName    = $TaskName
  Action      = $action
  Trigger     = $logonTrigger
  Principal   = $principal
  Settings    = $settings
  Description = 'Print Worker Hub - USB Bluetooth and network print bridge'
  Force       = $true
}
Register-ScheduledTask @taskParams | Out-Null

# Desktop shortcut to open hub UI (view LAN URL, printers)
$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
$shortcut = $shell.CreateShortcut((Join-Path $desktop "Print Worker Hub.lnk"))
$shortcut.TargetPath = $ExePath
$shortcut.WorkingDirectory = $InstallDir
$shortcut.Description = 'Print Worker Hub - copy LAN URL for your web app'
$shortcut.Save()

Write-Host "Starting Print Worker Hub (as $RunAsUser)..."
Start-Process -FilePath $ExePath -ArgumentList "--headless" -WorkingDirectory $InstallDir -WindowStyle Hidden
Start-Sleep -Seconds 3

$hubUrlFile = "C:\ProgramData\PrintWorkerHub\hub-url.txt"
if (Test-Path $hubUrlFile) {
  Write-Host ""
  Write-Host "Hub URLs (paste into your web app):"
  Get-Content $hubUrlFile
} else {
  Write-Host "Hub is starting. Open Print Worker Hub from the desktop to see the LAN URL."
}

Write-Host ""
Write-Host "Installed successfully."
Write-Host "  - Auto-starts when $RunAsUser logs on (task: $TaskName)"
Write-Host "  - Desktop shortcut: Print Worker Hub"
Write-Host "  - URL snapshot: C:\ProgramData\PrintWorkerHub\hub-url.txt"
