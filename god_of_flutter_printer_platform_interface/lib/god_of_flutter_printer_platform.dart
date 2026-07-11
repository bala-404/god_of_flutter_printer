import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'bluetooth_device_info.dart';

/// Native platform bridge for USB and Bluetooth transports.
abstract class PrintWorkerPlatform {
  static PrintWorkerPlatform _instance = MethodChannelPrintWorkerPlatform();

  static PrintWorkerPlatform get instance => _instance;

  static set instance(PrintWorkerPlatform instance) {
    _instance = instance;
  }

  Future<void> usbConnect({
    required String deviceId,
    int timeoutMs = 10000,
  });

  Future<void> usbWrite(Uint8List data);

  Future<void> usbDisconnect();

  Future<void> bluetoothConnect({
    required String address,
    int timeoutMs = 15000,
  });

  Future<void> bluetoothWrite(Uint8List data);

  Future<void> bluetoothDisconnect();

  Future<void> bleConnect({
    required String deviceId,
    int timeoutMs = 15000,
  });

  Future<void> bleWrite(Uint8List data);

  Future<void> bleDisconnect();

  Future<List<String>> listUsbPrinters();

  Future<List<BluetoothDeviceInfo>> listBluetoothDevices();
}

/// Default [MethodChannel] implementation.
class MethodChannelPrintWorkerPlatform extends PrintWorkerPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.godofflutterprinter/platform');

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    await _channel.invokeMethod<void>(method, args);
  }

  @override
  Future<void> usbConnect({
    required String deviceId,
    int timeoutMs = 10000,
  }) =>
      _invoke('usbConnect', {
        'deviceId': deviceId,
        'timeoutMs': timeoutMs,
      });

  @override
  Future<void> usbWrite(Uint8List data) =>
      _invoke('usbWrite', {'data': data});

  @override
  Future<void> usbDisconnect() => _invoke('usbDisconnect');

  @override
  Future<void> bluetoothConnect({
    required String address,
    int timeoutMs = 15000,
  }) =>
      _invoke('bluetoothConnect', {
        'address': address,
        'timeoutMs': timeoutMs,
      });

  @override
  Future<void> bluetoothWrite(Uint8List data) =>
      _invoke('bluetoothWrite', {'data': data});

  @override
  Future<void> bluetoothDisconnect() =>
      _invoke('bluetoothDisconnect');

  @override
  Future<void> bleConnect({
    required String deviceId,
    int timeoutMs = 15000,
  }) =>
      _invoke('bleConnect', {
        'deviceId': deviceId,
        'timeoutMs': timeoutMs,
      });

  @override
  Future<void> bleWrite(Uint8List data) =>
      _invoke('bleWrite', {'data': data});

  @override
  Future<void> bleDisconnect() => _invoke('bleDisconnect');

  @override
  Future<List<String>> listUsbPrinters() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('listUsbPrinters');
    if (result == null) return const [];
    return result.map((entry) => entry.toString()).toList();
  }

  @override
  Future<List<BluetoothDeviceInfo>> listBluetoothDevices() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('listBluetoothDevices');
    if (result == null) return const [];
    return result.map(_parseBluetoothDevice).toList();
  }

  BluetoothDeviceInfo _parseBluetoothDevice(dynamic entry) {
    if (entry is Map) {
      final map = Map<String, dynamic>.from(entry);
      final typeRaw = map['type']?.toString() ?? 'classic';
      return BluetoothDeviceInfo(
        name: map['name']?.toString() ?? 'Bluetooth device',
        address: map['address']?.toString() ?? '',
        type: typeRaw == 'ble'
            ? BluetoothTransportType.ble
            : BluetoothTransportType.classic,
      );
    }
    return BluetoothDeviceInfo(name: entry.toString(), address: entry.toString());
  }
}
