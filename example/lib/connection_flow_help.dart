import 'package:flutter/foundation.dart';

import 'platform_connection_config.dart';

/// Short test instructions per platform + connection.
class ConnectionFlowHelp {
  ConnectionFlowHelp._();

  static String runtimeLabel() {
    if (kIsWeb) return 'Web (Chrome)';
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'Windows',
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      _ => defaultTargetPlatform.name,
    };
  }

  static String connectionHint({
    required DemoPlatform runtime,
    required ConnectionType connection,
  }) {
    if (runtime == DemoPlatform.web) {
      return switch (connection) {
        ConnectionType.webAgent =>
          'Web → Print Hub → USB printer. Start print_agent, paste hub LAN URL, refresh.',
        ConnectionType.bluetooth =>
          'Web → Print Hub → Bluetooth. Pair printer in Windows, paste hub URL, refresh.',
        ConnectionType.network =>
          'Web → Print Hub → TCP 9100. Printer must be on same LAN as hub PC.',
        ConnectionType.usb => 'USB direct is Windows/Android native only.',
      };
    }

    return switch (connection) {
      ConnectionType.usb =>
        'Windows direct USB. Install driver, refresh printer list.',
      ConnectionType.bluetooth =>
        'Windows direct Bluetooth SPP. Pair in Settings, refresh.',
      ConnectionType.network =>
        'Direct TCP to printer IP (port 9100). No hub required.',
      ConnectionType.webAgent => '',
    };
  }

  /// Print Hub is required only when the app runs in the browser.
  static bool needsPrintHub({
    required DemoPlatform runtime,
    required ConnectionType connection,
  }) {
    if (!kIsWeb) return false;
    return connection == ConnectionType.webAgent ||
        connection == ConnectionType.bluetooth ||
        connection == ConnectionType.network;
  }
}
