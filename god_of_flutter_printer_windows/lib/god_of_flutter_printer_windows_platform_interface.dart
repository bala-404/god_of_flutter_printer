import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'god_of_flutter_printer_windows_method_channel.dart';

abstract class PrintWorkerWindowsPlatform extends PlatformInterface {
  /// Constructs a PrintWorkerWindowsPlatform.
  PrintWorkerWindowsPlatform() : super(token: _token);

  static final Object _token = Object();

  static PrintWorkerWindowsPlatform _instance = MethodChannelPrintWorkerWindows();

  /// The default instance of [PrintWorkerWindowsPlatform] to use.
  ///
  /// Defaults to [MethodChannelPrintWorkerWindows].
  static PrintWorkerWindowsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PrintWorkerWindowsPlatform] when
  /// they register themselves.
  static set instance(PrintWorkerWindowsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
