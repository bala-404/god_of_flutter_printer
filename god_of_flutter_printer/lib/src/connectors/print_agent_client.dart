import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:god_of_flutter_printer_platform_interface/god_of_flutter_printer_platform_interface.dart';

/// Result of probing a local print-agent webhook.
class AgentProbeResult {
  const AgentProbeResult({
    required this.online,
    this.printers = const [],
    this.error,
    this.agentVersion,
    this.baseUrl,
  });

  final bool online;
  final List<String> printers;
  final String? error;
  final String? agentVersion;

  /// Resolved agent URL when [PrintAgentClient.discoverAndProbe] succeeds.
  final String? baseUrl;

  bool get hasPrinters => printers.isNotEmpty;

  String get statusMessage {
    if (!online) {
      return error ??
          'Print agent is not reachable. Start print_agent on the Windows PC '
          'with the USB printer, then refresh.';
    }
    if (!hasPrinters) {
      return 'Agent is online but no USB printers were found in Windows. '
          'Install the Rugtek driver, then refresh — or type the printer name manually.';
    }
    return 'Agent online · ${printers.length} printer(s) found';
  }
}

/// HTTP client for the local print-agent (Chrome/web → USB on same PC).
class PrintAgentClient {
  PrintAgentClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  String get _root =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  /// Candidate local agent URLs (same host as the web page first).
  static List<String> candidateBaseUrls({String? preferred}) {
    final candidates = <String>[];
    void add(String url) {
      final trimmed = url.trim();
      if (trimmed.isEmpty) return;
      final normalized =
          trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
      if (!candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }

    add(preferred ?? '');
    if (kIsWeb) {
      final pageHost = Uri.base.host;
      if (pageHost.isNotEmpty && pageHost != '0.0.0.0') {
        add('http://$pageHost:9280');
      }
    }
    add('http://localhost:9280');
    add('http://127.0.0.1:9280');
    return candidates;
  }

  /// Tries common local agent URLs until one responds.
  static Future<AgentProbeResult> discoverAndProbe({
    String? preferred,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final candidates = candidateBaseUrls(preferred: preferred);
    String? lastError;

    for (final candidate in candidates) {
      final client = PrintAgentClient(baseUrl: candidate);
      try {
        final result = await client._probeHealth(timeout: timeout);
        if (result.online) {
          return AgentProbeResult(
            online: true,
            printers: result.printers,
            agentVersion: result.agentVersion,
            baseUrl: candidate,
          );
        }
        lastError = result.error;
      } catch (error) {
        lastError = error.toString();
      } finally {
        client.close();
      }
    }

    return AgentProbeResult(
      online: false,
      error: lastError ??
          'Print agent is not running on this PC.\n\n'
          'Open a terminal and run:\n'
          '  cd print_agent\n'
          '  flutter run -d windows\n\n'
          'Keep that window open, then tap Refresh in this app.',
    );
  }

  /// Checks agent health and loads the USB printer list.
  Future<AgentProbeResult> probe({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_root.isEmpty) {
      return const AgentProbeResult(
        online: false,
        error: 'Print agent URL is empty.',
      );
    }

    try {
      final result = await _probeHealth(timeout: timeout);
      return AgentProbeResult(
        online: result.online,
        printers: result.printers,
        error: result.error,
        agentVersion: result.agentVersion,
        baseUrl: result.online ? _root : null,
      );
    } on http.ClientException catch (error) {
      return AgentProbeResult(
        online: false,
        error: _friendlyNetworkError(error.message),
      );
    } on FormatException catch (error) {
      return AgentProbeResult(
        online: false,
        error: 'Invalid response from print agent: $error',
      );
    } catch (error) {
      return AgentProbeResult(
        online: false,
        error: error.toString(),
      );
    }
  }

  Future<AgentProbeResult> _probeHealth({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final health = await _client
          .get(Uri.parse('$_root/health'))
          .timeout(timeout);

      if (health.statusCode != 200) {
        return AgentProbeResult(
          online: false,
          error: 'Agent at $_root returned HTTP ${health.statusCode} on /health.',
        );
      }

      String? service;
      try {
        final healthJson = jsonDecode(health.body) as Map<String, dynamic>;
        service = healthJson['service'] as String?;
      } catch (_) {}

      final printersResponse = await _client
          .get(Uri.parse('$_root/printers'))
          .timeout(timeout);

      if (printersResponse.statusCode != 200) {
        return AgentProbeResult(
          online: true,
          agentVersion: service,
          error: 'Agent is online but /printers returned HTTP '
              '${printersResponse.statusCode}.',
        );
      }

      final json = jsonDecode(printersResponse.body) as Map<String, dynamic>;
      final printersRaw = json['printers'];
      final printers = printersRaw is List
          ? printersRaw.map((item) => item.toString()).toList()
          : <String>[];

      return AgentProbeResult(
        online: true,
        printers: printers,
        agentVersion: service,
      );
    } on http.ClientException catch (error) {
      return AgentProbeResult(
        online: false,
        error: _friendlyNetworkError(error.message),
      );
    } on FormatException catch (error) {
      return AgentProbeResult(
        online: false,
        error: 'Invalid response from print agent: $error',
      );
    } catch (error) {
      return AgentProbeResult(
        online: false,
        error: error.toString(),
      );
    }
  }

  String _friendlyNetworkError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection failed') ||
        lower.contains('failed to fetch')) {
      return 'Print agent is not running on this PC.\n\n'
          '1. Open a terminal\n'
          '2. Run: cd print_agent && flutter run -d windows\n'
          '3. Keep that app open, then tap Refresh here';
    }
    if (lower.contains('xmlhttprequest error') ||
        lower.contains('network error')) {
      return 'Browser blocked the request to $_root.\n\n'
          'Start print_agent on this same PC, then tap Refresh. '
          'Use http://localhost:9280 (not https).';
    }
    return 'Cannot reach print agent: $message';
  }

  void close() => _client.close();

  /// Lists paired Bluetooth devices exposed by the local agent.
  Future<List<BluetoothDeviceInfo>> listBluetoothDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_root.isEmpty) {
      throw StateError('Print agent URL is empty.');
    }

    try {
      final health = await _client
          .get(Uri.parse('$_root/health'))
          .timeout(timeout);

      if (health.statusCode != 200) {
        throw StateError(
          'Agent at $_root returned HTTP ${health.statusCode} on /health.',
        );
      }

      final response = await _client
          .get(Uri.parse('$_root/bluetooth'))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw StateError(
          'Agent is online but /bluetooth returned HTTP ${response.statusCode}.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final devicesRaw = json['devices'];
      if (devicesRaw is! List) return const [];

      return devicesRaw.map(_parseBluetoothDevice).toList();
    } on http.ClientException catch (error) {
      throw StateError(_friendlyNetworkError(error.message));
    }
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
