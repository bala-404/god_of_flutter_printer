import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:god_of_flutter_printer_platform_interface/god_of_flutter_printer_platform_interface.dart';

import 'network_utils.dart';

/// HTTP webhook server: Chrome/web → this PC's USB printer.
class PrintAgentServer {
  PrintAgentServer({
    InternetAddress? host,
    this.port = 9280,
    PrintWorkerPlatform? platform,
    bool listenOnLan = true,
  })  : host = host ??
            (listenOnLan ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4),
        _platform = platform ?? PrintWorkerPlatform.instance;

  final InternetAddress host;
  final int port;
  final PrintWorkerPlatform _platform;

  HttpServer? _server;
  final _logController = StreamController<String>.broadcast();
  PrintHubUrls? _hubUrls;

  Stream<String> get logs => _logController.stream;
  bool get isRunning => _server != null;

  /// Primary bind address (often 0.0.0.0 when [listenOnLan] is true).
  String get baseUrl => 'http://${host.address}:$port';

  PrintHubUrls? get hubUrls => _hubUrls;

  String get localHubUrl => _hubUrls?.localUrl ?? 'http://localhost:$port';

  String? get lanHubUrl => _hubUrls?.lanUrl;

  String get recommendedWebUrl =>
      _hubUrls?.recommendedWebUrl ?? localHubUrl;

  Future<void> start() async {
    if (_server != null) return;
    _hubUrls = await PrintHubUrls.forPort(port);
    _server = await HttpServer.bind(host, port, shared: true);
    _log('Listening on port $port (all interfaces)');
    _log('This PC (Chrome): ${_hubUrls!.localUrl}');
    if (_hubUrls!.lanUrl != null) {
      _log('Shop LAN (tablets): ${_hubUrls!.lanUrl}');
    }
    _log('Endpoints: GET /health  GET /printers  GET /bluetooth  GET /download/hub  POST /print');
    _server!.listen(_handleRequest, onError: (Object error) {
      _log('Server error: $error');
    });

    try {
      final printers = await _platform.listUsbPrinters();
      if (printers.isEmpty) {
        _log('Warning: no USB printers found in Windows spooler');
      } else {
        _log('USB printers: ${printers.join(', ')}');
      }
    } catch (error) {
      _log('Failed to enumerate USB printers: $error');
    }

    try {
      final devices = await _platform.listBluetoothDevices();
      if (devices.isEmpty) {
        _log('Warning: no paired Bluetooth devices found');
      } else {
        _log(
          'Bluetooth devices: '
          '${devices.map((d) => '${d.name} (${d.address})').join(', ')}',
        );
      }
    } catch (error) {
      _log('Failed to enumerate Bluetooth devices: $error');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _log('Stopped');
  }

  Future<List<String>> listLocalPrinters() {
    return _platform.listUsbPrinters();
  }

  Future<List<Map<String, String>>> listBluetoothDevices() async {
    final devices = await _platform.listBluetoothDevices();
    return devices
        .map(
          (device) => {
            'name': device.name,
            'address': device.address,
          },
        )
        .toList();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _addCors(request);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = _normalizePath(request.uri.path);

    if (path == '/download/hub' &&
        (request.method == 'GET' || request.method == 'HEAD')) {
      await _serveHubPackage(request, headOnly: request.method == 'HEAD');
      return;
    }

    _log('${request.method} $path from ${request.connectionInfo?.remoteAddress}');

    try {
      switch ('${request.method} $path') {
        case 'GET /health':
          await _writeJson(request.response, {
            'ok': true,
            'service': 'print_agent',
            'platform': Platform.operatingSystem,
            'port': port,
            'localUrl': localHubUrl,
            if (lanHubUrl != null) 'lanUrl': lanHubUrl,
            'webUrl': recommendedWebUrl,
            'hubPackage': _locateHubPackage()?.existsSync() ?? false,
          });
        case 'GET /printers':
          final printers = await _platform.listUsbPrinters();
          await _writeJson(request.response, {'printers': printers});
        case 'GET /bluetooth':
          final devices = await _platform.listBluetoothDevices();
          await _writeJson(request.response, {
            'devices': devices
                .map(
                  (device) => {
                    'name': device.name,
                    'address': device.address,
                    'type': device.type.name,
                  },
                )
                .toList(),
          });
        case 'POST /print':
          await _handlePrint(request);
        default:
          request.response.statusCode = HttpStatus.notFound;
          await _writeJson(request.response, {'error': 'Not found'});
      }
    } catch (error) {
      _log('Request failed: $error');
      request.response.statusCode = HttpStatus.internalServerError;
      await _writeJson(request.response, {'error': error.toString()});
    }
  }

  String _normalizePath(String path) {
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path.isEmpty ? '/' : path;
  }

  Future<void> _handlePrint(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final transport = (json['transport'] as String? ?? 'usb').toLowerCase();
    final printer = json['printer'] as String?;
    final address = json['address'] as String?;
    final bytesField = json['bytes'];

    late final Uint8List bytes;
    if (bytesField is String) {
      bytes = base64Decode(bytesField);
    } else if (bytesField is List) {
      bytes = Uint8List.fromList(bytesField.cast<int>());
    } else {
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {'error': 'Missing "bytes" (base64 string)'});
      return;
    }

    if (bytes.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {'error': 'Empty print payload'});
      return;
    }

