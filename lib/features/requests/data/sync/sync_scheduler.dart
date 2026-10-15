import 'dart:async';

/// Coalesces sync triggers into at most one in-flight drain.
///
/// - [trigger] runs immediately (save, reconnect, manual).
/// - [scheduleRetry] runs once after a backoff delay.
/// - a periodic timer is a safety net for anything missed.
class SyncScheduler {
  SyncScheduler(this._drain, {this.period = const Duration(seconds: 30)});

  final Future<void> Function() _drain;
  final Duration period;

  Timer? _periodic;
  Timer? _retry;
  bool _running = false;

  void start() {
    _periodic ??= Timer.periodic(period, (_) => trigger());
  }

  void trigger() => unawaited(_run());

  void scheduleRetry(Duration delay) {
    _retry?.cancel();
    _retry = Timer(delay, trigger);
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      await _drain();
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _periodic?.cancel();
    _retry?.cancel();
    _periodic = null;
    _retry = null;
  }
}
