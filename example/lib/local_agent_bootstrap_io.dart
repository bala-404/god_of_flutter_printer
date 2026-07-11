import 'dart:io';

import 'package:print_agent/print_agent.dart';

PrintAgentServer? _sharedAgent;

/// Starts the local print agent when the Windows example app launches.
Future<void> ensureLocalPrintAgent() async {
  if (!Platform.isWindows) return;

  _sharedAgent ??= PrintAgentServer();
  if (_sharedAgent!.isRunning) return;

  try {
    await _sharedAgent!.start();
  } on SocketException {
    // Port 9280 already in use — another print_agent instance is running.
  }
}
