import 'dart:typed_data';

import 'glyph_bitmap.dart';

/// Builds ESC/POS custom-font download commands (`ESC &`) — not image print.
class EscPosCustomFont {
  EscPosCustomFont._();

  static const int esc = 0x1B;

  /// Bytes per vertical column (24 dots = 3 bytes).
  static const int bytesPerColumn = 3;

  /// First slot for downloaded glyphs — above ASCII to avoid space (0x20) clash.
  static const int defaultStartCode = 0x80;

  /// Builds download bytes for [glyphs] mapped to sequential slots.
  ///
  /// [glyphs] keys are Unicode code points; values are raster matrices.
  static Uint8List buildDownloadBytes({
    required Map<int, GlyphBitmap> glyphs,
    int startCode = defaultStartCode,
  }) {
    if (glyphs.isEmpty) return Uint8List(0);

    final codePoints = glyphs.keys.toList()..sort();
    if (codePoints.length > 224) {
      throw ArgumentError('Too many custom glyphs in one download batch (max 224).');
    }

    final c1 = startCode;
    final c2 = startCode + codePoints.length - 1;
    final builder = BytesBuilder(copy: false);
    builder.add([esc, 0x26, bytesPerColumn, c1, c2]);

    for (final codePoint in codePoints) {
      final glyph = glyphs[codePoint]!.normalized();
      builder.addByte(glyph.width.clamp(1, 255));
      builder.add(glyph.toColumnBytes(bytesPerColumn: bytesPerColumn));
    }

    return builder.toBytes();
  }

  /// Selects user-defined character set (`ESC % 1`).
  static List<int> selectUserDefinedCharset() => [esc, 0x25, 0x01];

  /// Cancels user-defined characters (`ESC ?`).
  static List<int> cancelUserDefinedCharset() => [esc, 0x3F, 0x00];

  /// Maps Unicode code points to downloaded slot bytes for printing.
  static Map<int, int> buildSlotMap(List<int> codePoints, {int startCode = defaultStartCode}) {
    final map = <int, int>{};
    for (var i = 0; i < codePoints.length; i++) {
      map[codePoints[i]] = startCode + i;
    }
    return map;
  }

  /// Encodes [text] using [slotMap] for custom glyphs and Latin passthrough.
  static Uint8List encodeMappedText(String text, Map<int, int> slotMap) {
    final bytes = <int>[];
    for (final rune in text.runes) {
      final slot = slotMap[rune];
      if (slot != null) {
        bytes.add(slot);
      } else if (rune <= 0x7E) {
        bytes.add(rune);
      } else {
        bytes.add(0x3F); // '?'
      }
    }
    return Uint8List.fromList(bytes);
  }
}
