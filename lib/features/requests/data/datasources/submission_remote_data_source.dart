import 'package:dio/dio.dart';

import '../../../../core/result.dart';
import '../../domain/entities/service_request.dart';
import 'dio_error_mapper.dart';

/// Outcome of an accepted submission.
class SubmitOutcome {
  const SubmitOutcome({required this.duplicate, this.message});

  /// True when the server reported the request was already stored
  /// (HTTP 200 with the same Idempotency-Key) rather than newly created.
  final bool duplicate;

  final String? message;
}

/// Posts a saved request. The Idempotency-Key makes retries safe: a repeat
/// attempt returns 200 instead of creating a second record.
class SubmissionRemoteDataSource {
  SubmissionRemoteDataSource(this._dio);

  final Dio _dio;

  static const String path = '/api/submissions';

  Future<SubmitOutcome> submit({
    required ServiceRequest request,
    required String idempotencyKey,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        path,
        data: <String, Object?>{
          'formId': request.formId,
          'formVersion': request.formVersion,
          'data': request.data,
        },
        options: Options(
          headers: <String, String>{'Idempotency-Key': idempotencyKey},
        ),
      );
      final int code = response.statusCode ?? 0;
      final String? message = serverMessageFrom(response.data);
      if (code == 200) return SubmitOutcome(duplicate: true, message: message);
      if (code == 201) return SubmitOutcome(duplicate: false, message: message);
      throw ServerException(
        message ?? 'Unexpected response ($code)',
        statusCode: code,
      );
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
