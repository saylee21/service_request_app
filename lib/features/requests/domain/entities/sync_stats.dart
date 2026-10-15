/// Aggregate counts and health used by the requests header and diagnostics.
class SyncStats {
  const SyncStats({
    this.pending = 0,
    this.syncing = 0,
    this.failed = 0,
    this.synced = 0,
    this.lastSuccessAt,
    this.lastError,
    this.lastErrorAt,
    this.dbVersion = 0,
  });

  final int pending;
  final int syncing;
  final int failed;
  final int synced;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final DateTime? lastErrorAt;

  /// Current SQLite schema version, shown on the diagnostics screen.
  final int dbVersion;

  int get total => pending + syncing + failed + synced;

  /// Everything still owed to the server.
  int get outboxSize => pending + syncing + failed;

  bool get hasFailures => failed > 0;
}
