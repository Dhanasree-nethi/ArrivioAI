class OpenRouteServiceConfig {
  const OpenRouteServiceConfig._();

  /// Supply with `--dart-define=OPENROUTESERVICE_API_KEY=...`; never commit a key.
  static const apiKey = String.fromEnvironment('OPENROUTESERVICE_API_KEY');
  static bool get isConfigured => apiKey.isNotEmpty;
}
