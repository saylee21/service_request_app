import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/core/change_bus.dart';
import 'package:service_request_app/core/result.dart';
import 'package:service_request_app/features/requests/data/datasources/app_database.dart';
import 'package:service_request_app/features/requests/data/datasources/request_local_data_source.dart';
import 'package:service_request_app/features/requests/data/datasources/submission_remote_data_source.dart';
import 'package:service_request_app/features/requests/data/repositories/sync_repository_impl.dart';
import 'package:service_request_app/features/requests/domain/entities/request_status.dart';
import 'package:service_request_app/features/requests/domain/entities/sync_attempt.dart';
import 'package:service_request_app/features/requests/domain/entities/sync_summary.dart';
import 'package:service_request_app/features/requests/domain/services/retry_policy.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fakes.dart';

SyncSummary summaryOf(Result<SyncSummary> result) =>
    result.fold(onOk: (SyncSummary s) => s, onErr: (_) => const SyncSummary());

void main() {
  setUpAll(() => sqfliteFfiInit());

  late AppDatabase db;
  late RequestLocalDataSource local;
  late FakeSubmissionRemote remote;
  late FakeConnectivity connectivity;
  late SyncRepositoryImpl sync;

  setUp(() {
    db = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    local = RequestLocalDataSource(db);
    remote = FakeSubmissionRemote();
    connectivity = FakeConnectivity();
    sync = SyncRepositoryImpl(
      local: local,
      remote: remote,
      retryPolicy: RetryPolicy(jitterRatio: 0, random: Random(1)),
      connectivity: connectivity,
      clock: FakeClock(),
      bus: ChangeBus(),
      scheduleRetries: false,
    );
  });

  tearDown(() async {
    await sync.dispose();
    await connectivity.dispose();
    await db.close();
  });

  test(
    'successful submit marks the request synced and clears the outbox',
    () async {
      await local.saveWithOutbox(makeRequest(id: 'a'));
      remote.enqueue(const SubmitOutcome(duplicate: false, message: 'Created'));

      final SyncSummary summary = summaryOf(await sync.syncPending());

      expect(summary.synced, 1);
      final request = await local.byId('a');
      expect(request!.status, RequestStatus.synced);
      expect(request.syncedAt, isNotNull);
      expect(await local.pendingOutbox(), isEmpty);
      expect((await local.attemptsFor('a')).single.result, SyncResult.success);
    },
  );

  test('200 (duplicate) is treated as success', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    remote.enqueue(
      const SubmitOutcome(duplicate: true, message: 'Already saved'),
    );

    await sync.syncPending();

    expect((await local.byId('a'))!.status, RequestStatus.synced);
    expect((await local.attemptsFor('a')).single.result, SyncResult.duplicate);
  });

  test('4xx fails permanently and is not retried automatically', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    remote.enqueue(const ServerException('Invalid payload', statusCode: 422));

    final SyncSummary summary = summaryOf(await sync.syncPending());

    expect(summary.failed, 1);
    final request = await local.byId('a');
    expect(request!.status, RequestStatus.failed);
    expect(request.serverMessage, 'Invalid payload');
    expect(
      (await local.attemptsFor('a')).single.result,
      SyncResult.permanentFailure,
    );

    // A second drain does nothing: failed requests wait for a manual retry.
    await sync.syncPending();
    expect(remote.calls, 1);
  });

  test(
    'transient failures retry with the same idempotency key, then succeed',
    () async {
      await local.saveWithOutbox(makeRequest(id: 'a'));
      remote.enqueue(const NetworkException());
      remote.enqueue(const SubmitOutcome(duplicate: false, message: 'Created'));

      final SyncSummary first = summaryOf(await sync.syncPending());
      expect(first.retryScheduled, isTrue);
      expect((await local.byId('a'))!.status, RequestStatus.pending);
      expect(
        (await local.attemptsFor('a')).single.result,
        SyncResult.transientFailure,
      );

      final SyncSummary second = summaryOf(await sync.syncPending());
      expect(second.synced, 1);
      expect((await local.byId('a'))!.status, RequestStatus.synced);

      // Retries reuse the original key so the server can de-duplicate.
      expect(remote.idempotencyKeys.toSet().length, 1);
    },
  );

  test('exhausting the attempt budget fails the request', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    for (int i = 0; i < 5; i++) {
      remote.enqueue(const NetworkException());
      await sync.syncPending();
    }

    final request = await local.byId('a');
    expect(request!.status, RequestStatus.failed);
    expect(request.attempts, 5);
    expect(remote.calls, 5);

    final List<SyncAttempt> attempts = await local.attemptsFor('a');
    expect(attempts.length, 5);
    expect(
      attempts.every((a) => a.result == SyncResult.transientFailure),
      isTrue,
    );

    // A manual retry can still push it through.
    await local.requeueForRetry('a', updatedAt: DateTime(2025, 1, 2));
    remote.enqueue(const SubmitOutcome(duplicate: false, message: 'Created'));
    await sync.syncPending();
    expect((await local.byId('a'))!.status, RequestStatus.synced);
  });

  test('being offline consumes no attempt and reschedules', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    connectivity.online = false;

    final SyncSummary summary = summaryOf(await sync.syncPending());

    expect(summary.retryScheduled, isTrue);
    expect(remote.calls, 0);
    final request = await local.byId('a');
    expect(request!.status, RequestStatus.pending);
    expect(request.attempts, 0);
  });

  test('multiple requests drain in FIFO order', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    await local.saveWithOutbox(makeRequest(id: 'b'));
    remote.enqueue(const SubmitOutcome(duplicate: false));
    remote.enqueue(const SubmitOutcome(duplicate: false));

    final SyncSummary summary = summaryOf(await sync.syncPending());

    expect(summary.synced, 2);
    expect(remote.calls, 2);
    expect((await local.pendingOutbox()), isEmpty);
  });

  test(
    'a transient failure stops the queue so later items cannot overtake',
    () async {
      await local.saveWithOutbox(makeRequest(id: 'a'));
      await local.saveWithOutbox(makeRequest(id: 'b'));
      remote.enqueue(const NetworkException()); // a fails transiently
      remote.enqueue(const SubmitOutcome(duplicate: false)); // b would succeed

      final SyncSummary summary = summaryOf(await sync.syncPending());

      expect(summary.retryScheduled, isTrue);
      expect(remote.calls, 1, reason: 'b must not be sent before a succeeds');
      expect((await local.byId('a'))!.status, RequestStatus.pending);
      expect((await local.byId('b'))!.status, RequestStatus.pending);
    },
  );

  test('onStartup recovers a request stuck in syncing', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    await local.setStatus('a', RequestStatus.syncing);

    await sync.onStartup();

    expect((await local.byId('a'))!.status, RequestStatus.pending);
  });
}
