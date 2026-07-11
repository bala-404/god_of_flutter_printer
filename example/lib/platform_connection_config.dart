import 'package:flutter/foundation.dart';

/// Target platform selector for the example app UI.
enum DemoPlatform {
  web,
  ios,
  android,
  windows;

  String get label => switch (this) {
        DemoPlatform.web => 'Web (Chrome)',
        DemoPlatform.ios => 'iOS',
        DemoPlatform.android => 'Android',
        DemoPlatform.windows => 'Windows',
      };
}

/// Connection transport shown in the example app.
enum ConnectionType {
  network,
  usb,
  webAgent,
  bluetooth;

  String get label => switch (this) {
        ConnectionType.network => 'IP / Network (TCP)',
        ConnectionType.usb => 'USB',
        ConnectionType.webAgent => 'Web agent (localhost webhook)',
        ConnectionType.bluetooth => 'Bluetooth',
      };
}

/// Which connections are valid per target platform.
class PlatformConnectionRules {
  PlatformConnectionRules._();

  static DemoPlatform detectRuntimePlatform() {
    if (kIsWeb) return DemoPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => DemoPlatform.ios,
      TargetPlatform.android => DemoPlatform.android,
      TargetPlatform.windows => DemoPlatform.windows,
      _ => DemoPlatform.windows,
    };
  }

  static List<ConnectionType> allowedConnections(DemoPlatform platform) {
    return switch (platform) {
      DemoPlatform.web => [
        ConnectionType.webAgent,
        ConnectionType.network,
        ConnectionType.bluetooth,
      ],
      DemoPlatform.ios => [
        ConnectionType.network,
        ConnectionType.bluetooth,
      ],
      DemoPlatform.android => [
        ConnectionType.network,
        ConnectionType.bluetooth,
        ConnectionType.usb,
      ],
      DemoPlatform.windows => [
        ConnectionType.usb,
        ConnectionType.bluetooth,
        ConnectionType.network,
      ],
    };
  }

  static ConnectionType defaultConnection(DemoPlatform platform) {
    return switch (platform) {
      DemoPlatform.web => ConnectionType.webAgent,
      DemoPlatform.android => ConnectionType.bluetooth,
      DemoPlatform.ios => ConnectionType.bluetooth,
      DemoPlatform.windows => ConnectionType.usb,
    };
  }

  static String platformHint(DemoPlatform platform) {
    return switch (platform) {
      DemoPlatform.web =>
        'Web uses print_agent on this PC for USB and Bluetooth. '
        'Start print_agent, then pick a device below.',
      DemoPlatform.android =>
        'Android supports Bluetooth Classic (SPP) and network. Pair printer in system settings first.',
      DemoPlatform.ios =>
        'iOS supports BLE thermal printers and network (TCP). USB is not available.',
      DemoPlatform.windows =>
        'Windows prints directly via USB, Bluetooth Classic, or network. '
        'No Print Hub required.',
    };
  }
}
