import 'dart:convert';

import 'package:flutter/services.dart';

import '../encoders/receipt_line_formatter.dart';
import '../models/models.dart';
import '../utils/package_assets.dart';

/// Resolves bundled template JSON assets.
class TemplateRepository {
  TemplateRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, PrintTemplate> _cache = {};

  Future<PrintTemplate> load(String templateId) async {
    final raw = await PackageAssets.loadString(
      'assets/templates/$templateId.json',
      bundle: _bundle,
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final template = PrintTemplate.fromJson(json);
    _cache[templateId] = template;
    return template;
  }

  /// Clears cached templates (call after template JSON changes during dev).
  void clearCache() => _cache.clear();
}

/// Merges template placeholders with runtime data and renders a document.
class TemplateEngine {
  TemplateEngine(this._repository);

  final TemplateRepository _repository;

  Future<PrintDocument> render({
    required String templateId,
    required Map<String, dynamic> data,
  }) async {
    final template = await _repository.load(templateId);
    final blocks = <PrintDocumentBlock>[];

    for (final block in template.blocks) {
      if (!_shouldRenderBlock(block, data)) continue;
      blocks.addAll(_renderBlock(block, data));
    }

    return PrintDocument(
      locale: data['locale'] as String?,
      blocks: blocks,
    );
  }

  bool _shouldRenderBlock(TemplateBlock block, Map<String, dynamic> data) {
    if (block.when != null && block.when!.isNotEmpty) {
      if (_isEmptyValue(data[block.when])) return false;
    }

    switch (block.type) {
      case 'table':
        if (block.cells != null && block.cells!.isNotEmpty) {
          return block.cells!
              .map((cell) => _interpolate(cell, data).trim())
              .any((cell) => cell.isNotEmpty);
        }
        final itemsField = block.itemsField ?? 'items';
        final items = data[itemsField] as List<dynamic>?;
        return items != null && items.isNotEmpty;
      case 'text':
        final text = _interpolate(block.text ?? '', data).trim();
        return text.isNotEmpty;
      case 'qr':
        final value = _interpolate(block.value ?? '', data).trim();
        return value.isNotEmpty;
      case 'row':
        final left = _interpolate(block.left ?? '', data).trim();
        final right = _interpolate(block.right ?? '', data).trim();
        if (left.isEmpty && right.isEmpty) return false;
        if (left.isEmpty) return right.isNotEmpty;
        if (right.isEmpty) return left.isNotEmpty;
        return true;
      default:
        return true;
    }
  }

  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  List<PrintDocumentBlock> _renderBlock(
    TemplateBlock block,
    Map<String, dynamic> data,
  ) {
    switch (block.type) {
      case 'text':
        return [
          PrintDocumentBlock(
            type: 'text',
            text: _interpolate(block.text ?? '', data),
            align: block.align,
            bold: block.bold,
            size: block.size,
            locale: block.locale,
          ),
        ];
      case 'line':
        return [
          PrintDocumentBlock(
            type: 'line',
            char: block.char ?? '-',
          ),
        ];
      case 'feed':
        return [
          PrintDocumentBlock(
            type: 'feed',
            lines: block.lines ?? 1,
          ),
        ];
      case 'cut':
        return [
          PrintDocumentBlock(
            type: 'cut',
            lines: block.feedLines,
          ),
        ];
      case 'qr':
        return [
          PrintDocumentBlock(
            type: 'qr',
            value: _interpolate(block.value ?? '', data),
          ),
        ];
      case 'row':
        return [
          PrintDocumentBlock(
            type: 'row',
            left: _interpolate(block.left ?? '', data),
            right: _interpolate(block.right ?? '', data),
            bold: block.bold,
            locale: block.locale,
          ),
        ];
      case 'table':
        if (block.cells != null && block.cells!.isNotEmpty) {
          final cells =
              block.cells!.map((cell) => _interpolate(cell, data)).toList();
          return [
            PrintDocumentBlock(
              type: 'table',
              rows: [cells],
              columnCount: block.columnCount ?? cells.length,
              layout: block.layout,
              bold: block.bold,
              boldFirstColumn: block.boldFirstColumn,
              boldHeader: block.boldHeader,
              locale: block.locale,
            ),
          ];
        }
        final itemsField = block.itemsField ?? 'items';
        final items = data[itemsField] as List<dynamic>? ?? const [];
        final rows = <List<String>>[];
        for (final item in items) {
          final map = item as Map<String, dynamic>;
          if (block.rowTemplate != null) {
            rows.add(
              block.rowTemplate!
                  .map((cell) => _interpolate(cell, map))
                  .toList(),
            );
          }
        }
        return [
          PrintDocumentBlock(
            type: 'table',
            columns: block.columns == null
                ? null
                : ReceiptLineFormatter.normalizeColumns(block.columns!),
            rows: rows,
            columnCount: block.columnCount,
            layout: block.layout ??
                ReceiptLineFormatter.resolveLayout(
                  null,
                  ReceiptLineFormatter.normalizeColumns(block.columns ?? const []),
                ),
            bold: block.bold,
            boldFirstColumn: block.boldFirstColumn,
            boldHeader: block.boldHeader,
            locale: block.locale,
          ),
        ];
      default:
        return [
          PrintDocumentBlock(
            type: 'text',
            text: '[unknown template block: ${block.type}]',
          ),
        ];
    }
  }

  String _interpolate(String input, Map<String, dynamic> data) {
    return input.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (match) {
      final key = match.group(1)!;
      final value = data[key];
      return value?.toString() ?? '';
    });
  }
}
