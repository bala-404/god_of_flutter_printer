/// Fixed-width line layout for thermal receipt printers (Font A).
class ReceiptLineFormatter {
  ReceiptLineFormatter(this.lineWidth);

  final int lineWidth;

  static const String amountColumnHeader = 'Amount';

  /// Maps legacy / caller-supplied headers to the canonical receipt labels.
  static List<String> normalizeColumns(List<String> columns) {
    return columns.map(normalizeColumnLabel).toList();
  }

  static String normalizeColumnLabel(String column) {
    final trimmed = column.trim();
    if (trimmed.toLowerCase() == 'amt') return amountColumnHeader;
    return column;
  }

  /// Picks invoice table layout for standard 4-column product tables.
  static String? resolveLayout(String? layout, List<String> columns) {
    if (layout != null && layout.isNotEmpty) return layout;
    if (columns.length != 4) return layout;
    final labels = columns.map((c) => c.trim().toLowerCase()).toList();
    final hasProduct = labels.first.contains('product') || labels.first == 'item';
    final hasQty = labels.length > 1 && labels[1] == 'qty';
    final hasPrice = labels.length > 2 && labels[2] == 'price';
    final hasAmount = labels.length > 3 &&
        (labels[3] == 'amount' || labels[3] == 'amt');
    if (hasProduct && hasQty && hasPrice && hasAmount) return 'invoice';
    return layout;
  }

  String leftRight(String left, String right) {
    final l = left.trim();
    final r = right.trim();
    if (l.isEmpty) return _fit(r, lineWidth, 'right');
    if (r.isEmpty) return _fit(l, lineWidth, 'left');
    if (l.length + r.length >= lineWidth) {
      final maxLeft = (lineWidth - r.length - 1).clamp(0, lineWidth);
      if (maxLeft <= 0) {
        return _fit(r, lineWidth, 'right');
      }
      final clippedLeft = l.length > maxLeft ? l.substring(0, maxLeft) : l;
      return clippedLeft.padRight(lineWidth - r.length) + r;
    }
    return l.padRight(lineWidth - r.length) + r;
  }

  String formatHeader(List<String> columns, {String? layout}) {
    final normalized = normalizeColumns(columns);
    final resolvedLayout = resolveLayout(layout, normalized);
    return _joinCells(
      normalized,
      widthsFor(normalized.length, layout: resolvedLayout),
      alignsFor(normalized.length, layout: resolvedLayout),
    );
  }

  List<String> formatRow(List<String> cells, {int? columnCount, String? layout}) {
    final count = columnCount ?? cells.length;
    if (count == 0 || cells.isEmpty) return const [];

    final resolvedLayout = layout ?? (count == 4 ? 'invoice' : null);
    if (resolvedLayout == 'invoice' && count == 4) {
      return _formatInvoiceRow(cells);
    }

    final widths = widthsFor(count, layout: resolvedLayout);
    final aligns = alignsFor(count, layout: resolvedLayout);
    final padded = List<String>.generate(
      count,
      (i) => i < cells.length ? cells[i] : '',
    );

    if (count == 1) {
      return _wrapText(padded[0], lineWidth);
    }

    final firstWidth = widths[0];
    final firstLines = _wrapText(padded[0], firstWidth);
    final lines = <String>[];

    for (var i = 0; i < firstLines.length; i++) {
      if (i == 0) {
        lines.add(
          _joinCells(
            [firstLines[i], ...padded.sublist(1)],
            widths,
            aligns,
          ),
        );
      } else {
        lines.add(_fit(firstLines[i], firstWidth, 'left'));
      }
    }
    return lines;
  }

  /// Product name may wrap; qty/price/amount stay on column 0 only and are
  /// anchored to fixed right-edge positions on every item row.
  List<String> _formatInvoiceRow(List<String> cells) {
    final widths = _invoiceWidths();
    final productWidth = widths[0];
    final padded = List<String>.generate(
      4,
      (i) => i < cells.length ? cells[i].trim() : '',
    );
    final numericSuffix = _joinCells(
      padded.sublist(1),
      widths.sublist(1),
      const ['right', 'right', 'right'],
    );
    final productLines = _wrapText(padded[0], productWidth);
    final lines = <String>[];

    for (var i = 0; i < productLines.length; i++) {
      if (i == 0) {
        lines.add(
          _fit(productLines[i], productWidth, 'left') + numericSuffix,
        );
      } else {
        lines.add(_fit(productLines[i], productWidth, 'left'));
      }
    }
    return lines;
  }

