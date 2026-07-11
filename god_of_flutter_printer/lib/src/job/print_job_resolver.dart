import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/enums.dart';
import 'print_job_body.dart';
import 'print_job_spec.dart';
import 'print_target.dart';

/// Turns [PrintJobBody] (DB JSON) into [PrintJobSpec] for the current platform.
///
/// Same JSON for all POS users:
/// - **Web** → Print Hub ([PrinterJobConfig.hubUrl]) + USB name when set, else IP/BT via hub
/// - **Windows / Android / iOS** → direct TCP when [PrinterJobConfig.ip] is set, else USB/BT
class PrintJobResolver {
  PrintJobResolver._();

  static PrintJobSpec toSpec(PrintJobBody body) {
    return toSpecForPlatform(body, isWeb: kIsWeb);
  }

  /// Visible for tests — [isWeb] selects web vs native resolution rules.
  static PrintJobSpec toSpecForPlatform(
    PrintJobBody body, {
    required bool isWeb,
  }) {
    final mode = parsePrintMode(body.type);
    final connection = resolveTarget(body.printer, isWeb: isWeb);

    return PrintJobSpec(
      mode: mode,
      payload: _payloadForMode(body, mode),
      connection: connection,
      hubUrl: isWeb ? _resolveHubUrl(body.printer) : null,
      protocol: parsePrintProtocol(body.protocol),
      paperWidthMm: body.paperWidthMm,
      timeout: Duration(milliseconds: body.options.timeoutMs),
      retries: body.options.retries,
      prependInit: body.options.prependInit,
      allowRasterFallback: body.options.allowRasterFallback,
      charset: body.charset.isEmpty ? null : body.charset,
      jobId: body.jobId.isEmpty ? null : body.jobId,
    );
  }

  static Map<String, dynamic> _payloadForMode(PrintJobBody body, PrintMode mode) {
    return switch (mode) {
      PrintMode.template => {
          'templateId': body.templateId,
          'data': body.data,
        },
      PrintMode.text => {
          'text': body.text,
          if (body.charset.isNotEmpty) 'charset': body.charset,
        },
      PrintMode.document => {
          'document': body.document,
        },
      PrintMode.raw => {
          'bytes': body.bytes.isEmpty ? null : body.bytes,
        },
    };
  }

  static String? _resolveHubUrl(PrinterJobConfig printer) {
    final hub = printer.hubUrl.trim();
    return hub.isEmpty ? null : hub;
  }

  /// Picks connection method from filled printer fields + platform.
  static PrintTarget resolveTarget(
    PrinterJobConfig printer, {
    required bool isWeb,
  }) {
    final explicit = printer.connectionType.toLowerCase();
    if (explicit.isNotEmpty) {
      return _targetFromExplicit(printer, explicit);
    }

    if (isWeb) {
      return _resolveWebTarget(printer);
    }
    return _resolveNativeTarget(printer);
  }

  /// Web counter: USB name via hub when set; otherwise IP or Bluetooth via hub.
  static PrintTarget _resolveWebTarget(PrinterJobConfig printer) {
    if (printer.hasPrinterName) {
      return PrintTarget.usb(
        printerName: printer.printerName,
        brand: _brandOrNull(printer),
      );
    }
    if (printer.hasIp) {
      return PrintTarget.network(
        host: printer.ip,
        port: printer.port,
        brand: _brandOrNull(printer),
      );
    }
    if (printer.hasBluetooth) {
      return PrintTarget.bluetooth(
        address: printer.address,
        brand: _brandOrNull(printer),
      );
    }
    return const PrintTarget.usb(printerName: '');
  }

  /// Native POS: IP direct when set; otherwise Bluetooth or USB spooler name.
  static PrintTarget _resolveNativeTarget(PrinterJobConfig printer) {
    if (printer.hasIp) {
      return PrintTarget.network(
        host: printer.ip,
        port: printer.port,
        brand: _brandOrNull(printer),
      );
    }
    if (printer.hasBluetooth) {
      return PrintTarget.bluetooth(
        address: printer.address,
        brand: _brandOrNull(printer),
      );
    }
    if (printer.hasPrinterName) {
      return PrintTarget.usb(
        printerName: printer.printerName,
        brand: _brandOrNull(printer),
      );
    }
    return const PrintTarget.usb(printerName: '');
  }

  static PrintTarget _targetFromExplicit(
    PrinterJobConfig printer,
    String type,
  ) {
    return switch (type) {
      'usb' => PrintTarget.usb(
          printerName: printer.printerName,
          brand: _brandOrNull(printer),
        ),
      'bluetooth' || 'bt' => PrintTarget.bluetooth(
          address: printer.address,
          brand: _brandOrNull(printer),
        ),
      'network' || 'ip' || 'tcp' => PrintTarget.network(
          host: printer.hasIp ? printer.ip : printer.printerName,
          port: printer.port,
          brand: _brandOrNull(printer),
        ),
      _ => const PrintTarget.usb(printerName: ''),
    };
  }

  static String? _brandOrNull(PrinterJobConfig printer) {
    return printer.brand.isEmpty ? null : printer.brand;
  }
}
