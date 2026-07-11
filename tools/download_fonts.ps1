# @powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\download_fonts.ps1"
# Download Noto fonts for high-quality Tamil/Hindi ESC/POS glyphs.
# Embedded glyphs work without this step for common demo characters.

$ErrorActionPreference = 'Stop'
$fontDir = Join-Path $PSScriptRoot '..\god_of_flutter_printer\assets\fonts'
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null

$fonts = @{
  'NotoSansTamil-Regular.ttf' =
    'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/notosanstamil/NotoSansTamil-Regular.ttf'
  'NotoSansDevanagari-Regular.ttf' =
    'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/notosansdevanagari/NotoSansDevanagari-Regular.ttf'
}

foreach ($entry in $fonts.GetEnumerator()) {
  $dest = Join-Path $fontDir $entry.Key
  Write-Host "Downloading $($entry.Key)..."
  Invoke-WebRequest -Uri $entry.Value -OutFile $dest
  Write-Host "Saved $dest ($((Get-Item $dest).Length) bytes)"
}

Write-Host 'Done. Rebuild the example app to use high-quality glyphs.'