  /// One visual line per row — each inner list is the cell values on that line.
  List<List<String>> formatRowCells(
    List<String> cells, {
    int? columnCount,
    String? layout,
  }) {
    final count = columnCount ?? cells.length;
    if (count == 0 || cells.isEmpty) return const [];

    final widths = widthsFor(count, layout: layout);
    final padded = List<String>.generate(
      count,
      (i) => i < cells.length ? cells[i] : '',
    );

    if (count == 1) {
      return _wrapText(padded[0], lineWidth).map((line) => [line]).toList();
    }

    final resolvedLayout = layout ?? (count == 4 ? 'invoice' : null);
    if (resolvedLayout == 'invoice' && count == 4) {
      final productWidth = _invoiceWidths()[0];
      final productLines = _wrapText(padded[0], productWidth);
      final result = <List<String>>[];
      for (var i = 0; i < productLines.length; i++) {
        if (i == 0) {
          result.add([productLines[i], ...padded.sublist(1)]);
        } else {
          result.add([productLines[i]]);
        }
      }
      return result;
    }

    final firstLines = _wrapText(padded[0], widths[0]);
    final result = <List<String>>[];
    for (var i = 0; i < firstLines.length; i++) {
      if (i == 0) {
        result.add([firstLines[i], ...padded.sublist(1)]);
      } else {
        result.add([firstLines[i]]);
      }
    }
    return result;
  }

  List<int> widthsFor(int columnCount, {String? layout}) {
    if (layout == 'kot' && columnCount == 3) {
      final qtyW = _scaledWidth(5, min: 4, max: 6);
      final noteW = _scaledWidth(14, min: 10, max: 16);
      return [lineWidth - noteW - qtyW, noteW, qtyW];
    }
    if ((layout == 'invoice' || layout == null) && columnCount == 4) {
      return _invoiceWidths();
    }
    return _widthsFor(columnCount);
  }

  List<String> alignsFor(int columnCount, {String? layout}) {
    if (layout == 'kot' && columnCount == 3) {
      return const ['left', 'left', 'right'];
    }
    if ((layout == 'invoice' || layout == null) && columnCount == 4) {
      return const ['left', 'right', 'right', 'right'];
    }
    return _alignsFor(columnCount);
  }

  String joinCells(
    List<String> cells,
    int columnCount, {
    String? layout,
  }) {
    final widths = widthsFor(columnCount, layout: layout);
    final aligns = alignsFor(columnCount, layout: layout);
    final padded = List<String>.generate(
      columnCount,
      (i) => i < cells.length ? cells[i] : '',
    );
    return _joinCells(padded, widths, aligns);
  }

  /// Product | Qty | Price | Amount — numeric columns sized from the right
  /// so values stay in a straight vertical line on every paper width.
  List<int> _invoiceWidths() {
    final amount = _scaledWidth(10, min: 6, max: 11);
    final price = _scaledWidth(9, min: 7, max: 10);
    final qty = _scaledWidth(4, min: 4, max: 5);
    final product = lineWidth - qty - price - amount;
    return [product, qty, price, amount];
  }

  List<int> _widthsFor(int columnCount) {
    final qty = _scaledWidth(4, min: 3, max: 5);
    final summary = _scaledWidth(14, min: 10, max: 16);

    return switch (columnCount) {
      4 => _invoiceWidths(),
      3 => [lineWidth - qty - summary, qty, summary],
      2 => [lineWidth - summary, summary],
      1 => [lineWidth],
      _ => List.filled(columnCount, lineWidth ~/ columnCount),
    };
  }

  int _scaledWidth(int baseAt80mm, {required int min, required int max}) {
    final scaled = (lineWidth * baseAt80mm / 48).round();
    return scaled.clamp(min, max);
  }

  List<String> _alignsFor(int columnCount) {
    return switch (columnCount) {
      4 => const ['left', 'right', 'right', 'right'],
      3 => const ['left', 'right', 'right'],
      2 => const ['left', 'right'],
      _ => List.filled(columnCount, 'left'),
    };
  }

  String _joinCells(
    List<String> cells,
    List<int> widths,
    List<String> aligns,
  ) {
    final parts = <String>[];
    for (var i = 0; i < widths.length; i++) {
      final text = i < cells.length ? cells[i] : '';
      parts.add(_fit(text, widths[i], aligns[i]));
    }
    return parts.join();
  }

  String _fit(String text, int width, String align) {
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

  /// Word-wrap only — use with ESC/POS center/right alignment commands.
  List<String> wrapLines(String text, int width) {
    if (text.trim().isEmpty) return const [];

    final lines = <String>[];
    for (final part in text.split('\n')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      lines.addAll(_wrapText(trimmed, width));
    }
    return lines;
  }

  /// Word-wraps [text] then applies [align] per line within [width].
  /// Splits on newlines first so each address/header line is aligned on its own.
  List<String> wrapAligned(String text, int width, String align) {
    if (text.trim().isEmpty) return const [];

    final lines = <String>[];
    for (final part in text.split('\n')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      lines.addAll(
        _wrapText(trimmed, width).map((line) => _fit(line, width, align)),
      );
    }
    return lines;
  }

  List<String> _wrapText(String text, int width) {
    if (width <= 0 || text.isEmpty) return [text];
    if (text.length <= width) return [text];

    final lines = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = (start + width).clamp(0, text.length);
      if (end < text.length) {
        final slice = text.substring(start, end);
        final breakAt = slice.lastIndexOf(' ');
        if (breakAt > 0) {
          end = start + breakAt;
        }
      }
      lines.add(text.substring(start, end).trim());
      start = end;
      while (start < text.length && text[start] == ' ') {
        start++;
      }
    }
    return lines.isEmpty ? [''] : lines;
  }
}
