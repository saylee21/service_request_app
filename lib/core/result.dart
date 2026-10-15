/// Lightweight result type plus the application exception hierarchy.
///
/// Pure Dart: no Flutter imports, so the domain and data layers can depend on
/// it freely.
library;

sealed class Result<T> {
  const Result();

  /// Exhaustively handles both branches without importing pattern-matching
  /// syntax at call sites.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(Object error) onErr,
  }) => switch (this) {
    Ok<T>(:final T value) => onOk(value),
    Err<T>(:final Object error) => onErr(error),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}

/// Base class for expected, domain-level failures.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The device is offline or the connection failed.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network unavailable.']);
}

/// The server returned an error response.
class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});

  final int? statusCode;

  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;
}

/// Input failed a validation rule.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// A local read/write failed.
class CacheException extends AppException {
  const CacheException(super.message);
}
