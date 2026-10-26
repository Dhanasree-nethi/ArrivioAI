import 'package:flutter/foundation.dart';

class MapTilerConfig {
  const MapTilerConfig._();

  /// Supply with `--dart-define=MAPTILER_API_KEY=...`; never commit a key.
  static const apiKey = String.fromEnvironment('MAPTILER_API_KEY');
  static bool get isConfigured => apiKey.isNotEmpty;

  static String get rasterTileUrl =>
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$apiKey';

  /// Prints no secret material and is removed from non-debug builds.
  static void logDebugConfiguration() {
    assert(() {
      debugPrint('MAPTILER_API_KEY configured: $isConfigured');
      debugPrint('MAPTILER_API_KEY length: ${apiKey.length}');
      return true;
    }());
  }
}
