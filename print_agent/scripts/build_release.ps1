# Builds the Print Hub Windows release folder for shop distribution.
# Output: print_agent\build\windows\x64\runner\Release\

$ErrorActionPreference = "Stop"
$agentDir = Split-Path -Parent $PSScriptRoot

Write-Host "Building Print Hub (Windows release)..."
Set-Location $agentDir
flutter build windows --release

$outDir = Join-Path $agentDir "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $outDir "print_agent.exe"))) {
  throw "Build finished but print_agent.exe was not found in $outDir"
}

Write-Host ""
Write-Host "Print Hub EXE ready:"
Write-Host "  $outDir\print_agent.exe"
Write-Host ""
Write-Host "Ship the entire Release folder to each shop PC."
Write-Host "After install, open the app to see the LAN URL for your web app."
