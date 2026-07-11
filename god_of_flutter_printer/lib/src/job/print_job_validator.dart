import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../models/enums.dart';
import 'print_job_defaults.dart';
import 'print_job_field_error.dart';
import 'print_job_spec.dart';
import 'print_target.dart';

/// Synchronous, zero-I/O validation — fails instantly before any print work.
class PrintJobValidator {
  PrintJobValidator._();

  static final _hostPattern = RegExp(
    r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*'
    r'[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
  );

  static final _ipv4Pattern = RegExp(
    r'^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}'
    r'(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$',
  );

  static final _bluetoothMacPattern = RegExp(
    r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$',
  );

  static final _bleUuidPattern = RegExp(
    r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
  );

  /// Validates [spec] without network or native calls.
  static PrintJobValidationResult validate(PrintJobSpec spec) {
    final errors = <PrintJobFieldError>[];

    _validatePayload(spec, errors);
    _validatePaper(spec, errors);
    _validateOptions(spec, errors);
    _validateTarget(spec.connection, errors);
    _validatePlatform(spec.connection, errors);
    _validateHubUrl(spec, errors);

    if (errors.isEmpty) {
      return PrintJobValidationResult.valid;
    }
    return PrintJobValidationResult.invalid(errors);
  }

  static void _validateHubUrl(PrintJobSpec spec, List<PrintJobFieldError> errors) {
    if (kIsWeb) {
      final hub = spec.hubUrl?.trim() ?? '';
      if (hub.isEmpty) {
        errors.add(const PrintJobFieldError(
          field: 'hubUrl',
          message: 'hubUrl is required on web for every job',
        ));
      } else if (!_isHttpUrl(hub)) {
        errors.add(const PrintJobFieldError(
          field: 'hubUrl',
          message: 'hubUrl must start with http:// or https://',
        ));
      }
    } else {
      // hubUrl in DB JSON is ignored on native (web-only field).
    }
  }

  static void _validatePayload(PrintJobSpec spec, List<PrintJobFieldError> errors) {
    switch (spec.mode) {
      case PrintMode.template:
        final templateId = spec.payload['templateId']?.toString().trim() ?? '';
        if (templateId.isEmpty) {
          errors.add(const PrintJobFieldError(
            field: 'templateId',
            message: 'templateId is required for template jobs',
          ));
        }
        final data = spec.payload['data'];
        if (data is! Map) {
          errors.add(const PrintJobFieldError(
            field: 'data',
            message: 'data object is required for template jobs',
          ));
        }
      case PrintMode.text:
        final text = spec.payload['text']?.toString() ?? '';
        if (text.trim().isEmpty) {
          errors.add(const PrintJobFieldError(
            field: 'text',
            message: 'text is required for text jobs',
          ));
        }
      case PrintMode.document:
        final doc = spec.payload['document'];
        if (doc is! Map || doc.isEmpty) {
          errors.add(const PrintJobFieldError(
            field: 'document',
            message: 'document object is required for document jobs',
          ));
        }
      case PrintMode.raw:
        final bytes = spec.payload['bytes'];
        if (bytes == null ||
            (bytes is List && bytes.isEmpty) ||
            (bytes is String && bytes.trim().isEmpty)) {
          errors.add(const PrintJobFieldError(
            field: 'bytes',
            message: 'bytes (base64 or byte list) is required for raw jobs',
          ));
        }
    }
  }

  static void _validatePaper(PrintJobSpec spec, List<PrintJobFieldError> errors) {
    final width = spec.paperWidthMm ?? PrintJobDefaults.paperWidthMm;
    if (!supportedPaperWidthsMm.contains(width)) {
      errors.add(PrintJobFieldError(
        field: 'paperWidthMm',
        message:
            'paperWidthMm must be one of ${supportedPaperWidthsMm.join(', ')} (got $width)',
      ));
    }
  }

  static void _validateOptions(PrintJobSpec spec, List<PrintJobFieldError> errors) {
    if (spec.retries != null && spec.retries! < 1) {
      errors.add(const PrintJobFieldError(
        field: 'retries',
        message: 'retries must be at least 1',
      ));
    }
    if (spec.timeout != null && spec.timeout!.inMilliseconds < 1000) {
      errors.add(const PrintJobFieldError(
        field: 'timeout',
        message: 'timeout must be at least 1000 ms',
      ));
    }
  }

  static void _validateTarget(PrintTarget target, List<PrintJobFieldError> errors) {
    switch (target.kind) {
      case PrintConnectionKind.usb:
        final name = target.printerName?.trim() ?? '';
        if (name.isEmpty) {
          errors.add(const PrintJobFieldError(
            field: 'connection.printerName',
            message: 'printerName is required for USB printing',
          ));
        }
      case PrintConnectionKind.bluetooth:
        final address = target.address?.trim() ?? '';
        if (address.isEmpty) {
          errors.add(PrintJobFieldError(
            field: 'connection.address',
            message: defaultTargetPlatform == TargetPlatform.iOS
                ? 'Bluetooth device UUID is required for iOS BLE printing'
                : 'Bluetooth address is required (AA:BB:CC:DD:EE:FF)',
          ));
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          if (!_bleUuidPattern.hasMatch(address)) {
            errors.add(PrintJobFieldError(
              field: 'connection.address',
              message:
                  'Invalid Bluetooth device UUID for iOS: $address',
            ));
          }
        } else if (!_bluetoothMacPattern.hasMatch(address)) {
          errors.add(PrintJobFieldError(
            field: 'connection.address',
            message: 'Invalid Bluetooth address format: $address',
          ));
        }
      case PrintConnectionKind.network:
        final host = target.host?.trim() ?? '';
        if (host.isEmpty) {
          errors.add(const PrintJobFieldError(
            field: 'connection.host',
            message: 'host (IP address) is required for network printing',
          ));
        } else if (!_ipv4Pattern.hasMatch(host) && !_hostPattern.hasMatch(host)) {
          errors.add(PrintJobFieldError(
            field: 'connection.host',
            message: 'Invalid host or IP address: $host',
          ));
        }
        if (target.port < 1 || target.port > 65535) {
          errors.add(PrintJobFieldError(
            field: 'connection.port',
            message: 'port must be between 1 and 65535 (got ${target.port})',
          ));
        }
    }
  }

  static void _validatePlatform(
    PrintTarget target,
    List<PrintJobFieldError> errors,
  ) {
    if (kIsWeb) return;

    if (target.kind == PrintConnectionKind.usb &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      errors.add(const PrintJobFieldError(
        field: 'connection.type',
        message: 'USB printing is not supported on iOS',
      ));
    }
  }

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
