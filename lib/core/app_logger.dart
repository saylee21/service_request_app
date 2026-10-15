import 'dart:developer' as developer;

/// Thin logging wrapper.
///
/// Privacy rule: only ids, counts, status codes and durations are logged.
/// Field values are never logged or stored.
class AppLogger {
  AppLogger._();

  static const String _name = 'service_request_app';

  static void d(String message) =>
      developer.log(message, name: _name, level: 500);

  static void w(String message) =>
      developer.log(message, name: _name, level: 900);

  static void e(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(
        message,
        name: _name,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
}
