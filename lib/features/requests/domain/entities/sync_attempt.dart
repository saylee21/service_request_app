/// Outcome of a single sync attempt.
enum SyncResult {
  success,
  duplicate,
  transientFailure,
  permanentFailure;

  static SyncResult parse(String raw) {
    switch (raw) {
      case 'success':
        return SyncResult.success;
      case 'duplicate':
        return SyncResult.duplicate;
      case 'transient_failure':
        return SyncResult.transientFailure;
      case 'permanent_failure':
        return SyncResult.permanentFailure;
      default:
        return SyncResult.transientFailure;
    }
  }

  /// Stored value in the database.
  String get wire => switch (this) {
    SyncResult.success => 'success',
    SyncResult.duplicate => 'duplicate',
    SyncResult.transientFailure => 'transient_failure',
    SyncResult.permanentFailure => 'permanent_failure',
  };

  String get label => switch (this) {
    SyncResult.success => 'Success',
    SyncResult.duplicate => 'Duplicate (already saved)',
    SyncResult.transientFailure => 'Transient failure',
    SyncResult.permanentFailure => 'Permanent failure',
  };

  bool get isSuccess =>
      this == SyncResult.success || this == SyncResult.duplicate;
}

/// One row in the diagnostics log. Contains no field values.
class SyncAttempt {
  const SyncAttempt({
    this.id,
    required this.requestId,
    required this.attempt,
    required this.result,
    required this.at,
    this.httpStatus,
    this.durationMs,
    this.message,
  });

  final int? id;
  final String requestId;
  final int attempt;
  final SyncResult result;
  final DateTime at;
  final int? httpStatus;
  final int? durationMs;
  final String? message;
}
