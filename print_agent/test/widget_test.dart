import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent_server.dart';

void main() {
  test('agent base URL uses host and port', () {
    final server = PrintAgentServer(port: 9280);
    expect(server.baseUrl, 'http://127.0.0.1:9280');
  });
}
