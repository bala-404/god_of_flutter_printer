import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:god_of_flutter_printer_platform_interface/god_of_flutter_printer_platform_interface.dart';

import '../models/models.dart';
import 'print_connector.dart';

/// TCP/IP connector using Dart [Socket].
class TcpPrintConnector implements PrintConnector {
  TcpPrintConnector({
    required this.host,
    this.port = 9100,
  });

  final String host;
  final int port;

  Socket? _socket;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) async {
    _socket = await Socket.connect(host, port, timeout: timeout);
  }

  @override
  Future<void> write(Uint8List data) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('TCP socket is not connected.');
    }
    socket.add(data);
    await socket.flush();
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}

class UsbPrintConnector implements PrintConnector {
  UsbPrintConnector({required this.deviceId, this.timeoutMs = 10000});

  final String deviceId;
  final int timeoutMs;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) {
    return PrintWorkerPlatform.instance.usbConnect(
      deviceId: deviceId,
      timeoutMs: timeout.inMilliseconds,
    );
  }

  @override
  Future<void> write(Uint8List data) {
    return PrintWorkerPlatform.instance.usbWrite(data);
  }

  @override
  Future<void> disconnect() {
    return PrintWorkerPlatform.instance.usbDisconnect();
  }
}

class BluetoothPrintConnector implements PrintConnector {
  BluetoothPrintConnector({required this.address, this.timeoutMs = 15000});

  final String address;
  final int timeoutMs;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) {
    return PrintWorkerPlatform.instance.bluetoothConnect(
      address: address,
      timeoutMs: timeout.inMilliseconds,
    );
  }

  @override
  Future<void> write(Uint8List data) {
    return PrintWorkerPlatform.instance.bluetoothWrite(data);
  }

  @override
  Future<void> disconnect() {
    return PrintWorkerPlatform.instance.bluetoothDisconnect();
  }
}

class BlePrintConnector implements PrintConnector {
  BlePrintConnector({required this.deviceId, this.timeoutMs = 15000});

  final String deviceId;
  final int timeoutMs;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) {
    return PrintWorkerPlatform.instance.bleConnect(
      deviceId: deviceId,
      timeoutMs: timeout.inMilliseconds,
    );
  }

  @override
  Future<void> write(Uint8List data) {
    return PrintWorkerPlatform.instance.bleWrite(data);
  }

  @override
  Future<void> disconnect() {
    return PrintWorkerPlatform.instance.bleDisconnect();
  }
}

PrintConnector createConnector(PrintConnection connection) {
  return switch (connection) {
    NetworkPrintConnection(:final host, :final port) =>
      TcpPrintConnector(host: host, port: port),
    UsbPrintConnection(:final deviceId) =>
      UsbPrintConnector(deviceId: deviceId),
    LocalAgentPrintConnection() ||
    BluetoothAgentPrintConnection() ||
    NetworkAgentPrintConnection() =>
      throw UnsupportedError(
        'Print Hub / web agent is only supported in the browser. '
        'On Windows, Android, and iOS use PrintConnection.usb, '
        '.bluetooth, or .network directly.',
      ),
    BluetoothPrintConnection(:final address) =>
      BluetoothPrintConnector(address: address),
    BlePrintConnection(:final deviceId) => BlePrintConnector(deviceId: deviceId),
  };
}

String connectionLockKey(PrintConnection connection) => connection.summary;