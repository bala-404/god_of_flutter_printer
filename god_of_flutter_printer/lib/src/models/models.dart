import 'enums.dart';

/// Describes how to reach a printer for a single job.
sealed class PrintConnection {
  const PrintConnection();

  const factory PrintConnection.network({
    required String host,
    int port,
  }) = NetworkPrintConnection;

  const factory PrintConnection.bluetooth({
    required String address,
  }) = BluetoothPrintConnection;

  const factory PrintConnection.ble({
    required String deviceId,
  }) = BlePrintConnection;

  const factory PrintConnection.usb({
    required String deviceId,
  }) = UsbPrintConnection;

  /// Chrome/web → local print agent webhook → USB printer on the same PC.
  const factory PrintConnection.localAgent({
    required String baseUrl,
    required String printerName,
  }) = LocalAgentPrintConnection;

  /// Chrome/web → local print agent webhook → Bluetooth printer on the same PC.
  const factory PrintConnection.bluetoothAgent({
    required String baseUrl,
    required String address,
  }) = BluetoothAgentPrintConnection;

  /// Chrome/web → local print agent webhook → TCP/IP printer on the LAN.
  const factory PrintConnection.networkAgent({
    required String baseUrl,
    required String host,
    int port,
  }) = NetworkAgentPrintConnection;

  String get summary;
}

final class NetworkPrintConnection extends PrintConnection {
  const NetworkPrintConnection({
    required this.host,
    this.port = 9100,
  });

  final String host;
  final int port;

  @override
  String get summary => '$host:$port';
}

final class BluetoothPrintConnection extends PrintConnection {
  const BluetoothPrintConnection({required this.address});

  final String address;

  @override
  String get summary => 'bt:$address';
}

final class BlePrintConnection extends PrintConnection {
  const BlePrintConnection({required this.deviceId});

  final String deviceId;

  @override
  String get summary => 'ble:$deviceId';
}

final class UsbPrintConnection extends PrintConnection {
  const UsbPrintConnection({required this.deviceId});

  final String deviceId;

  @override
  String get summary => 'usb:$deviceId';
}

final class LocalAgentPrintConnection extends PrintConnection {
  const LocalAgentPrintConnection({
    required this.baseUrl,
    required this.printerName,
  });

  final String baseUrl;
  final String printerName;

  @override
  String get summary => 'agent:$printerName@$baseUrl';
}

final class BluetoothAgentPrintConnection extends PrintConnection {
  const BluetoothAgentPrintConnection({
    required this.baseUrl,
    required this.address,
  });

  final String baseUrl;
  final String address;

  @override
  String get summary => 'bt-agent:$address@$baseUrl';
}

final class NetworkAgentPrintConnection extends PrintConnection {
  const NetworkAgentPrintConnection({
    required this.baseUrl,
    required this.host,
    this.port = 9100,
  });

  final String baseUrl;
  final String host;
  final int port;

  @override
  String get summary => 'net-agent:$host:$port@$baseUrl';
}

/// Payload supplied by the caller — format depends on [PrintMode].
sealed class PrintPayload {
  const PrintPayload();

  const factory PrintPayload.raw(List<int> bytes) = RawPrintPayload;

  const factory PrintPayload.text(
    String text, {
    String? charset,
  }) = TextPrintPayload;

  const factory PrintPayload.document(Map<String, dynamic> json) =
      DocumentPrintPayload;

  const factory PrintPayload.template({
    required String templateId,
    required Map<String, dynamic> data,
  }) = TemplatePrintPayload;
}

final class RawPrintPayload extends PrintPayload {
  const RawPrintPayload(this.bytes);

  final List<int> bytes;
}

final class TextPrintPayload extends PrintPayload {
  const TextPrintPayload(this.text, {this.charset});

  final String text;
  final String? charset;
}

final class DocumentPrintPayload extends PrintPayload {
  const DocumentPrintPayload(this.json);

  final Map<String, dynamic> json;
}

final class TemplatePrintPayload extends PrintPayload {
  const TemplatePrintPayload({
    required this.templateId,
    required this.data,
  });

  final String templateId;
  final Map<String, dynamic> data;
}

/// Options that control a single print execution.
class PrintOptions {
  const PrintOptions({
    this.timeout = const Duration(seconds: 15),
    this.retries = 1,
    this.prependInit = true,
    this.charset,
    this.allowRasterFallback = true,
  });

