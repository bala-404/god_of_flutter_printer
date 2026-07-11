import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplateRepository', () {
    test('loads kitchen template from package assets', () async {
      final repository = TemplateRepository();
      final template = await repository.load('kitchen_kot_80');

      expect(template.id, 'kitchen_kot_80');
      expect(template.paperWidthMm, 80);
      expect(template.blocks, isNotEmpty);
    });

    test('loads invoice template from package assets', () async {
      final repository = TemplateRepository();
      final template = await repository.load('invoice_80');

      expect(template.id, 'invoice_80');
      expect(template.blocks, isNotEmpty);
      final itemsTable = template.blocks.firstWhere(
        (b) => b.type == 'table' && b.itemsField == 'items',
      );
      expect(itemsTable.columns, contains('Amount'));
      expect(itemsTable.columns, isNot(contains('Amt')));
      expect(itemsTable.layout, 'invoice');
    });
    test('loads tamil check template from package assets', () async {
      final repository = TemplateRepository();
      final template = await repository.load('tamil_check_80');

      expect(template.id, 'tamil_check_80');
      expect(template.blocks.any((b) => b.locale == 'ta'), isTrue);
    });

    test('loads day close template from package assets', () async {
      final repository = TemplateRepository();
      final template = await repository.load('day_close_80');

      expect(template.id, 'day_close_80');
      expect(template.paperWidthMm, 80);
      expect(template.blocks, isNotEmpty);
    });
  });
}
