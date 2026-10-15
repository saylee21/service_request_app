import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/requests/data/datasources/submission_remote_data_source.dart';

import '../helpers/fakes.dart';

void main() {
  late Dio dio;
  late SubmissionRemoteDataSource remote;
  Object? capturedData;
  String? capturedKey;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    remote = SubmissionRemoteDataSource(dio);
    capturedData = null;
    capturedKey = null;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          capturedData = options.data;
          capturedKey = options.headers['Idempotency-Key'] as String?;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 201,
              data: <String, Object?>{'id': 'x'},
            ),
          );
        },
      ),
    );
  });

  test(
    'posts { id, formVersion, data } with the Idempotency-Key header',
    () async {
      final SubmitOutcome outcome = await remote.submit(
        request: makeRequest(id: 'uuid-1', title: 'Leak'),
        idempotencyKey: 'uuid-1',
      );

      expect(outcome.duplicate, isFalse);
      expect(capturedKey, 'uuid-1');

      final Map<String, Object?> body = capturedData as Map<String, Object?>;
      expect(body['id'], 'uuid-1');
      expect(body['formVersion'], 2);
      expect(body['data'], <String, Object?>{'title': 'Leak'});
      expect(body.containsKey('formId'), isFalse);
    },
  );

  test('a 200 response is a duplicate outcome', () async {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, Object?>{'duplicate': true},
            ),
          );
        },
      ),
    );

    final SubmitOutcome outcome = await remote.submit(
      request: makeRequest(id: 'uuid-2'),
      idempotencyKey: 'uuid-2',
    );

    expect(outcome.duplicate, isTrue);
  });
}
