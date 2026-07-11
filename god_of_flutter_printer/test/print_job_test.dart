import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

void main() {
  /// Same DB row used by web counter + Windows back-office POS.
  final dbKitchenPrinter = {
    'type': 'template',
    'templateId': 'kitchen_ticket',
    'data': {'orderId': 'K-100', 'tableNo': 'T3'},
    'text': '',
    'document': {},
    'bytes': '',
    'printer': {
      'connectionType': '',
      'brand': 'Rugtek',
      'printerName': 'Rugtek Printer',
      'ip': '192.168.1.50',
      'port': 9100,
      'address': '',
      'hubUrl': 'http://192.168.1.10:9280',
    },
    'protocol': 'escPos',
    'paperWidthMm': 80,
    'charset': '',
    'options': {
      'timeoutMs': 15000,
      'retries': 1,
      'prependInit': true,
      'allowRasterFallback': true,
    },
  };

  group('PrintJobBody', () {
    test('emptyTemplate has all keys with empty defaults', () {
      final body = PrintJobBody.emptyTemplate().toMap();

      expect(body['text'], '');
      expect(body['document'], {});
      expect(body['printer'], isA<Map>());
      expect((body['printer'] as Map)['printerName'], '');
      expect((body['printer'] as Map)['ip'], '');
    });
  });

  group('PrintJobResolver platform rules', () {
    test('web user with printerName + ip uses USB via hub', () {
      final spec = PrintJobResolver.toSpecForPlatform(
        PrintJobBody.fromMap(dbKitchenPrinter),
        isWeb: true,
      );

      expect(spec.connection.kind, PrintConnectionKind.usb);
      expect(spec.hubUrl, 'http://192.168.1.10:9280');
      expect(spec.connection.printerName, 'Rugtek Printer');

      final wired = PrintConnectionResolver.resolveForPlatform(
        target: spec.connection,
        hubUrl: spec.hubUrl,
        isWeb: true,
      );
      expect(wired, isA<LocalAgentPrintConnection>());
    });

    test('windows user with same JSON uses direct IP', () {
      final spec = PrintJobResolver.toSpecForPlatform(
        PrintJobBody.fromMap(dbKitchenPrinter),
        isWeb: false,
      );

      expect(spec.connection.kind, PrintConnectionKind.network);
      expect(spec.hubUrl, isNull);
      expect(spec.connection.host, '192.168.1.50');

      final request = PrintJobBuilder.toRequest(spec);
      expect(request.connection, isA<NetworkPrintConnection>());
    });

    test('native bluetooth when only address is set', () {
      final spec = PrintJobResolver.toSpecForPlatform(
        PrintJobBody.fromMap({
          'type': 'text',
          'text': 'Hello',
          'printer': {
            'connectionType': '',
            'brand': 'Rugtek',
            'printerName': '',
            'ip': '',
            'port': 9100,
            'address': '60:6e:41:c8:0e:ad',
            'hubUrl': '',
          },
        }),
        isWeb: false,
      );

      expect(spec.connection.kind, PrintConnectionKind.bluetooth);
      final request = PrintJobBuilder.toRequest(spec);
      expect(request.connection, isA<BluetoothPrintConnection>());
    });

    test('explicit connectionType overrides auto-detect', () {
      final spec = PrintJobResolver.toSpecForPlatform(
        PrintJobBody.fromMap({
          ...dbKitchenPrinter,
          'printer': {
            ...(dbKitchenPrinter['printer'] as Map),
            'connectionType': 'network',
          },
        }),
        isWeb: false,
      );

      expect(spec.connection.kind, PrintConnectionKind.network);
      final request = PrintJobBuilder.toRequest(spec);
      expect(request.connection, isA<NetworkPrintConnection>());
    });
  });

  group('PrintJobValidator', () {
    test('template job requires templateId', () {
      final result = PrintJobValidator.validate(
        PrintJobSpec.fromMap({
          ...dbKitchenPrinter,
          'templateId': '',
        }),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.field == 'templateId'), isTrue);
    });

    test('network requires ip on native when only printerName set', () {
      final result = PrintJobValidator.validate(
        PrintJobResolver.toSpecForPlatform(
          PrintJobBody.fromMap({
            'type': 'text',
            'text': 'Hi',
            'printer': {
              'connectionType': '',
              'brand': '',
              'printerName': 'Rugtek Printer',
              'ip': '',
              'port': 9100,
              'address': '',
              'hubUrl': '',
            },
          }),
          isWeb: false,
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('missing all printer fields fails', () {
      final result = PrintJobValidator.validate(
        PrintJobResolver.toSpecForPlatform(
          PrintJobBody.fromMap({
            'type': 'text',
            'text': 'Hi',
            'printer': {
              'connectionType': '',
              'brand': '',
              'printerName': '',
              'ip': '',
              'port': 9100,
              'address': '',
              'hubUrl': '',
            },
          }),
          isWeb: false,
        ),
      );

      expect(result.isValid, isFalse);
    });
  });

  group('PrintWorker.printFromMap', () {
    test('invalid job fails instantly', () async {
      final stopwatch = Stopwatch()..start();
      final result = await PrintWorker.instance.printFromMap({
        ...dbKitchenPrinter,
        'templateId': '',
      });
      stopwatch.stop();

      expect(result.failedInstantly, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
