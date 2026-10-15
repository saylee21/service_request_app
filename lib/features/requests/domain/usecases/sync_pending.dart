import '../../../../core/result.dart';
import '../entities/sync_summary.dart';
import '../repositories/sync_repository.dart';

/// Drains the outbox on demand (startup, reconnect, manual retry).
class SyncPending {
  const SyncPending(this._repository);

  final SyncRepository _repository;

  Future<Result<SyncSummary>> call({bool userInitiated = false}) =>
      _repository.syncPending(userInitiated: userInitiated);
}
