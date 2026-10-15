import 'package:dio/dio.dart';

/// Builds the shared Dio instance.
///
/// Timeouts are deliberately above the mock server's 8s "slow" delay so slow
/// mode surfaces as a slow success rather than a timeout, while still bailing
/// out of genuinely dead connections.
Dio buildDio(String baseUrl) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
}
