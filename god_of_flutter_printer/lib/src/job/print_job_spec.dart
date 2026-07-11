import '../models/enums.dart';
import 'print_job_body.dart';
import 'print_job_defaults.dart';
import 'print_job_resolver.dart';
import 'print_target.dart';

/// One self-contained print job — connection and payload travel together.
///
/// Every call must include [connection] (and [hubUrl] on web). No global printer
/// config; different items can target different printers/brands/methods.
class PrintJobSpec {
  const PrintJobSpec({
    required this.mode,
    required this.payload,
    required this.connection,
    this.hubUrl,
    this.protocol,
    this.paperWidthMm,
    this.timeout,
    this.retries,
    this.prependInit = true,
    this.allowRasterFallback = true,
    this.charset,
    this.jobId,
  });

  factory PrintJobSpec.template({
    required String templateId,
    required Map<String, dynamic> data,
    required PrintTarget connection,
    String? hubUrl,
    PrintProtocol? protocol,
    int? paperWidthMm,
    Duration? timeout,
    int? retries,
    String? jobId,
  }) {
    return PrintJobSpec(
      mode: PrintMode.template,
      payload: {
        'templateId': templateId,
        'data': data,
      },
      connection: connection,
      hubUrl: hubUrl,
      protocol: protocol,
      paperWidthMm: paperWidthMm,
      timeout: timeout,
      retries: retries,
      jobId: jobId,
    );
  }

  factory PrintJobSpec.text({
    required String text,
    required PrintTarget connection,
    String? charset,
    String? hubUrl,
    PrintProtocol? protocol,
    int? paperWidthMm,
    Duration? timeout,
    int? retries,
    String? jobId,
  }) {
    return PrintJobSpec(
      mode: PrintMode.text,
      payload: {
        'text': text,
        if (charset != null) 'charset': charset,
      },
      connection: connection,
      hubUrl: hubUrl,
      protocol: protocol,
      paperWidthMm: paperWidthMm,
      timeout: timeout,
      retries: retries,
      charset: charset,
      jobId: jobId,
    );
  }

  /// Builds from unified DB JSON ([PrintJobBody]) or legacy flat maps.
  factory PrintJobSpec.fromMap(Map<String, dynamic> map) {
    return PrintJobResolver.toSpec(PrintJobBody.fromMap(map));
  }

  final PrintMode mode;
  final Map<String, dynamic> payload;
  final PrintTarget connection;
  final String? hubUrl;
  final PrintProtocol? protocol;
  final int? paperWidthMm;
  final Duration? timeout;
  final int? retries;
  final bool prependInit;
  final bool allowRasterFallback;
  final String? charset;
  final String? jobId;

  Map<String, dynamic> toMap() {
    final printer = connection.toMap();
    if (hubUrl != null && hubUrl!.isNotEmpty) {
      printer['hubUrl'] = hubUrl;
    }
    return PrintJobBody(
      jobId: jobId ?? '',
      type: mode.name,
      templateId: payload['templateId']?.toString() ?? '',
      data: payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'] as Map)
          : {},
      text: payload['text']?.toString() ?? '',
      document: payload['document'] is Map
          ? Map<String, dynamic>.from(payload['document'] as Map)
          : {},
      bytes: payload['bytes']?.toString() ?? '',
      printer: PrinterJobConfig.fromMap(printer),
      protocol: protocol?.name ?? 'escPos',
      paperWidthMm: paperWidthMm ?? PrintJobDefaults.paperWidthMm,
      charset: charset ?? '',
      options: PrintJobOptions(
        timeoutMs: timeout?.inMilliseconds ?? PrintJobDefaults.timeout.inMilliseconds,
        retries: retries ?? PrintJobDefaults.retries,
        prependInit: prependInit,
        allowRasterFallback: allowRasterFallback,
      ),
    ).toMap();
  }
}
