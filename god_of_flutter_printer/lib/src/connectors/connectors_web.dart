import '../models/models.dart';
import 'print_connector.dart';
import 'webhook_connector.dart';

PrintConnector createConnector(PrintConnection connection) {
  return switch (connection) {
    LocalAgentPrintConnection() => createWebhookConnector(connection),
    BluetoothAgentPrintConnection() => createBluetoothAgentConnector(connection),
    NetworkAgentPrintConnection() => createNetworkAgentConnector(connection),
    NetworkPrintConnection() => throw UnsupportedError(
        'Raw TCP from the browser is not supported. Use Web agent for USB or '
        'a network print proxy.',
      ),
    BluetoothPrintConnection() => throw UnsupportedError(
        'Direct Bluetooth from the browser is not supported. Start print_agent '
        'on the Windows PC, pair the printer, then use '
        'PrintConnection.bluetoothAgent(baseUrl, address).',
      ),
    UsbPrintConnection() ||
    BlePrintConnection() =>
      throw UnsupportedError(
        'On web, use PrintConnection.localAgent(baseUrl, printerName) '
        'with print_agent running on the PC that has the USB printer.',
      ),
  };
}

String connectionLockKey(PrintConnection connection) =>
    connectionLockKeyFor(connection);
