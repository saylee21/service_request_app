import 'package:sqflite/sqflite.dart';

import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_attempt.dart';
import '../../domain/entities/sync_stats.dart';
import '../mappers/request_mapper.dart';
import 'app_database.dart';

/// One queued submission, in FIFO order by `seq`.
class OutboxItem {
  const OutboxItem({
    required this.seq,
    required this.requestId,
    required this.idempotencyKey,
  });

  final int seq;
  final String requestId;
  final String idempotencyKey;
}

/// All local SQLite access for requests, the outbox and sync attempts.
class RequestLocalDataSource {
  RequestLocalDataSource(this._db);

  final AppDatabase _db;

  /// Inserts the request and its outbox row in a single transaction, so the two
  /// tables can never disagree.
  Future<void> saveWithOutbox(ServiceRequest request) async {
    final Database db = await _db.database;
    await db.transaction((Transaction txn) async {
      await txn.insert(
        'requests',
        RequestMapper.toRow(request),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('outbox', <String, Object?>{
        'request_id': request.id,
        'idempotency_key': request.id,
        'enqueued_at': request.createdAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<ServiceRequest>> list({RequestStatus? filter}) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'requests',
      where: filter == null ? null : 'status = ?',
      whereArgs: filter == null ? null : <Object?>[filter.name],
      orderBy: 'created_at DESC',
    );
    return rows.map(RequestMapper.fromRow).toList(growable: false);
  }

  Future<ServiceRequest?> byId(String id) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'requests',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : RequestMapper.fromRow(rows.first);
  }

  Future<void> setStatus(
    String id,
    RequestStatus status, {
    String? serverMessage,
    bool clearServerMessage = false,
    DateTime? updatedAt,
    DateTime? syncedAt,
    int? attempts,
    DateTime? lastAttemptAt,
  }) async {
    final Database db = await _db.database;
    final Map<String, Object?> values = <String, Object?>{
      'status': status.name,
    };
    if (serverMessage != null) values['server_message'] = serverMessage;
    if (clearServerMessage) values['server_message'] = null;
    if (updatedAt != null) values['updated_at'] = updatedAt.toIso8601String();
    if (syncedAt != null) values['synced_at'] = syncedAt.toIso8601String();
    if (attempts != null) values['attempts'] = attempts;
    if (lastAttemptAt != null) {
      values['last_attempt_at'] = lastAttemptAt.toIso8601String();
    }
    await db.update(
      'requests',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Startup recovery: any request stuck mid-flight becomes pending again.
  Future<void> resetSyncingToPending() async {
    final Database db = await _db.database;
    await db.update(
      'requests',
      <String, Object?>{'status': RequestStatus.pending.name},
      where: 'status = ?',
      whereArgs: <Object?>[RequestStatus.syncing.name],
    );
  }

  /// Puts a failed request back in the queue for a manual retry, re-adding the
  /// outbox row if it was removed.
  Future<void> requeueForRetry(String id, {required DateTime updatedAt}) async {
    final Database db = await _db.database;
    await db.update(
      'requests',
      <String, Object?>{
        'status': RequestStatus.pending.name,
        'server_message': null,
        'updated_at': updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    final List<Map<String, Object?>> existing = await db.query(
      'outbox',
      where: 'request_id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('outbox', <String, Object?>{
        'request_id': id,
        'idempotency_key': id,
        'enqueued_at': updatedAt.toIso8601String(),
      });
    }
  }

  Future<List<OutboxItem>> pendingOutbox({int limit = 50}) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT o.seq, o.request_id, o.idempotency_key
      FROM outbox o
      JOIN requests r ON r.id = o.request_id
      WHERE r.status = ?
      ORDER BY o.seq ASC
      LIMIT ?
      ''',
      <Object?>[RequestStatus.pending.name, limit],
    );
    return rows
        .map(
          (Map<String, Object?> r) => OutboxItem(
            seq: r['seq'] as int,
            requestId: r['request_id'] as String,
            idempotencyKey: r['idempotency_key'] as String,
          ),
        )
        .toList(growable: false);
  }

  Future<void> removeOutbox(int seq) async {
    final Database db = await _db.database;
    await db.delete('outbox', where: 'seq = ?', whereArgs: <Object?>[seq]);
  }

  Future<void> insertAttempt(SyncAttempt attempt) async {
    final Database db = await _db.database;
    await db.insert('sync_attempts', RequestMapper.attemptToRow(attempt));
  }

  Future<List<SyncAttempt>> attemptsFor(
    String requestId, {
    int limit = 50,
  }) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'sync_attempts',
      where: 'request_id = ?',
      whereArgs: <Object?>[requestId],
      orderBy: 'at DESC, id DESC',
      limit: limit,
    );
    return rows.map(RequestMapper.attemptFromRow).toList(growable: false);
  }

  Future<List<SyncAttempt>> recentAttempts({int limit = 100}) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'sync_attempts',
      orderBy: 'at DESC, id DESC',
      limit: limit,
    );
    return rows.map(RequestMapper.attemptFromRow).toList(growable: false);
  }

  Future<SyncStats> stats() async {
    final Database db = await _db.database;

    int pending = 0;
    int syncing = 0;
    int failed = 0;
    int synced = 0;
    final List<Map<String, Object?>> group = await db.rawQuery(
      'SELECT status, COUNT(*) AS c FROM requests GROUP BY status',
    );
    for (final Map<String, Object?> row in group) {
      final int c = (row['c'] as int?) ?? 0;
      switch (RequestStatus.parse(row['status'] as String?)) {
        case RequestStatus.pending:
          pending = c;
        case RequestStatus.syncing:
          syncing = c;
        case RequestStatus.failed:
          failed = c;
        case RequestStatus.synced:
          synced = c;
      }
    }

    final List<Map<String, Object?>> success = await db.rawQuery(
      'SELECT MAX(synced_at) AS t FROM requests WHERE synced_at IS NOT NULL',
    );
    final String? lastSuccess = success.first['t'] as String?;

    final List<Map<String, Object?>> error = await db.rawQuery('''
      SELECT message, at FROM sync_attempts
      WHERE result IN ('transient_failure', 'permanent_failure')
      ORDER BY at DESC, id DESC LIMIT 1
      ''');
    final String? lastError = error.isEmpty
        ? null
        : error.first['message'] as String?;
    final DateTime? lastErrorAt = error.isEmpty
        ? null
        : DateTime.tryParse(error.first['at'] as String? ?? '');

    return SyncStats(
      pending: pending,
      syncing: syncing,
      failed: failed,
      synced: synced,
      lastSuccessAt: lastSuccess == null
          ? null
          : DateTime.tryParse(lastSuccess),
      lastError: lastError,
      lastErrorAt: lastErrorAt,
      dbVersion: AppDatabase.schemaVersion,
    );
  }
}
