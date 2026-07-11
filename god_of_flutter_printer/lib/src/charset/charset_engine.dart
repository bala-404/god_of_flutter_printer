import 'dart:typed_data';

import 'escpos_raster_line.dart';
import 'embedded_glyph_catalog.dart';
import 'escpos_custom_font.dart';
import 'glyph_bitmap.dart';
import 'glyph_rasterizer.dart';
import 'script_utils.dart';

/// Result of encoding text with optional custom-font download preamble.
class CharsetEncodeResult {
  const CharsetEncodeResult({
    required this.bytes,
    this.usedCustomFont = false,
    this.usedRasterLine = false,
    this.missingGlyphs = const [],
  });

  final Uint8List bytes;
  final bool usedCustomFont;
  final bool usedRasterLine;
  final List<int> missingGlyphs;
}

/// Encodes multilingual text for ESC/POS printers.
class CharsetEngine {
  CharsetEngine({
    GlyphRasterizer? rasterizer,
    this.paperWidthMm = 80,
    this.allowRasterFallback = true,
  })  : _rasterizer = rasterizer ?? GlyphRasterizer(),
        _rasterLine = EscPosRasterLine(paperWidthMm: paperWidthMm);

  final GlyphRasterizer _rasterizer;
  final EscPosRasterLine _rasterLine;
  final int paperWidthMm;
  final bool allowRasterFallback;

  /// Encodes [text] to ESC/POS bytes.
  Future<CharsetEncodeResult> encodeText(
    String text, {
    String? locale,
    bool? allowRaster,
  }) async {
    if (!EscPosRasterLine.requiresRaster(text, locale: locale)) {
      return CharsetEncodeResult(
        bytes: Uint8List.fromList(text.codeUnits),
      );
    }

    final useRaster = allowRaster ?? allowRasterFallback;
    if (useRaster) {
      final bytes = await _rasterLine.encodeLine(text, locale: locale);
      return CharsetEncodeResult(
        bytes: Uint8List.fromList(bytes),
        usedRasterLine: true,
      );
    }

    return _encodeCustomFont(text, locale: locale);
  }

  Future<CharsetEncodeResult> _encodeCustomFont(
    String text, {
    String? locale,
  }) async {
    final codePoints = ScriptUtils.uniqueCustomCodePoints(text);
    final scriptLocale = _resolveLocale(text, locale);
    final glyphs = await _resolveGlyphs(codePoints, scriptLocale);
    final missing = codePoints.where((cp) => !glyphs.containsKey(cp)).toList();

    if (glyphs.isEmpty || missing.isNotEmpty) {
      final bytes = await _rasterLine.encodeLine(text, locale: locale);
      return CharsetEncodeResult(
        bytes: Uint8List.fromList(bytes),
        usedRasterLine: true,
        missingGlyphs: missing,
      );
    }

    final slotMap = EscPosCustomFont.buildSlotMap(glyphs.keys.toList());
    final builder = BytesBuilder(copy: false);
    builder.add(EscPosCustomFont.buildDownloadBytes(glyphs: glyphs));
    builder.add(EscPosCustomFont.selectUserDefinedCharset());
    builder.add(EscPosCustomFont.encodeMappedText(text, slotMap));

    return CharsetEncodeResult(
      bytes: builder.toBytes(),
      usedCustomFont: true,
      missingGlyphs: missing,
    );
  }

  Future<Uint8List> encodeLines(
    Iterable<String> lines, {
    String? locale,
    bool? allowRaster,
  }) async {
    final builder = BytesBuilder(copy: false);
    var first = true;

    for (final line in lines) {
      if (!first) builder.addByte(0x0A);
      first = false;
      final encoded = await encodeText(
        line,
        locale: locale,
        allowRaster: allowRaster,
      );
      builder.add(encoded.bytes);
    }

    return builder.toBytes();
  }

  ScriptLocale _resolveLocale(String text, String? localeTag) {
    final tagged = ScriptUtils.localeFromTag(localeTag);
    if (tagged != ScriptLocale.latin) return tagged;
    return ScriptUtils.detectLocale(text);
  }

  Future<Map<int, GlyphBitmap>> _resolveGlyphs(
    List<int> codePoints,
    ScriptLocale locale,
  ) async {
    final glyphs = <int, GlyphBitmap>{};

    for (final codePoint in codePoints) {
      final script = ScriptUtils.isTamil(codePoint)
          ? ScriptLocale.tamil
          : ScriptUtils.isDevanagari(codePoint)
              ? ScriptLocale.hindi
              : locale;

      GlyphBitmap? glyph = EmbeddedGlyphCatalog.find(codePoint)?.normalized();
      glyph ??= await _rasterizer.rasterize(codePoint, script);
      if (glyph != null) {
        glyphs[codePoint] = glyph;
      }
    }

    return glyphs;
  }
}
