import 'dart:convert';
import 'dart:typed_data';

import '../charset/charset_engine.dart';
import '../charset/escpos_raster_line.dart';
import '../models/enums.dart';
import '../models/models.dart';
import 'receipt_line_formatter.dart';

/// Builds ESC/POS byte streams without third-party dependencies.
class EscPosEncoder {
  EscPosEncoder({
    required this.paperWidthMm,
    this.prependInit = true,
    this.charset = 'utf8',
    this.charsetEngine,
    this.allowRasterFallback = true,
  });

  final int paperWidthMm;
  final bool prependInit;
  final String charset;
  final CharsetEngine? charsetEngine;
  final bool allowRasterFallback;

  static const int esc = 0x1B;
  static const int gs = 0x1D;
  static const int lf = 0x0A;

  /// Default receipt line spacing set in [_init].
  static const int defaultLineSpacing = 24;

  /// Tighter spacing for item table rows (matches compact POS bills).
  static const int tableRowLineSpacing = 18;

  CharsetEngine get _engine => charsetEngine ??
      CharsetEngine(
        paperWidthMm: paperWidthMm,
        allowRasterFallback: allowRasterFallback,
      );

  Future<Uint8List> encodeDocument(PrintDocument document) async {
    final buffer = BytesBuilder(copy: false);
    if (prependInit) buffer.add(_init());
    for (final block in document.blocks) {
      buffer.add(await _encodeBlock(block, documentLocale: document.locale));
    }
    return buffer.toBytes();
  }

  Future<Uint8List> encodeText(String text, {String? locale}) async {
    final buffer = BytesBuilder(copy: false);
    if (prependInit) buffer.add(_init());
    for (final line in text.split('\n')) {
      buffer.add(await _encodeTextLine(line, locale: locale));
    }
    buffer.add(_feed(3));
    buffer.add(_cut());
    return buffer.toBytes();
  }

  Uint8List wrapRaw(List<int> bytes, {bool addCutIfMissing = false}) {
    if (!prependInit) return Uint8List.fromList(bytes);
    final buffer = BytesBuilder(copy: false);
    buffer.add(_init());
    buffer.add(bytes);
    if (addCutIfMissing && !_looksLikeHasCut(bytes)) {
      buffer.add(_feed(2));
      buffer.add(_cut());
    }
    return buffer.toBytes();
  }

  List<int> _init() => [
        esc,
        0x40, // reset
        ..._lineSpacing(defaultLineSpacing),
      ];

  List<int> _lineSpacing(int dots) => [esc, 0x33, dots.clamp(0, 255)];

  List<int> _feed(int lines) => [esc, 0x64, lines];

  /// When [feedLines] is set, feed then partial-cut in one GS V 66 command
  /// so margin before the blade is consistent across printer firmware.
  List<int> _cut({int? feedLines}) {
    if (feedLines != null && feedLines > 0) {
      final dots = (feedLines * 24).clamp(0, 255);
      return [gs, 0x56, 66, dots];
    }
    return [gs, 0x56, 0x00];
  }

  Future<List<int>> _encodeBlock(
    PrintDocumentBlock block, {
    String? documentLocale,
  }) async {
    final locale = block.locale ?? documentLocale;
    switch (block.type) {
      case 'text':
        return _encodeStyledText(
          block.text ?? '',
          align: block.align,
          bold: block.bold ?? false,
          size: block.size,
          locale: locale,
        );
      case 'line':
        return _encodePlainLine(
          (block.char ?? '-') * charsPerLineForWidth(paperWidthMm),
          locale: locale,
        );
      case 'row':
        return _encodeSpreadRow(
          block.left ?? '',
          block.right ?? '',
          bold: block.bold ?? false,
          locale: locale,
        );
      case 'feed':
        return _feed(block.lines ?? 1);
      case 'cut':
        return _cut(feedLines: block.lines);
      case 'qr':
        return _encodeQr(block.value ?? '');
      case 'table':
        return _encodeTable(
          block.columns ?? const [],
          block.rows ?? const [],
          locale: locale,
          columnCount: block.columnCount,
          layout: block.layout,
          bold: block.bold ?? false,
          boldFirstColumn: block.boldFirstColumn ?? false,
          boldHeader: block.boldHeader ?? false,
        );
      default:
        return await _encodeTextLine('[unsupported block: ${block.type}]');
    }
  }

