import '../../../../core/result.dart';
import '../entities/sync_attempt.dart';
import '../entities/sync_stats.dart';
import '../entities/sync_summary.dart';

/// Owns the outbox drain loop: scheduling, backoff, connectivity and startup
/// recovery.
abstract class SyncRepository {
  /// Call once at startup: resets stuck `Syncing -> Pending` rows and schedules
  /// a drain.
  Future<void> onStartup();

  /// Drains the outbox. Returns a summary of what happened this run.
  Future<Result<SyncSummary>> syncPending({bool userInitiated = false});

  Future<Result<SyncStats>> stats();

  /// Recent diagnostic attempts, newest first. No field values.
  Future<Result<List<SyncAttempt>>> recentAttempts({int limit = 100});

  /// Emits whenever requests/outbox/attempts change.
  Stream<void> get changes;

  Future<void> dispose();
}
