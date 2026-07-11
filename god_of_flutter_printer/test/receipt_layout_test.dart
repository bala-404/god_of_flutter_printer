import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';
import 'package:god_of_flutter_printer/src/encoders/receipt_line_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptLineFormatter', () {
    final formatter = ReceiptLineFormatter(48);

    test('leftRight spreads bill metadata across the line', () {
      final line = formatter.leftRight(
        'Bill No: SR56',
        'Date: 05/07/2026 08:30 PM',
      );

      expect(line.length, 48);
      expect(line.startsWith('Bill No: SR56'), isTrue);
      expect(line.trimRight().endsWith('08:30 PM'), isTrue);
    });

    test('leftRight keeps amount aligned when label is long', () {
      final line = formatter.leftRight(
        'Total Inclusive Tax For Special Items',
        '1283.08',
      );

      expect(line.length, 48);
      expect(line.trimRight().endsWith('1283.08'), isTrue);
    });

    test('wrapAligned centers and wraps long header text', () {
      final lines = formatter.wrapAligned(
        'AK Super Market Main Street Branch City Center Area Near Bus Stand',
        48,
        'center',
      );

      expect(lines.length, greaterThan(1));
      for (final line in lines) {
        expect(line.length, 48);
      }
    });

    test('wrapAligned centers each newline-separated address line', () {
      final lines = formatter.wrapAligned(
        'AK Store\nAL1\nA12\nChennai',
        48,
        'center',
      );

      expect(lines.length, 4);
      for (final line in lines) {
        expect(line.length, 48);
        expect(line.trim(), isNotEmpty);
      }
      expect(lines[0].trim(), 'AK Store');
      expect(lines[1].trim(), 'AL1');
      expect(lines[2].trim(), 'A12');
      expect(lines[3].trim(), 'Chennai');
    });

    test('formatRow keeps each item on its own aligned line', () {
      final lines = formatter.formatRow(
        ['Blueberry Ice', '1', '98.67', '98.67'],
        columnCount: 4,
      );

      expect(lines.length, 1);
      expect(lines.first.length, 48);
      expect(lines.first.trimRight().endsWith('98.67'), isTrue);
      expect(lines.first.contains('Blueberry Ice'), isTrue);
    });

    test('formatRow wraps long item names', () {
      final lines = formatter.formatRow(
        ['Walnuts 5% Tax Item Extra Long', '1', '200.00', '210.00'],
        columnCount: 4,
      );

      expect(lines.length, greaterThan(1));
      expect(lines.first.contains('200.00'), isTrue);
    });

    test('formatHeader aligns kot columns', () {
      final header = formatter.formatHeader(
        ['Product', 'Special Note', 'Qty'],
        layout: 'kot',
      );

      expect(header.length, 48);
      expect(header.contains('Product'), isTrue);
      expect(header.contains('Special Note'), isTrue);
      expect(header.trimRight().endsWith('Qty'), isTrue);
    });
    test('formatRow aligns subtotal qty tax and amount columns', () {
      final lines = formatter.formatRow(
        ['Subtotal', '6', '68.00', '900.00'],
        columnCount: 4,
      );

      expect(lines.length, 1);
      expect(lines.first.length, 48);
      expect(lines.first.startsWith('Subtotal'), isTrue);
      expect(lines.first.trimRight().endsWith('900.00'), isTrue);
    });
    test('kot layout right-aligns qty column', () {
      final line = formatter.formatRow(
        ['Veg Biryani', 'Less spicy', '2'],
        columnCount: 3,
        layout: 'kot',
      ).first;

      expect(line.length, 48);
      final widths = formatter.widthsFor(3, layout: 'kot');
      final qtyCol = line.substring(line.length - widths[2]);
      expect(qtyCol, '    2');
    });

    test('wrapped item keeps qty price amount aligned with following rows', () {
      final widths = formatter.widthsFor(4, layout: 'invoice');
      final qtyStart = widths[0];
      final priceStart = qtyStart + widths[1];
      final amountStart = priceStart + widths[2];

      final wrapped = formatter.formatRow(
        ['Malli Puthina Mushroom Dosa Extra Malli', '1', '130.00', '130.00'],
        columnCount: 4,
      );
      expect(wrapped.length, greaterThan(1));

      final following = [
        ['Extra Appalam', '1', '5.00', '5.00'],
        ['Extra Vallai Ella', '1', '5.00', '5.00'],
        ['Extra Rice', '1', '5.00', '5.00'],
      ];

      final firstLineQty = wrapped.first.substring(qtyStart, priceStart);
      final firstLinePrice = wrapped.first.substring(priceStart, amountStart);
      final firstLineAmount = wrapped.first.substring(amountStart);

      for (final item in following) {
        final line = formatter.formatRow(item, columnCount: 4).first;
        expect(line.substring(qtyStart, priceStart), firstLineQty);
        expect(line.substring(priceStart, amountStart), item[2].padLeft(widths[2]));
        expect(line.substring(amountStart), item[3].padLeft(widths[3]));
        expect(line.substring(qtyStart, priceStart), item[1].padLeft(widths[1]));
      }

      expect(firstLineQty, '1'.padLeft(widths[1]));
      expect(firstLinePrice, '130.00'.padLeft(widths[2]));
      expect(firstLineAmount, '130.00'.padLeft(widths[3]));
    });

    test('invoice layout right-aligns qty price and amount columns', () {
      final widths = formatter.widthsFor(4, layout: 'invoice');
      final qtyStart = widths[0];
      final priceStart = qtyStart + widths[1];
      final amountStart = priceStart + widths[2];

      final items = [
        ['Malli Puthina Mushroom Dosa Extra Malli', '1', '130.00', '130.00'],
        ['Extra Appalam', '1', '5.00', '5.00'],
        ['Executive Meals [S]', '1', '270.00', '270.00'],
        ['Tea', '10', '10.00', '100.00'],
      ];

      for (final item in items) {
        final line = formatter.formatRow(item, columnCount: 4, layout: 'invoice').first;
        expect(line.length, 48);
        expect(line.substring(qtyStart, priceStart), item[1].padLeft(widths[1]));
        expect(line.substring(priceStart, amountStart), item[2].padLeft(widths[2]));
        expect(line.substring(amountStart), item[3].padLeft(widths[3]));
        expect(line.trimRight().endsWith(item[3]), isTrue);
      }
    });

    test('invoice header rewrites legacy Amt label to Amount', () {
      final header = formatter.formatHeader(
        ['Product', 'Qty', 'Price', 'Amt'],
        layout: 'invoice',
      );

      expect(header.length, 48);
      expect(header.contains('Amt'), isFalse);
      expect(header.trimRight().endsWith('Amount'), isTrue);
    });

    test('invoice header uses Amount label with right-aligned columns', () {
      final header = formatter.formatHeader(
        ['Product', 'Qty', 'Price', 'Amount'],
        layout: 'invoice',
      );

      expect(header.length, 48);
      expect(header.contains('Amount'), isTrue);
      expect(header.contains('Amt'), isFalse);
      expect(header.trimRight().endsWith('Amount'), isTrue);
    });
  });

  group('Paper width', () {
    test('72mm uses 42 characters per line', () {
      expect(charsPerLineForWidth(72), 42);
      expect(rasterDotsForWidth(72), 512);
    });

    test('scales table alignment for 72mm paper', () {
      final formatter = ReceiptLineFormatter(charsPerLineForWidth(72));
      final line = formatter.formatRow(
        ['Veg Biryani', '1', '120.00', '120.00'],
        columnCount: 4,
        layout: 'invoice',
      ).first;

      expect(line.length, 42);
      expect(line.contains('Veg Biryani'), isTrue);
      expect(line.trimRight().endsWith('120.00'), isTrue);
    });

    test('scales kot layout for 72mm paper', () {
      final formatter = ReceiptLineFormatter(charsPerLineForWidth(72));
      final header = formatter.formatHeader(
        ['Product', 'Special Note', 'Qty'],
        layout: 'kot',
      );

      expect(header.length, 42);
      expect(header.trimRight().endsWith('Qty'), isTrue);
    });
  });

  group('TemplateEngine kitchen_kot_80', () {
    test('renders kitchen copy layout with items table', () async {
      final engine = TemplateEngine(TemplateRepository());
      final doc = await engine.render(
        templateId: 'kitchen_kot_80',
        data: {
          'dateTime': '06/07/26 14:18',
          'orderNo': '234',
          'orderType': 'Pick Up',
          'biller': 'biller2',
          'items': [
            {
              'name': 'Veg Biryani',
              'specialNote': '--',
              'qty': '1',
            },
          ],
        },
      );

      final texts = doc.blocks
          .where((b) => b.type == 'text')
          .map((b) => b.text ?? '')
          .toList();
      final tables = doc.blocks.where((b) => b.type == 'table').toList();

      expect(texts.first, 'Kitchen Order Printer');
      expect(texts.any((t) => t.contains('06/07/26 14:18')), isTrue);
      expect(texts.any((t) => t.contains('KOT - 234')), isTrue);
      expect(texts.any((t) => t.contains('Pick Up')), isTrue);
      expect(texts.any((t) => t.contains('Biller: biller2')), isTrue);
      expect(tables.length, 1);
      expect(tables.first.columns, ['Product', 'Special Note', 'Qty']);
      expect(tables.first.rows?.first, ['Veg Biryani', '--', '1']);
      expect(tables.first.layout, 'kot');
      expect(tables.first.boldHeader, isTrue);
      expect(tables.first.boldFirstColumn, isNot(true));
      expect(doc.blocks.last.type, 'cut');
      expect(doc.blocks.last.lines, 3);
    });
  });

  group('EscPosEncoder table', () {
    test('encodes each table row on a separate line', () async {
      final bytes = await EscPosEncoder(paperWidthMm: 80).encodeDocument(
        PrintDocument(
          blocks: [
            PrintDocumentBlock(
              type: 'table',
              columns: const ['Product', 'Qty', 'Price', 'Amount'],
              rows: const [
                ['Blueberry Ice', '1', '98.67', '98.67'],
                ['Honey Cake', '1', '500.00', '500.00'],
              ],
              layout: 'invoice',
            ),
          ],
        ),
      );

      final text = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
      expect(text.contains('Blueberry Ice'), isTrue);
      expect(text.contains('Honey Cake'), isTrue);
      expect(text.indexOf('Honey Cake'), greaterThan(text.indexOf('Blueberry Ice')));
      expect(text.contains('Blueberry IceHoney Cake'), isFalse);
    });

    test('encodes table rows with compact line spacing', () async {
      final bytes = await EscPosEncoder(paperWidthMm: 80).encodeDocument(
        PrintDocument(
          blocks: [
            PrintDocumentBlock(
              type: 'table',
              columns: const ['Product', 'Qty', 'Price', 'Amount'],
              rows: const [
                ['Tea', '1', '10.00', '10.00'],
              ],
              layout: 'invoice',
            ),
          ],
        ),
      );

      final spacingValues = <int>[];
      for (var i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0x1B && bytes[i + 1] == 0x33) {
          spacingValues.add(bytes[i + 2]);
        }
      }
      expect(spacingValues, contains(EscPosEncoder.tableRowLineSpacing));
      expect(spacingValues.last, EscPosEncoder.defaultLineSpacing);
    });

    test('encodes legacy Amt header as Amount', () async {
      final bytes = await EscPosEncoder(paperWidthMm: 80).encodeDocument(
        PrintDocument(
          blocks: [
            PrintDocumentBlock(
              type: 'table',
              columns: const ['Product', 'Qty', 'Price', 'Amt'],
              rows: const [
                ['Tea', '1', '10.00', '10.00'],
              ],
            ),
          ],
        ),
      );

      final text = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
      expect(text.contains('Amt'), isFalse);
      expect(text.contains('Amount'), isTrue);
    });

    test('encodes kot table with dotted separator after header', () async {
      final bytes = await EscPosEncoder(paperWidthMm: 80).encodeDocument(
        PrintDocument(
          blocks: [
            PrintDocumentBlock(
              type: 'table',
              columns: const ['Product', 'Special Note', 'Qty'],
              rows: const [
                ['Veg Biryani', '--', '1'],
              ],
              columnCount: 3,
              layout: 'kot',
              boldHeader: true,
            ),
          ],
        ),
      );

      final text = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
      expect(text.contains('Product'), isTrue);
      expect(text.contains('................................................'), isTrue);
      expect(text.contains('Veg Biryani'), isTrue);
    });
  });
}