  Future<List<int>> _encodeStyledText(
    String text, {
    String? align,
    bool bold = false,
    String? size,
    String? locale,
  }) async {
    final buffer = BytesBuilder(copy: false);
    final lineWidth = charsPerLineForWidth(paperWidthMm);
    final wrapWidth = size == 'large' ? lineWidth ~/ 2 : lineWidth;
    final resolvedAlign = align ?? 'left';
    final formatter = ReceiptLineFormatter(lineWidth);
    final lines = resolvedAlign == 'left'
        ? formatter.wrapAligned(text, wrapWidth, 'left')
        : formatter.wrapLines(text, wrapWidth);

    if (lines.isEmpty) return buffer.takeBytes();

    if (_needsRaster(text, locale)) {
      buffer.add(_align(resolvedAlign));
      buffer.add(await _encodeTextLine(text, locale: locale));
      buffer.addByte(lf);
      buffer.add(_align('left'));
      return buffer.takeBytes();
    }

    if (bold) buffer.add([esc, 0x45, 0x01]);
    buffer.add(_textSize(size));
    for (final line in lines) {
      buffer.add(_align(resolvedAlign));
      buffer.add(await _encodeTextLine(line, locale: locale));
      buffer.addByte(lf);
    }
    if (bold) buffer.add([esc, 0x45, 0x00]);
    buffer.add(_align('left'));
    buffer.add(_textSize('normal'));
    return buffer.takeBytes();
  }

  List<int> _align(String? align) {
    final value = switch (align) {
      'center' => 1,
      'right' => 2,
      _ => 0,
    };
    return [esc, 0x61, value];
  }

  List<int> _textSize(String? size) {
    final value = switch (size) {
      'large' => 0x11,
      'small' => 0x00,
      _ => 0x00,
    };
    return [gs, 0x21, value];
  }

  Future<List<int>> _encodePlainLine(
    String text, {
    String? locale,
    bool bold = false,
  }) async {
    final buffer = BytesBuilder(copy: false);
    if (bold) buffer.add([esc, 0x45, 0x01]);
    buffer.add(await _encodeTextLine(text, locale: locale));
    buffer.addByte(lf);
    if (bold) buffer.add([esc, 0x45, 0x00]);
    return buffer.takeBytes();
  }

  Future<List<int>> _encodeSpreadRow(
    String left,
    String right, {
    bool bold = false,
    String? locale,
  }) async {
    final formatter = ReceiptLineFormatter(charsPerLineForWidth(paperWidthMm));
    final line = formatter.leftRight(left, right);
    if (bold) {
      return _encodeStyledText(line, bold: true, locale: locale);
    }
    return _encodePlainLine(line, locale: locale);
  }

