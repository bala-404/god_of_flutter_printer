#!/usr/bin/env bash
# Publish all three God of Flutter Printer packages to pub.dev.
# Run once: dart pub login
# Publisher must be verified for https://github.com/bala-404/god_of_flutter_printer

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERRIDES="$ROOT/god_of_flutter_printer/pubspec_overrides.yaml"
OVERRIDES_BAK="$ROOT/god_of_flutter_printer/pubspec_overrides.yaml.bak"

restore_overrides() {
  if [[ -f "$OVERRIDES_BAK" ]]; then
    mv "$OVERRIDES_BAK" "$OVERRIDES"
  fi
}
trap restore_overrides EXIT

echo "==> 1/3 god_of_flutter_printer_platform_interface"
cd "$ROOT/god_of_flutter_printer_platform_interface"
dart pub publish --dry-run
dart pub publish

echo "==> 2/3 god_of_flutter_printer_windows"
cd "$ROOT/god_of_flutter_printer_windows"
dart pub publish --dry-run
dart pub publish

echo "==> 3/3 god_of_flutter_printer"
cd "$ROOT/god_of_flutter_printer"
if [[ -f "$OVERRIDES" ]]; then
  mv "$OVERRIDES" "$OVERRIDES_BAK"
fi
dart pub publish --dry-run
dart pub publish

echo ""
echo "Done. Verify:"
echo "  https://pub.dev/packages/god_of_flutter_printer"
echo "  https://pub.dev/packages/god_of_flutter_printer_windows"
echo "  https://pub.dev/packages/god_of_flutter_printer_platform_interface"
