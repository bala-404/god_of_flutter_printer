/// Monochrome glyph matrix used to build ESC/POS custom font downloads.
class GlyphBitmap {
  GlyphBitmap({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;
  final List<bool> pixels;

  factory GlyphBitmap.fromAsciiArt(List<String> rows) {
    final height = rows.length;
    final width = rows.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    final pixels = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        pixels[y * width + x] = row[x] == '#';
      }
    }
    return GlyphBitmap(width: width, height: height, pixels: pixels);
  }

  bool dotAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    return pixels[y * width + x];
  }

  /// Trims empty columns and rows, normalizes height to [targetHeight].
  GlyphBitmap normalized({int targetHeight = 24, int maxWidth = 16}) {
    var minX = width;
    var maxX = -1;
    var minY = height;
    var maxY = -1;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (dotAt(x, y)) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) {
      return GlyphBitmap(width: 1, height: targetHeight, pixels: List.filled(targetHeight, false));
    }

    final croppedWidth = (maxX - minX + 1).clamp(1, maxWidth);
    final croppedHeight = maxY - minY + 1;
    final yOffset = ((targetHeight - croppedHeight) ~/ 2).clamp(0, targetHeight);

    final normalized = List<bool>.filled(croppedWidth * targetHeight, false);
    for (var y = 0; y < croppedHeight; y++) {
      for (var x = 0; x < croppedWidth; x++) {
        final sourceX = minX + x;
        final sourceY = minY + y;
        normalized[(y + yOffset) * croppedWidth + x] = dotAt(sourceX, sourceY);
      }
    }

    return GlyphBitmap(
      width: croppedWidth,
      height: targetHeight,
      pixels: normalized,
    );
  }

  /// ESC/POS column bytes for [EscPosCustomFont].
  List<int> toColumnBytes({int bytesPerColumn = 3}) {
    final columns = <int>[];
    for (var x = 0; x < width; x++) {
      for (var byteIndex = 0; byteIndex < bytesPerColumn; byteIndex++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final y = byteIndex * 8 + bit;
          if (y < height && dotAt(x, y)) {
            value |= 1 << (7 - bit);
          }
        }
        columns.add(value);
      }
    }
    return columns;
  }
}
