import 'dart:convert';

import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

/// Formats [PrintRequest] and encoded bytes for the example app debug panel.
class PayloadPreview {
  PayloadPreview._();

  static String dartCode(PrintRequest request) {
    final buffer = StringBuffer()
      ..writeln("import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';")
      ..writeln()
      ..writeln('final jobId = await PrintWorker.instance.execute(')
      ..writeln('  PrintRequest(')
      ..writeln('    connection: ${_connectionCode(request.connection)},')
      ..writeln('    protocol: PrintProtocol.${request.protocol.name},')
      ..writeln('    paperWidthMm: ${request.paperWidthMm},')
      ..writeln('    mode: PrintMode.${request.mode.name},')
      ..writeln('    payload: ${_payloadCode(request.payload)},')
      ..writeln('    options: ${_optionsCode(request.options)},')
      ..writeln('  ),')
      ..writeln(');');

    return buffer.toString();
  }

  static String jsonRequest(PrintRequest request) {
    final map = <String, dynamic>{
      'connection': _connectionJson(request.connection),
      'protocol': request.protocol.name,
      'paperWidthMm': request.paperWidthMm,
      'mode': request.mode.name,
      'payload': _payloadJson(request.payload),
      'options': {
        'prependInit': request.options.prependInit,
        'allowRasterFallback': request.options.allowRasterFallback,
        'retries': request.options.retries,
        'timeoutMs': request.options.timeout.inMilliseconds,
        if (request.options.charset != null)
          'charset': request.options.charset,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static String hexDump(List<int> bytes, {int maxBytes = 384}) {
    if (bytes.isEmpty) return '(empty — nothing encoded yet)';

    final shown = bytes.length > maxBytes ? bytes.sublist(0, maxBytes) : bytes;
    final lines = <String>[];
    const perLine = 16;

    for (var offset = 0; offset < shown.length; offset += perLine) {
      final end = (offset + perLine).clamp(0, shown.length);
      final chunk = shown.sublist(offset, end);

      final hex = chunk
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ')
          .padRight(perLine * 3 - 1);

      final ascii = chunk
          .map((b) => (b >= 0x20 && b <= 0x7E) ? String.fromCharCode(b) : '.')
          .join();

      lines.add(
        '${offset.toRadixString(16).padLeft(4, '0').toUpperCase()}: '
        '$hex  |$ascii|',
      );
    }

    final summary = StringBuffer()
      ..writeln('Total bytes: ${bytes.length}')
      ..writeln(_escPosLegend(bytes))
      ..writeln()
      ..write(lines.join('\n'));

    if (bytes.length > maxBytes) {
      summary.write('\n\n... truncated (${bytes.length - maxBytes} more bytes)');
    }

    return summary.toString();
  }

  static String _escPosLegend(List<int> bytes) {
    final tags = <String>[];
    if (bytes.length >= 2 && bytes[0] == 0x1B && bytes[1] == 0x40) {
      tags.add('ESC @ init');
    }
    for (var i = 0; i < bytes.length - 2; i++) {
      if (bytes[i] == 0x1B && bytes[i + 1] == 0x2A) {
        tags.add('ESC * raster');
        break;
      }
      if (bytes[i] == 0x1D && bytes[i + 1] == 0x76) {
        tags.add('GS v 0 image');
        break;
      }
    }
    if (bytes.length >= 3 && bytes[bytes.length - 3] == 0x1D) {
      tags.add('GS V cut');
    }
    return tags.isEmpty ? 'Commands: (see hex)' : 'Detected: ${tags.join(', ')}';
  }

  static String _connectionCode(PrintConnection connection) {
    return switch (connection) {
      NetworkPrintConnection(:final host, :final port) =>
        "PrintConnection.network(host: ${_quote(host)}, port: $port)",
      UsbPrintConnection(:final deviceId) =>
        "PrintConnection.usb(deviceId: ${_quote(deviceId)})",
      LocalAgentPrintConnection(:final baseUrl, :final printerName) =>
        'PrintConnection.localAgent(baseUrl: ${_quote(baseUrl)}, printerName: ${_quote(printerName)})',
      BluetoothAgentPrintConnection(:final baseUrl, :final address) =>
        'PrintConnection.bluetoothAgent(baseUrl: ${_quote(baseUrl)}, address: ${_quote(address)})',
      NetworkAgentPrintConnection(:final baseUrl, :final host, :final port) =>
        'PrintConnection.networkAgent(baseUrl: ${_quote(baseUrl)}, host: ${_quote(host)}, port: $port)',
      BluetoothPrintConnection(:final address) =>
        "PrintConnection.bluetooth(address: ${_quote(address)})",
      BlePrintConnection(:final deviceId) =>
        "PrintConnection.ble(deviceId: ${_quote(deviceId)})",
    };
  }

  static Map<String, dynamic> _connectionJson(PrintConnection connection) {
    return switch (connection) {
      NetworkPrintConnection(:final host, :final port) => {
          'type': 'network',
          'host': host,
          'port': port,
        },
      UsbPrintConnection(:final deviceId) => {
          'type': 'usb',
          'deviceId': deviceId,
        },
      LocalAgentPrintConnection(:final baseUrl, :final printerName) => {
          'type': 'localAgent',
          'baseUrl': baseUrl,
          'printerName': printerName,
        },
      BluetoothAgentPrintConnection(:final baseUrl, :final address) => {
          'type': 'bluetoothAgent',
          'baseUrl': baseUrl,
          'address': address,
        },
      NetworkAgentPrintConnection(:final baseUrl, :final host, :final port) => {
          'type': 'networkAgent',
          'baseUrl': baseUrl,
          'host': host,
          'port': port,
        },
      BluetoothPrintConnection(:final address) => {
          'type': 'bluetooth',
          'address': address,
        },
      BlePrintConnection(:final deviceId) => {
          'type': 'ble',
          'deviceId': deviceId,
        },
    };
  }

  static String _payloadCode(PrintPayload payload) {
    return switch (payload) {
      TextPrintPayload(:final text, :final charset) =>
        charset == null
            ? 'PrintPayload.text(${_quote(text)})'
            : 'PrintPayload.text(${_quote(text)}, charset: ${_quote(charset)})',
      TemplatePrintPayload(:final templateId, :final data) =>
        'PrintPayload.template(\n'
        '      templateId: ${_quote(templateId)},\n'
        '      data: ${_mapLiteral(data)},\n'
        '    )',
      DocumentPrintPayload(:final json) =>
        'PrintPayload.document(\n      ${_mapLiteral(json)},\n    )',
      RawPrintPayload(:final bytes) =>
        bytes.length <= 32
            ? 'PrintPayload.raw($bytes)'
            : 'PrintPayload.raw(/* ${bytes.length} bytes — see hex tab */)',
    };
  }

  static Map<String, dynamic> _payloadJson(PrintPayload payload) {
    return switch (payload) {
      TextPrintPayload(:final text, :final charset) => {
          'type': 'text',
          'text': text,
          if (charset != null) 'charset': charset,
        },
      TemplatePrintPayload(:final templateId, :final data) => {
          'type': 'template',
          'templateId': templateId,
          'data': data,
        },
      DocumentPrintPayload(:final json) => {
          'type': 'document',
          'json': json,
        },
      RawPrintPayload(:final bytes) => {
          'type': 'raw',
          'byteCount': bytes.length,
          'previewHex': bytes
              .take(64)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(' '),
        },
    };
  }

  static String _optionsCode(PrintOptions options) {
    final parts = <String>[
      'allowRasterFallback: ${options.allowRasterFallback}',
      'prependInit: ${options.prependInit}',
    ];
    if (options.charset != null) {
      parts.add('charset: ${_quote(options.charset!)}');
    }
    return 'PrintOptions(${parts.join(', ')})';
  }

  static String _quote(String value) {
    return "'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n')}'";
  }

  static String _mapLiteral(Map<String, dynamic> map, {int indent = 6}) {
    final pad = ' ' * indent;
    final inner = map.entries.map((entry) {
      final key = entry.key;
      final value = entry.value;
      return '$pad${_quote(key)}: ${_valueLiteral(value, indent: indent + 2)},';
    });
    return '{\n${inner.join('\n')}\n${' ' * (indent - 2)}}';
  }

  static String _valueLiteral(Object? value, {required int indent}) {
    if (value == null) return 'null';
    if (value is String) return _quote(value);
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      if (value.isEmpty) return '[]';
      final pad = ' ' * indent;
      final items = value.map((item) {
        return '$pad${_valueLiteral(item, indent: indent + 2)},';
      });
      return '[\n${items.join('\n')}\n${' ' * (indent - 2)}]';
    }
    if (value is Map) {
      return _mapLiteral(Map<String, dynamic>.from(value), indent: indent);
    }
    return _quote(value.toString());
  }
}
