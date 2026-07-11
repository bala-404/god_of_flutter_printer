/// Supported printer command protocols.
enum PrintProtocol {
  /// Receipt printers (Rugtek RP82, Epson TM, etc.)
  escPos,

  /// TSC and compatible label printers.
  tspl,

  /// Zebra label printers.
  zpl,
}

/// How the caller supplies print content on each job.
enum PrintMode {
  /// Pre-built command bytes — sent as-is (optional init prepended by caller).
  raw,

  /// Structured layout JSON ([PrintDocument]).
  document,

  /// Template id + data JSON merged at runtime.
  template,

  /// Plain text lines encoded for the target protocol.
  text,
}

/// Lifecycle status for a print job tracked in memory.
enum JobStatus {
  queued,
  encoding,
  connecting,
  sending,
  completed,
  failed,
  cancelled,
}

/// Log severity for per-job tracing.
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// Paper widths supported by validation and the example app.
const Set<int> supportedPaperWidthsMm = {58, 72, 80, 100};

/// Paper widths commonly used by thermal printers.
enum PaperWidth {
  mm58(58),
  mm72(72),
  mm80(80),
  mm100(100);

  const PaperWidth(this.mm);
  final int mm;
}

/// Character width hint derived from paper width (Font A, 12x24).
int charsPerLineForWidth(int paperWidthMm) {
  if (paperWidthMm <= 58) return 32;
  if (paperWidthMm <= 72) return 42;
  if (paperWidthMm <= 80) return 48;
  return 64;
}

/// Printable raster width in dots for multilingual / image lines.
int rasterDotsForWidth(int paperWidthMm) {
  if (paperWidthMm <= 58) return 384;
  if (paperWidthMm <= 72) return 512;
  if (paperWidthMm <= 80) return 576;
  return 720;
}
