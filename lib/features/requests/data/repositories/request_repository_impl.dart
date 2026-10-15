import 'dart:async';

import '../../../../core/change_bus.dart';
import '../../../../core/clock.dart';
import '../../../../core/id_generator.dart';
import '../../../../core/result.dart';
import '../../../form/domain/entities/form_definition.dart';
import '../../../form/domain/services/form_validator.dart';
import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_attempt.dart';
import '../../domain/repositories/request_repository.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/services/request_summary_extractor.dart';
import '../datasources/request_local_data_source.dart';

/// Request use cases for the UI. Persists offline-first, then nudges the sync
/// engine (fire-and-forget) so the UI never waits on the network.
class RequestRepositoryImpl implements RequestRepository {
  RequestRepositoryImpl({
    required RequestLocalDataSource local,
    required FormValidator validator,
    required RequestSummaryExtractor extractor,
    required IdGenerator idGenerator,
    required Clock clock,
    required ChangeBus bus,
    required SyncRepository syncRepository,
  }) : _local = local,
       _validator = validator,
       _extractor = extractor,
       _ids = idGenerator,
       _clock = clock,
       _bus = bus,
       _sync = syncRepository;

  final RequestLocalDataSource _local;
  final FormValidator _validator;
  final RequestSummaryExtractor _extractor;
  final IdGenerator _ids;
  final Clock _clock;
  final ChangeBus _bus;
  final SyncRepository _sync;

  @override
  Stream<void> get changes => _bus.stream;

  @override
  Future<Result<ServiceRequest>> save({
    required FormDefinition form,
    required Map<String, Object?> values,
  }) async {
    final Map<String, String> errors = _validator.validate(form, values);
    if (errors.isNotEmpty) {
      return Err(ValidationException(errors.values.first));
    }

    final Map<String, Object?> clean = _validator.stripHidden(form, values);
    final DateTime now = _clock.now();
    final ServiceRequest request = ServiceRequest(
      id: _ids.newId(),
      formId: form.id,
      formVersion: form.version,
      title: _extractor.titleFor(clean),
      priority: _extractor.priorityFor(clean),
      data: clean,
      status: RequestStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _local.saveWithOutbox(request);
      _bus.notify();
      unawaited(_sync.syncPending());
      return Ok(request);
    } on AppException catch (error) {
      return Err(error);
    } catch (error, stack) {
      return Err(CacheException('Could not save the request.'), stack);
    }
  }

  @override
  Future<Result<List<ServiceRequest>>> list({RequestStatus? filter}) async {
    try {
      return Ok(await _local.list(filter: filter));
    } catch (error, stack) {
      return Err(CacheException('Could not load requests.'), stack);
    }
  }

  @override
  Future<Result<ServiceRequest?>> byId(String id) async {
    try {
      return Ok(await _local.byId(id));
    } catch (error, stack) {
      return Err(CacheException('Could not load the request.'), stack);
    }
  }

  @override
  Future<Result<void>> retry(String id) async {
    try {
      await _local.requeueForRetry(id, updatedAt: _clock.now());
      _bus.notify();
      unawaited(_sync.syncPending(userInitiated: true));
      return const Ok<void>(null);
    } catch (error, stack) {
      return Err(CacheException('Could not retry the request.'), stack);
    }
  }

  @override
  Future<Result<List<SyncAttempt>>> attempts(String id) async {
    try {
      return Ok(await _local.attemptsFor(id));
    } catch (error, stack) {
      return Err(CacheException('Could not load sync history.'), stack);
    }
  }
}
