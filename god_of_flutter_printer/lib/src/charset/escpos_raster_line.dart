import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/enums.dart';
import 'script_utils.dart';

/// Renders text lines as ESC * raster strips (widely supported on Rugtek/Epson).
class EscPosRasterLine {
  EscPosRasterLine({required this.paperWidthMm});

  final int paperWidthMm;

  static const int esc = 0x1B;
  static const int bandHeight = 24;

  static const _tamilFonts = ['Nirmala UI', 'Latha', 'Tamil MN', 'Noto Sans Tamil'];
  static const _hindiFonts = ['Nirmala UI', 'Mangal', 'Noto Sans Devanagari'];

  /// Returns true when [text] must not be sent as UTF-8 to the printer.
  static bool requiresRaster(String text, {String? locale}) {
    if (ScriptUtils.hasCustomScript(text)) return true;
    if (ScriptUtils.needsMultilingualEncoding(text)) return true;
    final tagged = ScriptUtils.localeFromTag(locale);
    return tagged == ScriptLocale.tamil || tagged == ScriptLocale.hindi;
  }

  Future<List<int>> encodeLine(String text, {String? locale}) async {
    if (text.isEmpty) return const [];

    final script = _resolveLocale(text, locale);
    final fonts = switch (script) {
      ScriptLocale.tamil => _tamilFonts,
      ScriptLocale.hindi => _hindiFonts,
      _ => const ['Segoe UI', 'Arial'],
    };

    final maxWidth = _printableWidthDots();
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontFamily: fonts.first,
          fontFamilyFallback: fonts,
          color: const Color(0xFF000000),
        ),
      ),
      textDirection: TextDirection.ltr,
      locale: script == ScriptLocale.tamil
          ? const Locale('ta')
          : script == ScriptLocale.hindi
              ? const Locale('hi')
              : null,
      maxLines: 6,
    )..layout(maxWidth: maxWidth.toDouble());

    final layoutWidth = painter.width.ceil().clamp(1, maxWidth);
    final layoutHeight = painter.height.ceil().clamp(bandHeight, bandHeight * 6);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, layoutWidth.toDouble(), layoutHeight.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    painter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final image = await picture.toImage(layoutWidth, layoutHeight);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) {
      throw StateError('Failed to rasterize text for printing: "$text"');
    }

    final pixels = _binarize(rgba, layoutWidth, layoutHeight);
    final cropped = _trimWhitespace(pixels, padding: 2);

    if (!_hasInk(cropped)) {
      throw StateError(
        'No printable pixels generated for "$text". '
        'Install Tamil/Hindi fonts (Nirmala UI / Latha) on Windows.',
      );
    }

    return _encodeEscStarBands(cropped);
  }

  /// Hard threshold — anti-aliased gray pixels become white, not stray dots.
  List<List<bool>> _binarize(ByteData rgba, int width, int height) {
    final pixels = List.generate(
      height,
      (_) => List<bool>.filled(width, false),
    );

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        final r = rgba.getUint8(index);
        final g = rgba.getUint8(index + 1);
        final b = rgba.getUint8(index + 2);
        final a = rgba.getUint8(index + 3);
        final luminance = (r * 0.299 + g * 0.587 + b * 0.114).round();
        if (a > 160 && luminance < 96) {
          pixels[y][x] = true;
        }
      }
    }

    return pixels;
  }

  /// Remove empty margins so ESC * width matches ink, not trailing whitespace.
  List<List<bool>> _trimWhitespace(
    List<List<bool>> pixels, {
    required int padding,
  }) {
    final height = pixels.length;
    final width = pixels.first.length;

    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!pixels[y][x]) continue;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }

    if (maxX < 0) return pixels;

    minX = math.max(0, minX - padding);
    minY = math.max(0, minY - padding);
    maxX = math.min(width - 1, maxX + padding);
    maxY = math.min(height - 1, maxY + padding);

    final croppedHeight = maxY - minY + 1;
    final croppedWidth = maxX - minX + 1;
    return List.generate(croppedHeight, (y) {
      final row = minY + y;
      return List<bool>.generate(
        croppedWidth,
        (x) => pixels[row][minX + x],
      );
    });
  }

  bool _hasInk(List<List<bool>> pixels) {
    for (final row in pixels) {
      if (row.any((dot) => dot)) return true;
    }
    return false;
  }

  /// ESC * m nL nH — 24-dot double-density bands (Rugtek/Epson compatible).
  ///
  /// Line spacing is locked to [bandHeight] between bands so multi-row Tamil
  /// glyphs are not split by extra white gaps (the common "broken letter" bug).
  List<int> _encodeEscStarBands(List<List<bool>> pixels) {
    final height = pixels.length;
    final width = pixels.first.length;
    final output = <int>[];

    output.addAll([esc, 0x33, bandHeight]);

    for (var yBand = 0; yBand < height; yBand += bandHeight) {
      output.addAll([esc, 0x2A, 33, width & 0xFF, (width >> 8) & 0xFF]);

      for (var x = 0; x < width; x++) {
        for (var byteRow = 0; byteRow < 3; byteRow++) {
          var value = 0;
          for (var bit = 0; bit < 8; bit++) {
            final y = yBand + byteRow * 8 + bit;
            if (y < height && pixels[y][x]) {
              value |= 1 << (7 - bit);
            }
          }
          output.add(value);
        }
      }

      output.add(0x0A);
    }

    output.addAll([esc, 0x32]);
    output.addAll([esc, 0x4A, 0x06]);
    return output;
  }

  int _printableWidthDots() => rasterDotsForWidth(paperWidthMm);

  ScriptLocale _resolveLocale(String text, String? localeTag) {
    final tagged = ScriptUtils.localeFromTag(localeTag);
    if (tagged != ScriptLocale.latin) return tagged;
    return ScriptUtils.detectLocale(text);
  }
}
