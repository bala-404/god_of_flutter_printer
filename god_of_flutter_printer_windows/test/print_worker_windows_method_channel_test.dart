import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer_windows/god_of_flutter_printer_windows_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelPrintWorkerWindows platform = MethodChannelPrintWorkerWindows();
  const MethodChannel channel = MethodChannel('print_worker_windows');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
