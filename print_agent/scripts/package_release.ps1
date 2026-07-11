# Build Print Hub, bundle installer scripts, and zip for shop distribution.
$ErrorActionPreference = "Stop"
$agentDir = Split-Path -Parent $PSScriptRoot
$scriptsDir = $PSScriptRoot

Write-Host "Building Print Hub (Windows release)..."
Set-Location $agentDir
flutter build windows --release

$releaseDir = Join-Path $agentDir "build\windows\x64\runner\Release"
$exePath = Join-Path $releaseDir "print_agent.exe"
if (-not (Test-Path $exePath)) {
  throw "Build finished but print_agent.exe was not found."
}

$stageDir = Join-Path $agentDir "dist\PrintWorkerHub-win64"
if (Test-Path $stageDir) {
  Remove-Item $stageDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

Write-Host "Staging package..."
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $stageDir -Recurse -Force
Copy-Item -Path (Join-Path $scriptsDir "install_service.ps1") -Destination $stageDir
Copy-Item -Path (Join-Path $scriptsDir "uninstall_service.ps1") -Destination $stageDir
Copy-Item -Path (Join-Path $scriptsDir "install_hub.bat") -Destination $stageDir
Copy-Item -Path (Join-Path $scriptsDir "INSTALL.txt") -Destination $stageDir

$distDir = Join-Path $agentDir "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$zipPath = Join-Path $distDir "PrintWorkerHub-win64.zip"

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}

Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $zipPath

Write-Host ""
Write-Host "Package ready:"
Write-Host "  $zipPath"
Write-Host ""
Write-Host "Shop install: unzip -> Run install_hub.bat as Administrator"
Write-Host "Hub auto-starts on every boot after install."
