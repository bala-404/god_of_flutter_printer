import 'package:flutter_test/flutter_test.dart';
import 'package:god_of_flutter_printer_windows/god_of_flutter_printer_windows.dart';
import 'package:god_of_flutter_printer_windows/god_of_flutter_printer_windows_platform_interface.dart';
import 'package:god_of_flutter_printer_windows/god_of_flutter_printer_windows_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPrintWorkerWindowsPlatform
    with MockPlatformInterfaceMixin
    implements PrintWorkerWindowsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PrintWorkerWindowsPlatform initialPlatform = PrintWorkerWindowsPlatform.instance;

  test('$MethodChannelPrintWorkerWindows is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPrintWorkerWindows>());
  });

  test('getPlatformVersion', () async {
    PrintWorkerWindows printWorkerWindowsPlugin = PrintWorkerWindows();
    MockPrintWorkerWindowsPlatform fakePlatform = MockPrintWorkerWindowsPlatform();
    PrintWorkerWindowsPlatform.instance = fakePlatform;

    expect(await printWorkerWindowsPlugin.getPlatformVersion(), '42');
  });
}
