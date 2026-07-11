# Starts print_agent (Windows) then the Chrome example app.
# Web Bluetooth/USB needs the agent running on the same PC.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$agentDir = Join-Path $root "print_agent"
$exampleDir = Join-Path $root "example"

Write-Host "Starting print_agent on Windows (keep this PC's Bluetooth/USB bridge)..."
$agent = Start-Process powershell -ArgumentList @(
  "-NoExit",
  "-Command",
  "cd '$agentDir'; flutter run -d windows"
) -PassThru

Write-Host "Waiting for print agent on http://localhost:9280 ..."
$ready = $false
for ($i = 0; $i -lt 45; $i++) {
  try {
    $response = Invoke-WebRequest -Uri "http://localhost:9280/health" -UseBasicParsing -TimeoutSec 2
    if ($response.StatusCode -eq 200) {
      $ready = $true
      break
    }
  } catch {
    Start-Sleep -Seconds 2
  }
}

if (-not $ready) {
  Write-Warning "Print agent did not respond yet. Chrome may show an error until the agent window finishes starting."
} else {
  Write-Host "Print agent is online."
}

Write-Host "Launching example app in Chrome..."
Set-Location $exampleDir
flutter run -d chrome
