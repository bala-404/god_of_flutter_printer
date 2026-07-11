import 'dart:io';

/// Discovers the first non-loopback IPv4 address for LAN print-hub URLs.
Future<String?> discoverLanIPv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        final ip = address.address;
        if (ip.startsWith('169.254.')) continue;
        return ip;
      }
    }
  } catch (_) {}

  return null;
}

/// Hub URLs exposed to web clients on this PC and shop LAN.
class PrintHubUrls {
  const PrintHubUrls({
    required this.localUrl,
    this.lanUrl,
    required this.port,
  });

  final String localUrl;
  final String? lanUrl;
  final int port;

  static Future<PrintHubUrls> forPort(int port) async {
    final lanIp = await discoverLanIPv4();
    return PrintHubUrls(
      localUrl: 'http://localhost:$port',
      lanUrl: lanIp == null ? null : 'http://$lanIp:$port',
      port: port,
    );
  }

  /// URL tablets on the same Wi‑Fi should use in the hosted web app.
  String get recommendedWebUrl => lanUrl ?? localUrl;

  List<String> get allUrls => [
        localUrl,
        if (lanUrl != null) lanUrl!,
      ];
}
