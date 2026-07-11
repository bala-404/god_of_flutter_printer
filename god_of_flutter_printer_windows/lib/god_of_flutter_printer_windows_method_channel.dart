import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'god_of_flutter_printer_windows_platform_interface.dart';

/// An implementation of [PrintWorkerWindowsPlatform] that uses method channels.
class MethodChannelPrintWorkerWindows extends PrintWorkerWindowsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('print_worker_windows');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