    if (transport == 'network') {
      final host = json['host'] as String?;
      final port = json['port'] is int
          ? json['port'] as int
          : int.tryParse(json['port']?.toString() ?? '') ?? 9100;

      if (host == null || host.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        await _writeJson(request.response, {
          'error': 'Missing "host" for network print',
        });
        return;
      }

      _log('Network print job → $host:$port (${bytes.length} bytes)');
      final socket = await Socket.connect(host, port);
      try {
        socket.add(bytes);
        await socket.flush();
        await _writeJson(request.response, {
          'ok': true,
          'transport': 'network',
          'host': host,
          'port': port,
          'bytesSent': bytes.length,
        });
        _log('Printed ${bytes.length} bytes over TCP');
      } finally {
        await socket.close();
      }
      return;
    }

    final useBluetooth = transport == 'bluetooth' ||
        (address != null &&
            address.isNotEmpty &&
            (printer == null || printer.isEmpty));

    if (useBluetooth) {
      if (address == null || address.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        await _writeJson(request.response, {
          'error': 'Missing "address" for Bluetooth print',
        });
        return;
      }

      _log('Bluetooth print job → $address (${bytes.length} bytes)');
      try {
        await _platform.bluetoothConnect(address: address);
        try {
          await _platform.bluetoothWrite(bytes);
          await _writeJson(request.response, {
            'ok': true,
            'transport': 'bluetooth',
            'address': address,
            'bytesSent': bytes.length,
          });
          _log('Printed ${bytes.length} bytes over Bluetooth');
        } finally {
          await _platform.bluetoothDisconnect();
        }
      } catch (error) {
        request.response.statusCode = HttpStatus.internalServerError;
        await _writeJson(request.response, {'error': error.toString()});
        _log('Bluetooth print failed: $error');
      }
      return;
    }

    if (printer == null || printer.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {'error': 'Missing "printer" field'});
      return;
    }

    _log('Print job → "$printer" (${bytes.length} bytes)');
    try {
      await _platform.usbConnect(deviceId: printer);
      try {
        await _platform.usbWrite(bytes);
        await _writeJson(request.response, {
          'ok': true,
          'transport': 'usb',
          'printer': printer,
          'bytesSent': bytes.length,
        });
        _log('Printed ${bytes.length} bytes');
      } finally {
        await _platform.usbDisconnect();
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      await _writeJson(request.response, {'error': error.toString()});
      _log('USB print failed: $error');
    }
  }

  Future<void> _serveHubPackage(
    HttpRequest request, {
    bool headOnly = false,
  }) async {
    final zipFile = _locateHubPackage();
    if (zipFile == null || !await zipFile.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await _writeJson(request.response, {
        'error':
            'Print Hub package not built. On a Windows dev PC run: '
            'print_agent/scripts/package_release.ps1',
      });
      return;
    }

    final length = await zipFile.length();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers
      ..add('Content-Type', 'application/zip')
      ..add(
        'Content-Disposition',
        'attachment; filename="PrintWorkerHub-win64.zip"',
      )
      ..add('Content-Length', '$length');

    if (!headOnly) {
      await request.response.addStream(zipFile.openRead());
    }
    await request.response.close();
  }

  File? _locateHubPackage() {
    const relativeCandidates = [
      'dist/PrintWorkerHub-win64.zip',
      'dist/print_worker_hub.zip',
    ];

    for (final relative in relativeCandidates) {
      final file = File(relative);
      if (file.existsSync()) return file;
    }

    final exeDir = File(Platform.resolvedExecutable).parent;
    final nextToExe = File(
      '${exeDir.path}${Platform.pathSeparator}PrintWorkerHub-win64.zip',
    );
    if (nextToExe.existsSync()) return nextToExe;

    return null;
  }

  void _addCors(HttpRequest request) {
    final response = request.response;
    response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..add('Access-Control-Allow-Headers',
          'Content-Type, Access-Control-Request-Private-Network')
      ..add('Access-Control-Allow-Private-Network', 'true');

    if (request.method != 'OPTIONS') {
      response.headers.add('Content-Type', 'application/json; charset=utf-8');
    }
  }

  Future<void> _writeJson(HttpResponse response, Map<String, dynamic> data) async {
    response.write(jsonEncode(data));
    await response.close();
  }

  void _log(String message) {
    final line = '${DateTime.now().toIso8601String()}  $message';
    _logController.add(line);
  }
}
