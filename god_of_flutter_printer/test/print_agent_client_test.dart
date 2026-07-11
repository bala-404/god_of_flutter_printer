import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

void main() {
  group('PrintAgentClient', () {
    test('statusMessage explains offline state', () {
      const result = AgentProbeResult(
        online: false,
        error: 'Connection refused',
      );
      expect(result.statusMessage, contains('Connection refused'));
    });

    test('statusMessage explains empty printer list', () {
      const result = AgentProbeResult(online: true, printers: []);
      expect(result.statusMessage, contains('no USB printers'));
    });
  });

  group('LocalAgentPrintConnection', () {
    test('summary includes agent URL and printer', () {
      const connection = PrintConnection.localAgent(
        baseUrl: 'http://127.0.0.1:9280',
        printerName: 'Rugtek RP82',
      );
      expect(connection.summary, 'agent:Rugtek RP82@http://127.0.0.1:9280');
    });
  });

  group('BluetoothAgentPrintConnection', () {
    test('summary includes agent URL and bluetooth address', () {
      const connection = PrintConnection.bluetoothAgent(
        baseUrl: 'http://127.0.0.1:9280',
        address: 'aa:bb:cc:dd:ee:ff',
      );
      expect(
        connection.summary,
        'bt-agent:aa:bb:cc:dd:ee:ff@http://127.0.0.1:9280',
      );
    });
  });
}
