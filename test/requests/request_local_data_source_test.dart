import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/requests/data/datasources/app_database.dart';
import 'package:service_request_app/features/requests/data/datasources/request_local_data_source.dart';
import 'package:service_request_app/features/requests/domain/entities/request_status.dart';
import 'package:service_request_app/features/requests/domain/entities/sync_attempt.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fakes.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase db;
  late RequestLocalDataSource local;

  setUp(() {
    db = AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    local = RequestLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('saveWithOutbox writes the request and its outbox row', () async {
    await local.saveWithOutbox(makeRequest(id: 'abc'));

    final list = await local.list();
    expect(list.length, 1);
    expect(list.single.id, 'abc');

    final outbox = await local.pendingOutbox();
    expect(outbox.length, 1);
    expect(outbox.single.requestId, 'abc');
    // Idempotency-Key is the request UUID.
    expect(outbox.single.idempotencyKey, 'abc');
  });

  test('re-saving the same id never duplicates the outbox row', () async {
    await local.saveWithOutbox(makeRequest(id: 'abc'));
    await local.saveWithOutbox(makeRequest(id: 'abc'));

    expect((await local.list()).length, 1);
    expect((await local.pendingOutbox()).length, 1);
  });

  test('pendingOutbox is FIFO by insertion order', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    await local.saveWithOutbox(makeRequest(id: 'b'));
    await local.saveWithOutbox(makeRequest(id: 'c'));

    final outbox = await local.pendingOutbox();
    expect(outbox.map((OutboxItem i) => i.requestId).toList(), <String>[
      'a',
      'b',
      'c',
    ]);
  });

  test('list filters by status', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    await local.saveWithOutbox(makeRequest(id: 'b'));
    await local.setStatus('b', RequestStatus.synced);

    final pending = await local.list(filter: RequestStatus.pending);
    expect(pending.map((r) => r.id).toList(), <String>['a']);
  });

  test('resetSyncingToPending recovers rows stuck mid-flight', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    await local.setStatus('a', RequestStatus.syncing);

    await local.resetSyncingToPending();

    expect((await local.byId('a'))!.status, RequestStatus.pending);
  });

  test(
    'requeueForRetry flips to pending and keeps a single outbox row',
    () async {
      await local.saveWithOutbox(makeRequest(id: 'a'));
      await local.setStatus('a', RequestStatus.failed, serverMessage: 'nope');

      await local.requeueForRetry('a', updatedAt: DateTime(2025, 1, 2));

      final request = await local.byId('a');
      expect(request!.status, RequestStatus.pending);
      expect(request.serverMessage, isNull);
      expect((await local.pendingOutbox()).length, 1);
    },
  );

  test('stats aggregates counts and surfaces the last error', () async {
    await local.saveWithOutbox(makeRequest(id: 'a'));
    await local.saveWithOutbox(makeRequest(id: 'b'));
    await local.setStatus(
      'b',
      RequestStatus.synced,
      syncedAt: DateTime(2025, 1, 1),
    );
    await local.insertAttempt(
      SyncAttempt(
        requestId: 'a',
        attempt: 1,
        result: SyncResult.permanentFailure,
        at: DateTime(2025, 1, 1),
        message: 'Invalid payload',
        httpStatus: 422,
      ),
    );

    final stats = await local.stats();
    expect(stats.pending, 1);
    expect(stats.synced, 1);
    expect(stats.outboxSize, 1);
    expect(stats.lastError, 'Invalid payload');
    expect(stats.lastSuccessAt, DateTime(2025, 1, 1));
  });

  test(
    'foreign keys cascade: deleting a request clears its attempts',
    () async {
      await local.saveWithOutbox(makeRequest(id: 'a'));
      await local.insertAttempt(
        SyncAttempt(
          requestId: 'a',
          attempt: 1,
          result: SyncResult.transientFailure,
          at: DateTime(2025, 1, 1),
          message: 'timeout',
        ),
      );

      final raw = await db.database;
      await raw.delete('requests', where: 'id = ?', whereArgs: <Object?>['a']);

      expect(await local.attemptsFor('a'), isEmpty);
      expect((await local.pendingOutbox()), isEmpty);
    },
  );
}
