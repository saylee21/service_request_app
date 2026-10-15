import 'package:dio/dio.dart';

import '../../../../core/result.dart';
import '../../domain/entities/form_definition.dart';
import '../../../requests/data/datasources/dio_error_mapper.dart';

/// Fetches the current form definition from the server.
class FormRemoteDataSource {
  FormRemoteDataSource(this._dio);

  final Dio _dio;

  static const String path = '/api/forms/request-form';

  Future<FormDefinition> fetch() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(path);
      final Object? data = response.data;
      if (data is! Map) {
        throw const ServerException('Malformed form response.');
      }
      return FormDefinition.fromJson(data.cast<String, dynamic>());
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
