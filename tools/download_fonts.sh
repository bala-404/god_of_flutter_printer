#!/usr/bin/env bash
# Download Noto fonts for high-quality Tamil/Hindi ESC/POS glyphs.
# Embedded glyphs work without this step for common demo characters.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FONT_DIR="$SCRIPT_DIR/../god_of_flutter_printer/assets/fonts"
mkdir -p "$FONT_DIR"

download() {
  local name="$1"
  local url="$2"
  local dest="$FONT_DIR/$name"
  echo "Downloading $name..."
  curl -fsSL "$url" -o "$dest"
  echo "Saved $dest ($(wc -c < "$dest") bytes)"
}

download "NotoSansTamil-Regular.ttf" \
  "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/notosanstamil/NotoSansTamil-Regular.ttf"

download "NotoSansDevanagari-Regular.ttf" \
  "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/notosansdevanagari/NotoSansDevanagari-Regular.ttf"

echo "Done. Rebuild the example app to use high-quality glyphs."
