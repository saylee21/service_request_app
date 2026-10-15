import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';

import '../core/change_bus.dart';
import '../core/clock.dart';
import '../core/config/app_config.dart';
import '../core/id_generator.dart';
import '../features/form/data/datasources/form_local_data_source.dart';
import '../features/form/data/datasources/form_remote_data_source.dart';
import '../features/form/data/repositories/form_repository_impl.dart';
import '../features/form/domain/repositories/form_repository.dart';
import '../features/form/domain/services/form_validator.dart';
import '../features/form/domain/usecases/get_form_definition.dart';
import '../features/form/presentation/cubit/new_request_cubit.dart';
import '../features/requests/data/datasources/api_client.dart';
import '../features/requests/data/datasources/app_database.dart';
import '../features/requests/data/datasources/connectivity_probe.dart';
import '../features/requests/data/datasources/request_local_data_source.dart';
import '../features/requests/data/datasources/submission_remote_data_source.dart';
import '../features/requests/data/repositories/request_repository_impl.dart';
import '../features/requests/data/repositories/sync_repository_impl.dart';
import '../features/requests/domain/repositories/request_repository.dart';
import '../features/requests/domain/repositories/sync_repository.dart';
import '../features/requests/domain/services/request_summary_extractor.dart';
import '../features/requests/domain/services/retry_policy.dart';
import '../features/requests/domain/usecases/save_request.dart';
import '../features/requests/domain/usecases/sync_pending.dart';
import '../features/requests/presentation/cubit/diagnostics_cubit.dart';
import '../features/requests/presentation/cubit/request_detail_cubit.dart';
import '../features/requests/presentation/cubit/requests_cubit.dart';

final GetIt getIt = GetIt.instance;

/// Wires the whole object graph.
///
/// Every collaborator that touches the platform (Dio, database, connectivity,
/// clock, id generator) can be overridden, which is what the tests use.
Future<void> configureDependencies({
  AppConfig? config,
  Dio? dio,
  DatabaseFactory? databaseFactory,
  String? databasePath,
  ConnectivityProbe? connectivity,
  Clock? clock,
  IdGenerator? idGenerator,
  RetryPolicy? retryPolicy,
}) async {
  final AppConfig appConfig = config ?? AppConfig.fromEnvironment();

  getIt.registerSingleton<AppConfig>(appConfig);
  getIt.registerLazySingleton<Clock>(() => clock ?? const SystemClock());
  getIt.registerLazySingleton<IdGenerator>(
    () => idGenerator ?? const UuidGenerator(),
  );
  getIt.registerLazySingleton<ChangeBus>(
    ChangeBus.new,
    dispose: (ChangeBus bus) => bus.dispose(),
  );

  getIt.registerLazySingleton<Dio>(() => dio ?? buildDio(appConfig.apiBaseUrl));
  getIt.registerLazySingleton<ConnectivityProbe>(
    () => connectivity ?? PluginConnectivityProbe(Connectivity()),
  );

  getIt.registerLazySingleton<AppDatabase>(
    () => AppDatabase(factory: databaseFactory, path: databasePath),
    dispose: (AppDatabase db) => db.close(),
  );

  getIt.registerLazySingleton<FormRemoteDataSource>(
    () => FormRemoteDataSource(getIt<Dio>()),
  );
  getIt.registerLazySingleton<FormLocalDataSource>(
    () => FormLocalDataSource(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<RequestLocalDataSource>(
    () => RequestLocalDataSource(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<SubmissionRemoteDataSource>(
    () => SubmissionRemoteDataSource(getIt<Dio>()),
  );

  getIt.registerLazySingleton<FormValidator>(() => const FormValidator());
  getIt.registerLazySingleton<RequestSummaryExtractor>(
    () => const RequestSummaryExtractor(),
  );
  getIt.registerLazySingleton<RetryPolicy>(() => retryPolicy ?? RetryPolicy());

  getIt.registerLazySingleton<FormRepository>(
    () => FormRepositoryImpl(
      remote: getIt<FormRemoteDataSource>(),
      local: getIt<FormLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<SyncRepository>(
    () => SyncRepositoryImpl(
      local: getIt<RequestLocalDataSource>(),
      remote: getIt<SubmissionRemoteDataSource>(),
      retryPolicy: getIt<RetryPolicy>(),
      connectivity: getIt<ConnectivityProbe>(),
      clock: getIt<Clock>(),
      bus: getIt<ChangeBus>(),
    ),
    dispose: (SyncRepository repository) => repository.dispose(),
  );
  getIt.registerLazySingleton<RequestRepository>(
    () => RequestRepositoryImpl(
      local: getIt<RequestLocalDataSource>(),
      validator: getIt<FormValidator>(),
      extractor: getIt<RequestSummaryExtractor>(),
      idGenerator: getIt<IdGenerator>(),
      clock: getIt<Clock>(),
      bus: getIt<ChangeBus>(),
      syncRepository: getIt<SyncRepository>(),
    ),
  );

  getIt.registerLazySingleton<GetFormDefinition>(
    () => GetFormDefinition(getIt<FormRepository>()),
  );
  getIt.registerLazySingleton<SaveRequest>(
    () => SaveRequest(getIt<RequestRepository>()),
  );
  getIt.registerLazySingleton<SyncPending>(
    () => SyncPending(getIt<SyncRepository>()),
  );

  getIt.registerFactory<RequestsCubit>(
    () => RequestsCubit(
      requestRepository: getIt<RequestRepository>(),
      syncRepository: getIt<SyncRepository>(),
      connectivity: getIt<ConnectivityProbe>(),
    ),
  );
  getIt.registerFactory<NewRequestCubit>(
    () => NewRequestCubit(
      getForm: getIt<GetFormDefinition>(),
      saveRequest: getIt<SaveRequest>(),
      validator: getIt<FormValidator>(),
    ),
  );
  getIt.registerFactory<DiagnosticsCubit>(
    () => DiagnosticsCubit(getIt<SyncRepository>()),
  );
  getIt.registerFactoryParam<RequestDetailCubit, String, void>(
    (String requestId, _) => RequestDetailCubit(
      requestRepository: getIt<RequestRepository>(),
      formRepository: getIt<FormRepository>(),
      requestId: requestId,
    ),
  );
}

/// Tears the graph down; used between tests.
Future<void> resetDependencies() => getIt.reset();