  Future<List<int>> _encodeTable(
    List<String> columns,
    List<List<String>> rows, {
    String? locale,
    int? columnCount,
    String? layout,
    bool bold = false,
    bool boldFirstColumn = false,
    bool boldHeader = false,
  }) async {
    final lineWidth = charsPerLineForWidth(paperWidthMm);
    final formatter = ReceiptLineFormatter(lineWidth);
    final buffer = BytesBuilder(copy: false);
    final normalizedColumns = ReceiptLineFormatter.normalizeColumns(columns);
    final resolvedLayout =
        ReceiptLineFormatter.resolveLayout(layout, normalizedColumns);
    final resolvedColumnCount = columnCount ??
        (normalizedColumns.isNotEmpty
            ? normalizedColumns.length
            : (rows.isNotEmpty ? rows.first.length : 0));

    if (normalizedColumns.isNotEmpty) {
      buffer.add(
        await _encodePlainLine(
          formatter.formatHeader(normalizedColumns, layout: resolvedLayout),
          locale: locale,
          bold: boldHeader || bold,
        ),
      );
      final separatorChar = layout == 'kot' ? '.' : '-';
      buffer.add(
        await _encodePlainLine(
          separatorChar * lineWidth,
          locale: locale,
        ),
      );
    }
    if (rows.isNotEmpty) {
      buffer.add(_lineSpacing(tableRowLineSpacing));
    }
    for (final row in rows) {
      if (boldFirstColumn && !bold) {
        final cellLines = formatter.formatRowCells(
          row,
          columnCount: resolvedColumnCount,
          layout: resolvedLayout,
        );
        for (final cells in cellLines) {
          if (cells.length == 1) {
            buffer.add(
              await _encodePlainLine(
                formatter.joinCells(
                  cells,
                  1,
                  layout: layout,
                ),
                locale: locale,
                bold: true,
              ),
            );
          } else {
            buffer.add(
              await _encodeJoinedCells(
                cells,
                resolvedColumnCount,
                layout: layout,
                boldFirstColumn: true,
                locale: locale,
              ),
            );
          }
        }
      } else {
        for (final line in formatter.formatRow(
          row,
          columnCount: resolvedColumnCount,
          layout: resolvedLayout,
        )) {
          buffer.add(
            await _encodePlainLine(line, locale: locale, bold: bold),
          );
        }
      }
    }
    if (rows.isNotEmpty) {
      buffer.add(_lineSpacing(defaultLineSpacing));
    }
    return buffer.takeBytes();
  }

  Future<List<int>> _encodeJoinedCells(
    List<String> cells,
    int columnCount, {
    String? layout,
    bool boldFirstColumn = false,
    String? locale,
  }) async {
    final formatter = ReceiptLineFormatter(charsPerLineForWidth(paperWidthMm));
    final widths = formatter.widthsFor(columnCount, layout: layout);
    final aligns = formatter.alignsFor(columnCount, layout: layout);
    final buffer = BytesBuilder(copy: false);

    for (var i = 0; i < columnCount; i++) {
      final text = i < cells.length ? cells[i] : '';
      final fitted = _fitCell(text, widths[i], aligns[i]);
      if (i == 0 && boldFirstColumn) {
        buffer.add([esc, 0x45, 0x01]);
      }
      buffer.add(await _encodeTextLine(fitted, locale: locale));
      if (i == 0 && boldFirstColumn) {
        buffer.add([esc, 0x45, 0x00]);
      }
    }
    buffer.addByte(lf);
    return buffer.takeBytes();
  }

  String _fitCell(String text, int width, String align) {
    if (width <= 0) return '';
    var value = text;
    if (value.length > width) {
      value = value.substring(0, width);
    }
    return switch (align) {
      'right' => value.padLeft(width),
      'center' => value
          .padLeft((width + value.length) ~/ 2)
          .padRight(width)
          .substring(0, width),
      _ => value.padRight(width),
    };
  }

  List<int> _encodeQr(String value) {
    final data = utf8.encode(value);
    final storeLen = data.length + 3;
    final pL = storeLen % 256;
    final pH = storeLen ~/ 256;
    return [
      gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x08,
      gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30,
      gs, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30,
      ...data,
      gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
      lf,
    ];
  }

  bool _needsRaster(String text, String? locale) {
    return EscPosRasterLine.requiresRaster(text, locale: locale);
  }

  Future<List<int>> _encodeTextLine(String text, {String? locale}) async {
    if (_needsRaster(text, locale)) {
      final encoded = await _engine.encodeText(text, locale: locale);
      return encoded.bytes;
    }

    if (charset.toLowerCase() == 'ascii') {
      return text.codeUnits.where((c) => c <= 0x7F).toList();
    }

    return utf8.encode(text);
  }

  bool _looksLikeHasCut(List<int> bytes) {
    for (var i = 0; i < bytes.length - 2; i++) {
      if (bytes[i] == gs && bytes[i + 1] == 0x56) return true;
    }
    return false;
  }
}
