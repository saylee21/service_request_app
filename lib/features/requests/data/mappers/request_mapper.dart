import 'dart:convert';

import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_attempt.dart';

/// Row <-> entity conversion for the requests and sync_attempts tables.
class RequestMapper {
  const RequestMapper._();

  static ServiceRequest fromRow(Map<String, Object?> row) => ServiceRequest(
    id: row['id'] as String,
    formId: row['form_id'] as String,
    formVersion: (row['form_version'] as int?) ?? 1,
    title: row['title'] as String,
    priority: row['priority'] as String?,
    data: decodeData(row['data_json']),
    status: RequestStatus.parse(row['status'] as String?),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    syncedAt: _dateOrNull(row['synced_at']),
    serverMessage: row['server_message'] as String?,
    attempts: (row['attempts'] as int?) ?? 0,
    lastAttemptAt: _dateOrNull(row['last_attempt_at']),
  );

  static Map<String, Object?> toRow(ServiceRequest r) => <String, Object?>{
    'id': r.id,
    'form_id': r.formId,
    'form_version': r.formVersion,
    'title': r.title,
    'priority': r.priority,
    'data_json': encodeData(r.data),
    'status': r.status.name,
    'created_at': r.createdAt.toIso8601String(),
    'updated_at': r.updatedAt.toIso8601String(),
    'synced_at': r.syncedAt?.toIso8601String(),
    'server_message': r.serverMessage,
    'attempts': r.attempts,
    'last_attempt_at': r.lastAttemptAt?.toIso8601String(),
  };

  static SyncAttempt attemptFromRow(Map<String, Object?> row) => SyncAttempt(
    id: row['id'] as int?,
    requestId: row['request_id'] as String,
    attempt: (row['attempt'] as int?) ?? 1,
    result: SyncResult.parse((row['result'] as String?) ?? ''),
    at: DateTime.parse(row['at'] as String),
    httpStatus: row['http_status'] as int?,
    durationMs: row['duration_ms'] as int?,
    message: row['message'] as String?,
  );

  static Map<String, Object?> attemptToRow(SyncAttempt a) => <String, Object?>{
    if (a.id != null) 'id': a.id,
    'request_id': a.requestId,
    'attempt': a.attempt,
    'result': a.result.wire,
    'http_status': a.httpStatus,
    'duration_ms': a.durationMs,
    'message': a.message,
    'at': a.at.toIso8601String(),
  };

  static Map<String, Object?> decodeData(Object? raw) {
    if (raw is! String || raw.isEmpty) return <String, Object?>{};
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map) return decoded.cast<String, Object?>();
    return <String, Object?>{};
  }

  static String encodeData(Map<String, Object?> data) => jsonEncode(data);

  static DateTime? _dateOrNull(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.parse(raw) : null;
}
