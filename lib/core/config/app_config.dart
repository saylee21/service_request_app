/// Application configuration.
///
/// The API base URL is injected at build/run time via `--dart-define`, never
/// hard-coded. There is intentionally **no default**: if it is missing the app
/// shows a clear setup screen instead of silently talking to the wrong server.
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   (Android)
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000  (iOS sim)
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  final String apiBaseUrl;

  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');

  /// False when the app was started without `--dart-define=API_BASE_URL=...`.
  static bool get hasBaseUrl => _baseUrl.isNotEmpty;

  factory AppConfig.fromEnvironment() => const AppConfig(apiBaseUrl: _baseUrl);
}