  final Duration timeout;
  final int retries;
  final bool prependInit;
  final String? charset;
  final bool allowRasterFallback;
}

/// Complete request for one stateless print job.
class PrintRequest {
  const PrintRequest({
    this.jobId,
    required this.connection,
    required this.protocol,
    required this.paperWidthMm,
    required this.mode,
    required this.payload,
    this.options = const PrintOptions(),
  });

  final String? jobId;
  final PrintConnection connection;
  final PrintProtocol protocol;
  final int paperWidthMm;
  final PrintMode mode;
  final PrintPayload payload;
  final PrintOptions options;
}

/// Final outcome stored in memory keyed by [jobId].
class JobResult {
  JobResult({
    required this.jobId,
    required this.status,
    required this.createdAt,
    required this.connectionSummary,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.errorCode,
    this.bytesSent = 0,
    this.protocol,
    this.paperWidthMm,
  });

  final String jobId;
  JobStatus status;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  String? errorMessage;
  String? errorCode;
  int bytesSent;
  final String connectionSummary;
  PrintProtocol? protocol;
  int? paperWidthMm;

  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  bool get isCompleted => status == JobStatus.completed;
  bool get isFailed => status == JobStatus.failed;
  bool get isRunning =>
      status == JobStatus.connecting ||
      status == JobStatus.sending ||
      status == JobStatus.encoding;

  JobResult copyWith({
    JobStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    String? errorCode,
    int? bytesSent,
    PrintProtocol? protocol,
    int? paperWidthMm,
  }) {
    return JobResult(
      jobId: jobId,
      status: status ?? this.status,
      createdAt: createdAt,
      connectionSummary: connectionSummary,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      bytesSent: bytesSent ?? this.bytesSent,
      protocol: protocol ?? this.protocol,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
    );
  }
}

/// Stream event emitted while a job progresses.
class JobEvent {
  const JobEvent({
    required this.jobId,
    required this.status,
    required this.timestamp,
    this.message,
  });

  final String jobId;
  final JobStatus status;
  final DateTime timestamp;
  final String? message;
}

/// Single log line tied to a [jobId].
class JobLogEntry {
  const JobLogEntry({
    required this.jobId,
    required this.timestamp,
    required this.level,
    required this.step,
    required this.message,
    this.meta,
  });

  final String jobId;
  final DateTime timestamp;
  final LogLevel level;
  final String step;
  final String message;
  final Map<String, dynamic>? meta;
}

/// Structured print document — protocol-neutral layout tree.
///
/// See [PrintDocumentBlock] for supported block types.
class PrintDocument {
  const PrintDocument({
    required this.blocks,
    this.locale,
  });

