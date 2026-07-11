import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

void main() {
  group('WebhookPrintConnector', () {
    test('localAgent connection uses webhook summary', () {
      const connection = PrintConnection.localAgent(
        baseUrl: 'http://127.0.0.1:9280',
        printerName: 'Rugtek RP82',
      );
      expect(connection.summary, contains('agent:'));
      expect(connection.summary, contains('9280'));
    });

    test('bluetoothAgent connection uses bluetooth agent summary', () {
      const connection = PrintConnection.bluetoothAgent(
        baseUrl: 'http://127.0.0.1:9280',
        address: 'aa:bb:cc:dd:ee:ff',
      );
      expect(connection.summary, contains('bt-agent:'));
      expect(connection.summary, contains('9280'));
    });

    test('networkAgent connection uses network agent summary', () {
      const connection = PrintConnection.networkAgent(
        baseUrl: 'http://127.0.0.1:9280',
        host: '192.168.1.100',
        port: 9100,
      );
      expect(connection.summary, contains('net-agent:'));
      expect(connection.summary, contains('192.168.1.100'));
    });
  });
}
