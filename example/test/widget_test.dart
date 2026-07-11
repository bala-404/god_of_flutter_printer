import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('Print demo app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const PrintWorkerExampleApp());
    expect(find.text('Print Worker Demo'), findsOneWidget);
  });
}
