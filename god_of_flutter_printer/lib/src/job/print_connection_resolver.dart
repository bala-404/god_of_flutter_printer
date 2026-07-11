import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../models/models.dart';
import 'print_target.dart';

/// Maps per-job [PrintTarget] + platform to internal [PrintConnection].
class PrintConnectionResolver {
  PrintConnectionResolver._();

  static PrintConnection resolve({
    required PrintTarget target,
    required String? hubUrl,
  }) {
    return resolveForPlatform(
      target: target,
      hubUrl: hubUrl,
      isWeb: kIsWeb,
    );
  }

  static PrintConnection resolveForPlatform({
    required PrintTarget target,
    required String? hubUrl,
    required bool isWeb,
  }) {
    if (isWeb) {
      return _resolveWeb(target, hubUrl!.trim());
    }
    return _resolveNative(target);
  }

  static PrintConnection _resolveWeb(PrintTarget target, String hubUrl) {
    return switch (target.kind) {
      PrintConnectionKind.usb => PrintConnection.localAgent(
          baseUrl: hubUrl,
          printerName: target.printerName!,
        ),
      PrintConnectionKind.bluetooth => PrintConnection.bluetoothAgent(
          baseUrl: hubUrl,
          address: target.address!,
        ),
      PrintConnectionKind.network => PrintConnection.networkAgent(
          baseUrl: hubUrl,
          host: target.host!,
          port: target.port,
        ),
    };
  }

  static PrintConnection _resolveNative(PrintTarget target) {
    return switch (target.kind) {
      PrintConnectionKind.usb => PrintConnection.usb(
          deviceId: target.printerName!,
        ),
      PrintConnectionKind.bluetooth =>
        defaultTargetPlatform == TargetPlatform.iOS
            ? PrintConnection.ble(deviceId: target.address!)
            : PrintConnection.bluetooth(
                address: target.address!,
              ),
      PrintConnectionKind.network => PrintConnection.network(
          host: target.host!,
          port: target.port,
        ),
    };
  }
}
