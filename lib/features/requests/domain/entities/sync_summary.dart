/// Result of a single [SyncRepository.syncPending] run.
class SyncSummary {
  const SyncSummary({
    this.synced = 0,
    this.failed = 0,
    this.retryScheduled = false,
  });

  /// Count of requests that reached a terminal success state this run
  /// (freshly accepted or de-duplicated by the server).
  final int synced;

  /// Count of requests that hit a permanent failure this run.
  final int failed;

  /// True when at least one request hit a transient failure, so another run is
  /// scheduled.
  final bool retryScheduled;

  bool get didWork => synced > 0 || failed > 0;
}
