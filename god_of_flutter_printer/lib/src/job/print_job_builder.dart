import 'dart:convert';
import 'dart:typed_data';

import '../models/enums.dart';
import '../models/models.dart';
import 'print_connection_resolver.dart';
import 'print_job_defaults.dart';
import 'print_job_spec.dart';

/// Builds [PrintRequest] from a validated [PrintJobSpec].
class PrintJobBuilder {
  PrintJobBuilder._();

  static PrintRequest toRequest(PrintJobSpec spec) {
    return PrintRequest(
      jobId: spec.jobId,
      connection: PrintConnectionResolver.resolve(
        target: spec.connection,
        hubUrl: spec.hubUrl,
      ),
      protocol: spec.protocol ?? PrintJobDefaults.protocol,
      paperWidthMm: spec.paperWidthMm ?? PrintJobDefaults.paperWidthMm,
      mode: spec.mode,
      payload: _toPayload(spec),
      options: PrintOptions(
        timeout: spec.timeout ?? PrintJobDefaults.timeout,
        retries: spec.retries ?? PrintJobDefaults.retries,
        prependInit: spec.prependInit,
        charset: spec.charset,
        allowRasterFallback: spec.allowRasterFallback,
      ),
    );
  }

  static PrintPayload _toPayload(PrintJobSpec spec) {
    return switch (spec.mode) {
      PrintMode.template => PrintPayload.template(
          templateId: spec.payload['templateId'].toString(),
          data: Map<String, dynamic>.from(
            spec.payload['data'] as Map,
          ),
        ),
      PrintMode.text => PrintPayload.text(
          spec.payload['text'].toString(),
          charset: spec.payload['charset']?.toString(),
        ),
      PrintMode.document => PrintPayload.document(
          Map<String, dynamic>.from(spec.payload['document'] as Map),
        ),
      PrintMode.raw => PrintPayload.raw(_decodeRawBytes(spec.payload['bytes'])),
    };
  }

  static List<int> _decodeRawBytes(dynamic bytes) {
    if (bytes is List) {
      return bytes.cast<int>();
    }
    if (bytes is Uint8List) {
      return bytes;
    }
    if (bytes is String) {
      return base64Decode(bytes);
    }
    return const [];
  }
}
