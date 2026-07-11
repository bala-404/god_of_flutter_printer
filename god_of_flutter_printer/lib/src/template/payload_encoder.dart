import 'dart:typed_data';

import '../encoders/encoders.dart';
import '../models/enums.dart';
import '../models/models.dart';
import 'template_engine.dart';

/// Converts [PrintRequest] payload + mode into protocol bytes.
class PayloadEncoder {
  PayloadEncoder({
    TemplateEngine? templateEngine,
  }) : _templateEngine = templateEngine;

  final TemplateEngine? _templateEngine;

  Future<Uint8List> encode(PrintRequest request) async {
    switch (request.mode) {
      case PrintMode.raw:
        return _encodeRaw(request);
      case PrintMode.text:
        return _encodeText(request);
      case PrintMode.document:
        return _encodeDocument(request);
      case PrintMode.template:
        return _encodeTemplate(request);
    }
  }

  EscPosEncoder _escPosEncoder(PrintRequest request) {
    return EscPosEncoder(
      paperWidthMm: request.paperWidthMm,
      prependInit: request.options.prependInit,
      charset: request.options.charset ?? 'utf8',
      allowRasterFallback: request.options.allowRasterFallback,
    );
  }

  Future<Uint8List> _encodeRaw(PrintRequest request) async {
    final payload = request.payload as RawPrintPayload;
    switch (request.protocol) {
      case PrintProtocol.escPos:
        final bytes = payload.bytes;
        if (bytes.isEmpty) {
          return _escPosEncoder(request).encodeText('');
        }
        return _escPosEncoder(request).wrapRaw(bytes);
      case PrintProtocol.tspl:
      case PrintProtocol.zpl:
        return Uint8List.fromList(payload.bytes);
    }
  }

  Future<Uint8List> _encodeText(PrintRequest request) async {
    final payload = request.payload as TextPrintPayload;
    switch (request.protocol) {
      case PrintProtocol.escPos:
        return _escPosEncoder(request).encodeText(
          payload.text,
          locale: payload.charset ?? request.options.charset,
        );
      case PrintProtocol.tspl:
        return TsplEncoder(paperWidthMm: request.paperWidthMm)
            .encodeText(payload.text);
      case PrintProtocol.zpl:
        return ZplEncoder(paperWidthMm: request.paperWidthMm)
            .encodeText(payload.text);
    }
  }

  Future<Uint8List> _encodeDocument(PrintRequest request) async {
    final payload = request.payload as DocumentPrintPayload;
    final document = PrintDocument.fromJson(payload.json);
    switch (request.protocol) {
      case PrintProtocol.escPos:
        return _escPosEncoder(request).encodeDocument(document);
      case PrintProtocol.tspl:
        final text = document.blocks
            .where((b) => b.type == 'text')
            .map((b) => b.text ?? '')
            .join('\n');
        return TsplEncoder(paperWidthMm: request.paperWidthMm).encodeText(text);
      case PrintProtocol.zpl:
        final text = document.blocks
            .where((b) => b.type == 'text')
            .map((b) => b.text ?? '')
            .join('\n');
        return ZplEncoder(paperWidthMm: request.paperWidthMm).encodeText(text);
    }
  }

  Future<Uint8List> _encodeTemplate(PrintRequest request) async {
    final payload = request.payload as TemplatePrintPayload;
    if (_templateEngine == null) {
      throw StateError(
        'TemplateEngine is required for PrintMode.template requests.',
      );
    }
    final document = await _templateEngine.render(
      templateId: payload.templateId,
      data: payload.data,
    );
    return _encodeDocument(
      PrintRequest(
        connection: request.connection,
        protocol: request.protocol,
        paperWidthMm: request.paperWidthMm,
        mode: PrintMode.document,
        payload: PrintPayload.document(document.toJson()),
        options: request.options,
      ),
    );
  }
}
