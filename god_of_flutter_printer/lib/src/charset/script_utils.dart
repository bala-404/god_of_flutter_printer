/// Supported locale/script identifiers for charset encoding.
enum ScriptLocale {
  latin,
  tamil,
  hindi,
  mixed,
}

/// Detects script boundaries inside Unicode text.
class ScriptUtils {
  ScriptUtils._();

  static bool isLatin(int codeUnit) {
    return (codeUnit >= 0x20 && codeUnit <= 0x7E) ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
  }

  static bool isTamil(int codeUnit) {
    return codeUnit >= 0x0B80 && codeUnit <= 0x0BFF;
  }

  static bool isDevanagari(int codeUnit) {
    return codeUnit >= 0x0900 && codeUnit <= 0x097F;
  }

  static bool needsCustomFont(int codeUnit) {
    return isTamil(codeUnit) || isDevanagari(codeUnit);
  }

  static bool hasCustomScript(String text) {
    for (final rune in text.runes) {
      if (needsCustomFont(rune)) return true;
    }
    return false;
  }

  /// Any non-ASCII character must not be sent as UTF-8 to ESC/POS printers.
  static bool needsMultilingualEncoding(String text) {
    for (final rune in text.runes) {
      if (rune > 0x7F) return true;
    }
    return false;
  }

  static ScriptLocale detectLocale(String text) {
    var tamil = false;
    var hindi = false;

    for (final unit in text.runes) {
      if (isTamil(unit)) tamil = true;
      if (isDevanagari(unit)) hindi = true;
    }

    if (tamil && hindi) return ScriptLocale.mixed;
    if (tamil) return ScriptLocale.tamil;
    if (hindi) return ScriptLocale.hindi;
    return ScriptLocale.latin;
  }

  static ScriptLocale localeFromTag(String? locale) {
    if (locale == null) return ScriptLocale.latin;
    final value = locale.toLowerCase();
    if (value.startsWith('ta')) return ScriptLocale.tamil;
    if (value.startsWith('hi') || value.startsWith('in')) {
      return ScriptLocale.hindi;
    }
    return ScriptLocale.latin;
  }

  /// Collects unique code points that require downloaded glyphs.
  static List<int> uniqueCustomCodePoints(String text) {
    final set = <int>{};
    for (final rune in text.runes) {
      if (needsCustomFont(rune)) set.add(rune);
    }
    final list = set.toList()..sort();
    return list;
  }
}

/// A text segment tagged with its script.
class ScriptRun {
  const ScriptRun({
    required this.text,
    required this.locale,
  });

  final String text;
  final ScriptLocale locale;
}

/// Splits text into contiguous script runs.
List<ScriptRun> splitScriptRuns(String text) {
  if (text.isEmpty) return const [];

  ScriptLocale localeForRune(int rune) {
    if (ScriptUtils.isTamil(rune)) return ScriptLocale.tamil;
    if (ScriptUtils.isDevanagari(rune)) return ScriptLocale.hindi;
    return ScriptLocale.latin;
  }

  final runs = <ScriptRun>[];
  final buffer = StringBuffer();
  ScriptLocale? current;

  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final locale = localeForRune(rune);
    if (current != null && current != locale) {
      runs.add(ScriptRun(text: buffer.toString(), locale: current));
      buffer.clear();
    }
    current = locale;
    buffer.write(char);
  }

  if (buffer.isNotEmpty && current != null) {
    runs.add(ScriptRun(text: buffer.toString(), locale: current));
  }
  return runs;
}
