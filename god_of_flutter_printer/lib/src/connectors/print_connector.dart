import 'dart:typed_data';

/// Transport abstraction used by the worker for a single job.
abstract class PrintConnector {
  Future<void> connect({Duration timeout = const Duration(seconds: 15)});
  Future<void> write(Uint8List data);
  Future<void> disconnect();
}
