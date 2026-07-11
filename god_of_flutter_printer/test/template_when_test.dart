import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplateEngine when', () {
    test('skips optional blocks when data field is missing', () async {
      final engine = TemplateEngine(TemplateRepository());
      final doc = await engine.render(
        templateId: 'kitchen_kot_80',
        data: {
          'orderNo': '2054',
        },
      );

      final texts = doc.blocks
          .where((b) => b.type == 'text')
          .map((b) => b.text ?? '')
          .toList();

      expect(texts.any((t) => t.contains('Kitchen Order Printer')), isTrue);
      expect(texts.any((t) => t.contains('KOT - 2054')), isTrue);
      expect(texts.any((t) => t.contains('Table')), isFalse);
      expect(texts.any((t) => t.contains('Remarks')), isFalse);
    });
  });
}
