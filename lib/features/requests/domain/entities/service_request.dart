import 'request_status.dart';

/// A saved service request.
///
/// [data] holds the field values keyed by form field key. It is never logged.
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.formId,
    required this.formVersion,
    required this.title,
    required this.data,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.priority,
    this.syncedAt,
    this.serverMessage,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  final String id;
  final String formId;
  final int formVersion;
  final String title;
  final String? priority;
  final Map<String, Object?> data;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final String? serverMessage;
  final int attempts;

  /// When the most recent sync attempt happened (nullable until the first try).
  /// Added in schema v2.
  final DateTime? lastAttemptAt;

  ServiceRequest copyWith({
    RequestStatus? status,
    DateTime? updatedAt,
    DateTime? syncedAt,
    String? serverMessage,
    int? attempts,
    DateTime? lastAttemptAt,
    bool clearServerMessage = false,
  }) => ServiceRequest(
    id: id,
    formId: formId,
    formVersion: formVersion,
    title: title,
    priority: priority,
    data: data,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncedAt: syncedAt ?? this.syncedAt,
    serverMessage: clearServerMessage
        ? null
        : (serverMessage ?? this.serverMessage),
    attempts: attempts ?? this.attempts,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
  );
}
