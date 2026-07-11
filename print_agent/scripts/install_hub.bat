@echo off
title Print Worker Hub Installer
echo.
echo Print Worker Hub - one-time install (Administrator required)
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
  echo Requesting Administrator privileges...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0install_service.ps1\"' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_service.ps1"
echo.
pause
