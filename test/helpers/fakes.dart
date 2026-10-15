import 'dart:async';

import 'package:dio/dio.dart';
import 'package:service_request_app/core/change_bus.dart';
import 'package:service_request_app/core/clock.dart';
import 'package:service_request_app/core/id_generator.dart';
import 'package:service_request_app/core/result.dart';
import 'package:service_request_app/features/form/domain/entities/form_definition.dart';
import 'package:service_request_app/features/requests/data/datasources/connectivity_probe.dart';
import 'package:service_request_app/features/requests/data/datasources/submission_remote_data_source.dart';
import 'package:service_request_app/features/requests/domain/entities/request_status.dart';
import 'package:service_request_app/features/requests/domain/entities/service_request.dart';
import 'package:service_request_app/features/requests/domain/entities/sync_attempt.dart';
import 'package:service_request_app/features/requests/domain/entities/sync_stats.dart';
import 'package:service_request_app/features/requests/domain/entities/sync_summary.dart';
import 'package:service_request_app/features/requests/domain/repositories/request_repository.dart';
import 'package:service_request_app/features/requests/domain/repositories/sync_repository.dart';

class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2025, 1, 1, 12);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator([this.prefix = 'id']);
  final String prefix;
  int _counter = 0;

  @override
  String newId() => '$prefix-${_counter++}';
}

class FakeConnectivity implements ConnectivityProbe {
  FakeConnectivity({this.online = true});

  bool online;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void emit(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}

/// Returns queued responses in order; an [Exception] in the queue is thrown.
class FakeSubmissionRemote extends SubmissionRemoteDataSource {
  FakeSubmissionRemote() : super(Dio());

  final List<Object> responses = <Object>[];
  int calls = 0;
  final List<String> idempotencyKeys = <String>[];

  void enqueue(Object response) => responses.add(response);

  @override
  Future<SubmitOutcome> submit({
    required ServiceRequest request,
    required String idempotencyKey,
  }) async {
    calls++;
    idempotencyKeys.add(idempotencyKey);
    if (responses.isEmpty) {
      throw StateError('FakeSubmissionRemote ran out of responses');
    }
    final Object response = responses.removeAt(0);
    if (response is Exception) throw response;
    return response as SubmitOutcome;
  }
}

ServiceRequest makeRequest({
  String id = 'r1',
  RequestStatus status = RequestStatus.pending,
  String title = 'Broken street light',
  String? priority,
  Map<String, Object?>? data,
  DateTime? createdAt,
  int attempts = 0,
  String? serverMessage,
  DateTime? syncedAt,
}) {
  final DateTime when = createdAt ?? DateTime(2025, 1, 1, 12);
  return ServiceRequest(
    id: id,
    formId: 'request-form',
    formVersion: 2,
    title: title,
    priority: priority,
    data: data ?? <String, Object?>{'title': title},
    status: status,
    createdAt: when,
    updatedAt: when,
    syncedAt: syncedAt,
    serverMessage: serverMessage,
    attempts: attempts,
  );
}

class FakeRequestRepository implements RequestRepository {
  final List<ServiceRequest> items = <ServiceRequest>[];
  final ChangeBus bus = ChangeBus();
  final List<String> retried = <String>[];

  @override
  Stream<void> get changes => bus.stream;

  @override
  Future<Result<List<ServiceRequest>>> list({RequestStatus? filter}) async =>
      Ok(
        filter == null
            ? List<ServiceRequest>.of(items)
            : items.where((ServiceRequest r) => r.status == filter).toList(),
      );

  @override
  Future<Result<ServiceRequest?>> byId(String id) async {
    for (final ServiceRequest r in items) {
      if (r.id == id) return Ok(r);
    }
    return const Ok<ServiceRequest?>(null);
  }

  @override
  Future<Result<ServiceRequest>> save({
    required FormDefinition form,
    required Map<String, Object?> values,
  }) async => Ok(makeRequest());

  @override
  Future<Result<void>> retry(String id) async {
    retried.add(id);
    final int index = items.indexWhere((ServiceRequest r) => r.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(status: RequestStatus.pending);
    }
    bus.notify();
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<SyncAttempt>>> attempts(String id) async =>
      const Ok<List<SyncAttempt>>(<SyncAttempt>[]);
}

class FakeSyncRepository implements SyncRepository {
  SyncStats statsValue = const SyncStats();
  int syncCalls = 0;
  final ChangeBus bus = ChangeBus();

  @override
  Stream<void> get changes => bus.stream;

  @override
  Future<Result<SyncStats>> stats() async => Ok(statsValue);

  @override
  Future<Result<SyncSummary>> syncPending({bool userInitiated = false}) async {
    syncCalls++;
    return const Ok<SyncSummary>(SyncSummary());
  }

  @override
  Future<void> onStartup() async {}

  @override
  Future<Result<List<SyncAttempt>>> recentAttempts({int limit = 100}) async =>
      const Ok<List<SyncAttempt>>(<SyncAttempt>[]);

  @override
  Future<void> dispose() async {}
}
