import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScriptUtils', () {
    test('detects Tamil script', () {
      expect(ScriptUtils.hasCustomScript('Hello வணக்கம்'), isTrue);
      expect(ScriptUtils.hasCustomScript('Hello'), isFalse);
    });

    test('needsMultilingualEncoding catches any non-ASCII', () {
      expect(ScriptUtils.needsMultilingualEncoding('வ'), isTrue);
      expect(ScriptUtils.needsMultilingualEncoding('Hello'), isFalse);
    });
  });

  group('EscPosCustomFont', () {
    test('builds ESC & download bytes', () {
      final glyph = GlyphBitmap.fromAsciiArt([
        '.#.',
        '#.#',
        '...',
      ]).normalized();

      final bytes = EscPosCustomFont.buildDownloadBytes(
        glyphs: {0x0BB5: glyph},
        startCode: 0x80,
      );

      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x26);
      expect(bytes[3], 0x80);
      expect(bytes[4], 0x80);
    });

    test('maps unicode to slot bytes above ASCII', () {
      final map = EscPosCustomFont.buildSlotMap([0x0BB5, 0x0B95]);
      final encoded = EscPosCustomFont.encodeMappedText('வக', map);
      expect(encoded[0], 0x80);
      expect(encoded[1], 0x81);
    });
  });

  group('CharsetEngine', () {
    test('sets 24-dot line spacing between ESC * bands', () async {
      final engine = CharsetEngine(allowRasterFallback: true);
      final result = await engine.encodeText('வணக்கம்', locale: 'ta');

      expect(result.usedRasterLine, isTrue);
      expect(result.bytes, contains(0x1B));
      expect(result.bytes, contains(0x33));
      expect(result.bytes[result.bytes.indexOf(0x33) - 1], 0x1B);
      expect(result.bytes[result.bytes.indexOf(0x33) + 1], 24);
    });

    test('encodes Hindi using raster line by default', () async {
      final engine = CharsetEngine(allowRasterFallback: true);
      final result = await engine.encodeText('नमस्ते', locale: 'hi');

      expect(result.usedRasterLine, isTrue);
    });

    test('passes through Latin-only text', () async {
      final engine = CharsetEngine();
      final result = await engine.encodeText('Hello 123');

      expect(result.usedCustomFont, isFalse);
      expect(result.usedRasterLine, isFalse);
      expect(String.fromCharCodes(result.bytes), 'Hello 123');
    });
  });

  group('EscPosEncoder', () {
    test('encodes Tamil text with init command', () async {
      final bytes = await EscPosEncoder(paperWidthMm: 80).encodeText(
        'வணக்கம்',
        locale: 'ta',
      );
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);
    });
  });
}
