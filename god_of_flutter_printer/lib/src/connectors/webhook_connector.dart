import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'print_agent_client.dart';
import 'print_connector.dart';

/// Sends encoded bytes to a local print-agent webhook (Chrome/web → USB).
class WebhookPrintConnector implements PrintConnector {
  WebhookPrintConnector({
    required this.baseUrl,
    required this.printerName,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String printerName;
  final http.Client _client;
  String? _activeRoot;

  String get _root =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  String get _requestRoot => _activeRoot ?? _root;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) async {
    await _ensureAgentOnline(timeout);
  }

  Future<void> _ensureAgentOnline(Duration timeout) async {
    final probe = await PrintAgentClient.discoverAndProbe(
      preferred: baseUrl,
      timeout: timeout,
    );
    if (!probe.online) {
      throw StateError(probe.error ?? 'Print agent not reachable');
    }
    _activeRoot = probe.baseUrl ?? _root;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_activeRoot == null) {
      await _ensureAgentOnline(const Duration(seconds: 15));
    }

    final response = await _client.post(
      Uri.parse('$_requestRoot/print'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transport': 'usb',
        'printer': printerName,
        'bytes': base64Encode(data),
      }),
    );

    if (response.statusCode != 200) {
      final body = response.body.trim();
      throw StateError(
        'Print agent rejected job (HTTP ${response.statusCode})'
        '${body.isEmpty ? '' : ': $body'}',
      );
    }
  }

  @override
  Future<void> disconnect() async {}

  /// Probes the agent and returns printers plus human-readable status.
  static Future<AgentProbeResult> probe(String baseUrl) {
    return PrintAgentClient.discoverAndProbe(preferred: baseUrl);
  }

  /// Lists USB printers exposed by the local agent.
  static Future<List<String>> listPrinters(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await PrintAgentClient.discoverAndProbe(
      preferred: baseUrl,
      timeout: timeout,
    );
    if (!result.online) {
      throw StateError(result.error ?? 'Print agent not reachable');
    }
    return result.printers;
  }
}

PrintConnector createWebhookConnector(LocalAgentPrintConnection connection) {
  return WebhookPrintConnector(
    baseUrl: connection.baseUrl,
    printerName: connection.printerName,
  );
}

/// Sends encoded bytes to a local print-agent webhook (Chrome/web → Bluetooth).
class BluetoothAgentPrintConnector implements PrintConnector {
  BluetoothAgentPrintConnector({
    required this.baseUrl,
    required this.address,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String address;
  final http.Client _client;
  String? _activeRoot;

  String get _root =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  String get _requestRoot => _activeRoot ?? _root;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) async {
    await _ensureAgentOnline(timeout);
  }

  Future<void> _ensureAgentOnline(Duration timeout) async {
    final probe = await PrintAgentClient.discoverAndProbe(
      preferred: baseUrl,
      timeout: timeout,
    );
    if (!probe.online) {
      throw StateError(probe.error ?? 'Print agent not reachable');
    }
    _activeRoot = probe.baseUrl ?? _root;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_activeRoot == null) {
      await _ensureAgentOnline(const Duration(seconds: 15));
    }

    final response = await _client.post(
      Uri.parse('$_requestRoot/print'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transport': 'bluetooth',
        'address': address,
        'bytes': base64Encode(data),
      }),
    );

    if (response.statusCode != 200) {
      final body = response.body.trim();
      throw StateError(
        'Print agent rejected Bluetooth job (HTTP ${response.statusCode})'
        '${body.isEmpty ? '' : ': $body'}',
      );
    }
  }

  @override
  Future<void> disconnect() async {}
}

PrintConnector createBluetoothAgentConnector(
  BluetoothAgentPrintConnection connection,
) {
  return BluetoothAgentPrintConnector(
    baseUrl: connection.baseUrl,
    address: connection.address,
  );
}

/// Sends encoded bytes to a local print-agent webhook (Chrome/web → TCP/IP).
class NetworkAgentPrintConnector implements PrintConnector {
  NetworkAgentPrintConnector({
    required this.baseUrl,
    required this.host,
    this.port = 9100,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String host;
  final int port;
  final http.Client _client;
  String? _activeRoot;

  String get _root =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  String get _requestRoot => _activeRoot ?? _root;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) async {
    final probe = await PrintAgentClient.discoverAndProbe(
      preferred: baseUrl,
      timeout: timeout,
    );
    if (!probe.online) {
      throw StateError(probe.error ?? 'Print agent not reachable');
    }
    _activeRoot = probe.baseUrl ?? _root;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_activeRoot == null) {
      await connect();
    }

    final response = await _client.post(
      Uri.parse('$_requestRoot/print'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transport': 'network',
        'host': host,
        'port': port,
        'bytes': base64Encode(data),
      }),
    );

    if (response.statusCode != 200) {
      final body = response.body.trim();
      throw StateError(
        'Print agent rejected network job (HTTP ${response.statusCode})'
        '${body.isEmpty ? '' : ': $body'}',
      );
    }
  }

  @override
  Future<void> disconnect() async {}
}

PrintConnector createNetworkAgentConnector(
  NetworkAgentPrintConnection connection,
) {
  return NetworkAgentPrintConnector(
    baseUrl: connection.baseUrl,
    host: connection.host,
    port: connection.port,
  );
}

String connectionLockKeyFor(PrintConnection connection) => connection.summary;
