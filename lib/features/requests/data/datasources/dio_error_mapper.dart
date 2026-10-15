import 'package:dio/dio.dart';

import '../../../../core/result.dart';

/// Maps a Dio failure onto the app's exception hierarchy.
///
/// Timeouts and connection errors are transient; HTTP responses carry the
/// status code so the retry policy can tell 4xx (permanent) from 5xx.
AppException mapDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const NetworkException();
    case DioExceptionType.cancel:
      return const NetworkException('Request cancelled.');
    case DioExceptionType.badResponse:
      final int code = error.response?.statusCode ?? 0;
      return ServerException(
        serverMessageFrom(error.response?.data) ?? 'Server error ($code)',
        statusCode: code,
      );
    case DioExceptionType.unknown:
      return const NetworkException();
  }
}

/// Extracts a human message from a few common error-body shapes
/// (`{"error": ...}`, `{"message": ...}`, or a plain string).
String? serverMessageFrom(Object? data) {
  if (data is Map) {
    for (final String key in const <String>['error', 'message', 'detail']) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
  }
  if (data is String && data.trim().isNotEmpty) return data.trim();
  return null;
}
