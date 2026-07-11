# @powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\release_all.ps1"
# Build all distributable assets for a God of Flutter Printer release.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " God of Flutter Printer — Release Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Run package tests
Write-Host "[1/3] Running god_of_flutter_printer tests..." -ForegroundColor Yellow
Set-Location (Join-Path $root "god_of_flutter_printer")
flutter pub get | Out-Null
flutter test
if ($LASTEXITCODE -ne 0) { throw "Tests failed." }

# 2. Build Print Hub zip
Write-Host ""
Write-Host "[2/3] Building Print Hub (print_agent)..." -ForegroundColor Yellow
Set-Location (Join-Path $root "print_agent")
& (Join-Path $root "print_agent\scripts\package_release.ps1")

# 3. Summary
Write-Host ""
Write-Host "[3/3] Release assets ready:" -ForegroundColor Green
Write-Host ""
Write-Host "  Print Hub (for web POS shops):" -ForegroundColor White
Write-Host "    $root\print_agent\dist\PrintWorkerHub-win64.zip"
Write-Host ""
Write-Host "  pub.dev packages (publish manually in order):" -ForegroundColor White
Write-Host "    1. god_of_flutter_printer_platform_interface"
Write-Host "    2. god_of_flutter_printer_windows"
Write-Host "    3. god_of_flutter_printer"
Write-Host ""
Write-Host "  Example demo app (run from source):" -ForegroundColor White
Write-Host "    cd example && flutter run -d windows"
Write-Host ""
Write-Host "  See PUBLISHING.md for full instructions." -ForegroundColor Cyan
