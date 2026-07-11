import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resolves asset paths for resources bundled inside the `god_of_flutter_printer` package.
class PackageAssets {
  PackageAssets._();

  static const packageName = 'god_of_flutter_printer';

  /// Asset paths to try: app bundle first, then package bundle, then local tests.
  static List<String> resolve(String relativePath) {
    return [
      relativePath,
      'packages/$packageName/$relativePath',
    ];
  }

  static Future<String> loadString(
    String relativePath, {
    AssetBundle? bundle,
  }) async {
    final loader = bundle ?? rootBundle;
    Object? lastError;

    for (final path in resolve(relativePath)) {
      try {
        return await loader.loadString(path);
      } catch (error) {
        lastError = error;
      }
    }

    throw FlutterError(
      'Unable to load package asset "$relativePath". '
      'Tried: ${resolve(relativePath).join(', ')}. '
      'Last error: $lastError',
    );
  }

  static Future<ByteData> loadBytes(
    String relativePath, {
    AssetBundle? bundle,
  }) async {
    final loader = bundle ?? rootBundle;
    Object? lastError;

    for (final path in resolve(relativePath)) {
      try {
        return await loader.load(path);
      } catch (error) {
        lastError = error;
      }
    }

    throw FlutterError(
      'Unable to load package asset "$relativePath". '
      'Tried: ${resolve(relativePath).join(', ')}. '
      'Last error: $lastError',
    );
  }
}
