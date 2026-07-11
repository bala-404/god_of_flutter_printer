# Uninstall Print Worker Hub service / boot task.
# Run as Administrator.

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run as Administrator."
}

$TaskName = "PrintWorkerHub"
$InstallDir = Join-Path ${env:ProgramFiles} "PrintWorkerHub"

Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Get-Process print_agent -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Remove-NetFirewallRule -DisplayName "Print Worker Hub (TCP 9280)" -ErrorAction SilentlyContinue

$desktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
$shortcut = Join-Path $desktop "Print Worker Hub.lnk"
if (Test-Path $shortcut) { Remove-Item $shortcut -Force }

if (Test-Path $InstallDir) {
  Remove-Item $InstallDir -Recurse -Force
}

Write-Host "Print Worker Hub uninstalled."
