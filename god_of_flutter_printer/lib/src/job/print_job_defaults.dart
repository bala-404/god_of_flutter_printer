import '../models/enums.dart';

/// Package fallbacks for optional technical fields only.
///
/// Printer connection, hub URL, brand, and protocol are always per-job —
/// never stored globally.
class PrintJobDefaults {
  PrintJobDefaults._();

  static const int paperWidthMm = 80;
  static const PrintProtocol protocol = PrintProtocol.escPos;
  static const Duration timeout = Duration(seconds: 15);
  static const int retries = 1;
}
