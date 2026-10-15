import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/core/config/app_config.dart';
import 'package:service_request_app/di/injector.dart';
import 'package:service_request_app/features/form/data/repositories/form_repository_impl.dart';
import 'package:service_request_app/features/form/domain/repositories/form_repository.dart';
import 'package:service_request_app/features/requests/data/repositories/request_repository_impl.dart';
import 'package:service_request_app/features/requests/data/repositories/sync_repository_impl.dart';
import 'package:service_request_app/features/requests/domain/repositories/request_repository.dart';
import 'package:service_request_app/features/requests/domain/repositories/sync_repository.dart';
import 'package:service_request_app/features/requests/presentation/cubit/requests_cubit.dart';
import 'package:service_request_app/features/setup/presentation/setup_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  setUp(() async {
    await configureDependencies(
      config: const AppConfig(apiBaseUrl: 'http://localhost:3000'),
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      connectivity: FakeConnectivity(),
      clock: FakeClock(),
      idGenerator: SequentialIdGenerator(),
    );
  });

  tearDown(() => resetDependencies());

  test('the dependency graph resolves end to end', () async {
    expect(getIt<FormRepository>(), isA<FormRepositoryImpl>());
    expect(getIt<RequestRepository>(), isA<RequestRepositoryImpl>());
    expect(getIt<SyncRepository>(), isA<SyncRepositoryImpl>());

    final RequestsCubit cubit = getIt<RequestsCubit>();
    expect(cubit, isA<RequestsCubit>());
    await cubit.close();
  });

  testWidgets('setup screen explains the missing base URL', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetupScreen()));

    expect(find.text('API base URL not configured'), findsOneWidget);
    expect(find.textContaining('10.0.2.2:3000'), findsWidgets);
    expect(find.textContaining('localhost:3000'), findsWidgets);
  });
}