  factory PrintDocument.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List<dynamic>? ?? const [];
    return PrintDocument(
      locale: json['locale'] as String?,
      blocks: rawBlocks
          .map((b) => PrintDocumentBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<PrintDocumentBlock> blocks;
  final String? locale;

  Map<String, dynamic> toJson() => {
        if (locale != null) 'locale': locale,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };
}

/// One layout element inside a [PrintDocument].
class PrintDocumentBlock {
  const PrintDocumentBlock({
    required this.type,
    this.text,
    this.left,
    this.right,
    this.align,
    this.bold,
    this.size,
    this.locale,
    this.columns,
    this.rows,
    this.columnCount,
    this.layout,
    this.boldFirstColumn,
    this.boldHeader,
    this.value,
    this.lines,
    this.char,
  });

  factory PrintDocumentBlock.fromJson(Map<String, dynamic> json) {
    return PrintDocumentBlock(
      type: json['type'] as String,
      text: json['text'] as String?,
      left: json['left'] as String?,
      right: json['right'] as String?,
      align: json['align'] as String?,
      bold: json['bold'] as bool?,
      size: json['size'] as String?,
      locale: json['locale'] as String?,
      columns: (json['columns'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      rows: (json['rows'] as List<dynamic>?)
          ?.map((row) => (row as List<dynamic>).map((c) => c.toString()).toList())
          .toList(),
      columnCount: json['columnCount'] as int?,
      layout: json['layout'] as String?,
      boldFirstColumn: json['boldFirstColumn'] as bool?,
      boldHeader: json['boldHeader'] as bool?,
      value: json['value'] as String?,
      lines: json['lines'] as int?,
      char: json['char'] as String?,
    );
  }

  final String type;
  final String? text;
  final String? left;
  final String? right;
  final String? align;
  final bool? bold;
  final String? size;
  final String? locale;
  final List<String>? columns;
  final List<List<String>>? rows;
  final int? columnCount;
  final String? layout;
  final bool? boldFirstColumn;
  final bool? boldHeader;
  final String? value;
  final int? lines;
  final String? char;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (text != null) 'text': text,
        if (left != null) 'left': left,
        if (right != null) 'right': right,
        if (align != null) 'align': align,
        if (bold != null) 'bold': bold,
        if (size != null) 'size': size,
        if (locale != null) 'locale': locale,
        if (columns != null) 'columns': columns,
        if (rows != null) 'rows': rows,
        if (columnCount != null) 'columnCount': columnCount,
        if (layout != null) 'layout': layout,
        if (boldFirstColumn != null) 'boldFirstColumn': boldFirstColumn,
        if (boldHeader != null) 'boldHeader': boldHeader,
        if (value != null) 'value': value,
        if (lines != null) 'lines': lines,
        if (char != null) 'char': char,
      };
}

/// Template definition loaded from bundled JSON assets.
class PrintTemplate {
  const PrintTemplate({
    required this.id,
    required this.protocol,
    required this.paperWidthMm,
    required this.blocks,
  });

  factory PrintTemplate.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List<dynamic>? ?? const [];
    return PrintTemplate(
      id: json['id'] as String,
      protocol: _protocolFromString(json['protocol'] as String? ?? 'escpos'),
      paperWidthMm: json['paperWidthMm'] as int? ?? 80,
      blocks: rawBlocks
          .map((b) => TemplateBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final PrintProtocol protocol;
  final int paperWidthMm;
  final List<TemplateBlock> blocks;
}

class TemplateBlock {
  const TemplateBlock({
    required this.type,
    this.text,
    this.left,
    this.right,
    this.align,
    this.bold,
    this.size,
    this.locale,
    this.columns,
    this.rowTemplate,
    this.cells,
    this.columnCount,
    this.layout,
    this.boldFirstColumn,
    this.boldHeader,
    this.itemsField,
    this.value,
    this.lines,
    this.char,
    this.when,
    this.feedLines,
  });

  factory TemplateBlock.fromJson(Map<String, dynamic> json) {
    return TemplateBlock(
      type: json['type'] as String,
      text: json['text'] as String?,
      left: json['left'] as String?,
      right: json['right'] as String?,
      align: json['align'] as String?,
      bold: json['bold'] as bool?,
      size: json['size'] as String?,
      locale: json['locale'] as String?,
      columns: (json['columns'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      rowTemplate: (json['rowTemplate'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      cells: (json['cells'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      columnCount: json['columnCount'] as int?,
      layout: json['layout'] as String?,
      boldFirstColumn: json['boldFirstColumn'] as bool?,
      boldHeader: json['boldHeader'] as bool?,
      itemsField: json['itemsField'] as String?,
      value: json['value'] as String?,
      lines: json['lines'] as int?,
      char: json['char'] as String?,
      when: json['when'] as String?,
      feedLines: json['feedLines'] as int?,
    );
  }

  final String type;
  final String? text;
  final String? left;
  final String? right;
  final String? align;
  final bool? bold;
  final String? size;
  final String? locale;
  final List<String>? columns;
  final List<String>? rowTemplate;
  final List<String>? cells;
  final int? columnCount;
  final String? layout;
  final bool? boldFirstColumn;
  final bool? boldHeader;
  final String? itemsField;
  final String? value;
  final int? lines;
  final String? char;

  /// Data key that must be non-empty for this block to render.
  final String? when;

  /// Lines to feed immediately before cutting (merged into GS V 66).
  final int? feedLines;
}

PrintProtocol _protocolFromString(String value) {
  switch (value.toLowerCase()) {
    case 'tspl':
      return PrintProtocol.tspl;
    case 'zpl':
      return PrintProtocol.zpl;
    case 'escpos':
    default:
      return PrintProtocol.escPos;
  }
}
