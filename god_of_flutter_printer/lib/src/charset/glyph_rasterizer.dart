import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'embedded_glyph_catalog.dart';
import 'glyph_bitmap.dart';
import 'script_utils.dart';
import '../utils/package_assets.dart';

/// Rasterizes Unicode glyphs into dot matrices for ESC/POS font download.
///
/// Uses bundled Noto fonts when available; falls back to [EmbeddedGlyphCatalog].
class GlyphRasterizer {
  GlyphRasterizer({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Set<ScriptLocale> _loadedFontLocales = {};
  final Map<String, GlyphBitmap> _cache = {};

  static const _fontAssets = {
    ScriptLocale.tamil: (
      asset: 'assets/fonts/NotoSansTamil-Regular.ttf',
      family: 'PrintWorkerNotoTamil',
    ),
    ScriptLocale.hindi: (
      asset: 'assets/fonts/NotoSansDevanagari-Regular.ttf',
      family: 'PrintWorkerNotoDevanagari',
    ),
  };

  Future<GlyphBitmap?> rasterize(int codePoint, ScriptLocale locale) async {
    final cacheKey = '${locale.name}:$codePoint';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final embedded = EmbeddedGlyphCatalog.find(codePoint);
    if (embedded != null) {
      _cache[cacheKey] = embedded.normalized();
      return _cache[cacheKey];
    }

    final char = String.fromCharCode(codePoint);
    final bitmap = await _rasterizeChar(char, locale);
    if (bitmap != null) {
      _cache[cacheKey] = bitmap.normalized();
      return _cache[cacheKey];
    }
    return null;
  }

  Future<Map<int, GlyphBitmap>> rasterizeAll(
    Iterable<int> codePoints,
    ScriptLocale locale,
  ) async {
    final result = <int, GlyphBitmap>{};
    for (final codePoint in codePoints) {
      final glyph = await rasterize(codePoint, locale);
      if (glyph != null) {
        result[codePoint] = glyph;
      }
    }
    return result;
  }

  Future<bool> _ensureFontLoaded(ScriptLocale locale) async {
    if (locale == ScriptLocale.latin || locale == ScriptLocale.mixed) {
      return false;
    }
    if (_loadedFontLocales.contains(locale)) return true;

    final config = _fontAssets[locale];
    if (config == null) return false;

    try {
      final data = await PackageAssets.loadBytes(config.asset, bundle: _bundle);
      if (data.lengthInBytes >= 1024) {
        final loader = FontLoader(config.family)..addFont(Future.value(data));
        await loader.load();
        _loadedFontLocales.add(locale);
        return true;
      }
    } catch (_) {
      // Fall back to system fonts below.
    }
    return true;
  }

  Future<GlyphBitmap?> _rasterizeChar(String char, ScriptLocale locale) async {
    await _ensureFontLoaded(locale);

    final families = <String>[];
    final config = _fontAssets[locale];
    if (config != null && _loadedFontLocales.contains(locale)) {
      families.add(config.family);
    }
    families.addAll(_fallbackFonts(locale));

    final painter = TextPainter(
      text: TextSpan(
        text: char,
        style: TextStyle(
          fontSize: 28,
          height: 1,
          fontFamily: families.first,
          fontFamilyFallback: families,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 64);

    final width = painter.width.ceil().clamp(1, 32);
    final height = painter.height.ceil().clamp(1, 32);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final pixels = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        final alpha = byteData.getUint8(index + 3);
        pixels[y * width + x] = alpha > 40;
      }
    }

    return GlyphBitmap(width: width, height: height, pixels: pixels);
  }

  List<String> _fallbackFonts(ScriptLocale locale) {
    return switch (locale) {
      ScriptLocale.tamil => const ['Nirmala UI', 'Latha', 'Tamil MN'],
      ScriptLocale.hindi => const ['Nirmala UI', 'Mangal'],
      _ => const ['Segoe UI', 'Arial'],
    };
  }
}
