import '../models/enums.dart';

/// Unified print job JSON from your DB / API — same shape for every POS user.
///
/// Unused fields stay empty (`""`, `{}`, `0`). The package resolves which
/// printer fields matter based on runtime platform (web vs Windows/Android/iOS).
class PrintJobBody {
  const PrintJobBody({
    this.jobId = '',
    this.type = 'template',
    this.templateId = '',
    this.data = const {},
    this.text = '',
    this.document = const {},
    this.bytes = '',
    this.printer = const PrinterJobConfig(),
    this.protocol = 'escPos',
    this.paperWidthMm = 80,
    this.charset = '',
    this.options = const PrintJobOptions(),
  });

  /// Empty template job — fill from DB or copy as a starting point.
  factory PrintJobBody.emptyTemplate() {
    return const PrintJobBody();
  }

  factory PrintJobBody.fromMap(Map<String, dynamic> map) {
    final printerMap = map['printer'];
    var printer = printerMap is Map
        ? PrinterJobConfig.fromMap(Map<String, dynamic>.from(printerMap))
        : PrinterJobConfig.fromMap(map);

    final rootHub = _str(map['hubUrl'] ?? map['hub_url']);
    if (!printer.hasHubUrl && rootHub.isNotEmpty) {
      printer = PrinterJobConfig(
        connectionType: printer.connectionType,
        brand: printer.brand,
        printerName: printer.printerName,
        ip: printer.ip,
        port: printer.port,
        address: printer.address,
        hubUrl: rootHub,
      );
    }

    final optionsMap = map['options'];

    return PrintJobBody(
      jobId: _str(map['jobId']),
      type: _str(map['type']).isEmpty ? 'template' : _str(map['type']),
      templateId: _str(map['templateId']),
      data: _map(map['data']),
      text: _str(map['text']),
      document: _map(map['document']),
      bytes: _str(map['bytes']),
      printer: printer,
      protocol: _str(map['protocol']).isEmpty ? 'escPos' : _str(map['protocol']),
      paperWidthMm: _readInt(map['paperWidthMm']) ?? 80,
      charset: _str(map['charset']),
      options: optionsMap is Map
          ? PrintJobOptions.fromMap(Map<String, dynamic>.from(optionsMap))
          : PrintJobOptions.fromMap(map),
    );
  }

  final String jobId;
  final String type;
  final String templateId;
  final Map<String, dynamic> data;
  final String text;
  final Map<String, dynamic> document;
  final String bytes;
  final PrinterJobConfig printer;
  final String protocol;
  final int paperWidthMm;
  final String charset;
  final PrintJobOptions options;

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'type': type,
        'templateId': templateId,
        'data': data,
        'text': text,
        'document': document,
        'bytes': bytes,
        'printer': printer.toMap(),
        'protocol': protocol,
        'paperWidthMm': paperWidthMm,
        'charset': charset,
        'options': options.toMap(),
      };

  static String _str(dynamic value) => value?.toString().trim() ?? '';

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// Printer row from DB — all keys present; unused values are empty.
class PrinterJobConfig {
  const PrinterJobConfig({
    this.connectionType = '',
    this.brand = '',
    this.printerName = '',
    this.ip = '',
    this.port = 9100,
    this.address = '',
    this.hubUrl = '',
  });

  factory PrinterJobConfig.fromMap(Map<String, dynamic> map) {
    final merged = Map<String, dynamic>.from(map);
    final nested = map['connection'];
    if (nested is Map) {
      merged.addAll(Map<String, dynamic>.from(nested));
    }

    return PrinterJobConfig(
      connectionType: _str(
        merged['connectionType'] ?? merged['connection_type'] ?? merged['transport'],
      ),
      brand: _str(merged['brand']),
      printerName: _str(merged['printerName'] ?? merged['name']),
      ip: _str(merged['ip'] ?? merged['host']),
      port: _readPort(merged['port']),
      address: _str(merged['address'] ?? merged['bluetoothAddress']),
      hubUrl: _str(merged['hubUrl'] ?? merged['hub_url']),
    );
  }

  final String connectionType;
  final String brand;
  final String printerName;
  final String ip;
  final int port;
  final String address;
  final String hubUrl;

  bool get hasPrinterName => printerName.isNotEmpty;
  bool get hasIp => ip.isNotEmpty;
  bool get hasBluetooth => address.isNotEmpty;
  bool get hasHubUrl => hubUrl.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'connectionType': connectionType,
        'brand': brand,
        'printerName': printerName,
        'ip': ip,
        'port': port,
        'address': address,
        'hubUrl': hubUrl,
      };

  static String _str(dynamic value) => value?.toString().trim() ?? '';

  static int _readPort(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return 9100;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 9100;
  }
}

class PrintJobOptions {
  const PrintJobOptions({
    this.timeoutMs = 15000,
    this.retries = 1,
    this.prependInit = true,
    this.allowRasterFallback = true,
  });

  factory PrintJobOptions.fromMap(Map<String, dynamic> map) {
    return PrintJobOptions(
      timeoutMs: _readInt(map['timeoutMs']) ?? 15000,
      retries: _readInt(map['retries']) ?? 1,
      prependInit: map['prependInit'] as bool? ?? true,
      allowRasterFallback: map['allowRasterFallback'] as bool? ?? true,
    );
  }

  final int timeoutMs;
  final int retries;
  final bool prependInit;
  final bool allowRasterFallback;

  Map<String, dynamic> toMap() => {
        'timeoutMs': timeoutMs,
        'retries': retries,
        'prependInit': prependInit,
        'allowRasterFallback': allowRasterFallback,
      };

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

PrintProtocol? parsePrintProtocol(String raw) {
  if (raw.isEmpty) return null;
  for (final protocol in PrintProtocol.values) {
    if (protocol.name == raw) return protocol;
  }
  return null;
}

PrintMode parsePrintMode(String raw) {
  return switch (raw.toLowerCase()) {
    'text' => PrintMode.text,
    'document' => PrintMode.document,
    'raw' => PrintMode.raw,
    _ => PrintMode.template,
  };
}
