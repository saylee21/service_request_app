import 'dart:async';

import '../../../../core/app_logger.dart';
import '../../../../core/change_bus.dart';
import '../../../../core/clock.dart';
import '../../../../core/result.dart';
import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_attempt.dart';
import '../../domain/entities/sync_stats.dart';
import '../../domain/entities/sync_summary.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/services/retry_policy.dart';
import '../datasources/connectivity_probe.dart';
import '../datasources/request_local_data_source.dart';
import '../datasources/submission_remote_data_source.dart';
import '../sync/sync_scheduler.dart';

/// Drains the outbox in FIFO order with backoff, connectivity awareness and
/// idempotent retries.
class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl({
    required RequestLocalDataSource local,
    required SubmissionRemoteDataSource remote,
    required RetryPolicy retryPolicy,
    required ConnectivityProbe connectivity,
    required Clock clock,
    required ChangeBus bus,
    Duration period = const Duration(seconds: 30),
    bool scheduleRetries = true,
  }) : _local = local,
       _remote = remote,
       _retryPolicy = retryPolicy,
       _connectivity = connectivity,
       _clock = clock,
       _bus = bus,
       _scheduleRetries = scheduleRetries {
    _scheduler = SyncScheduler(_drainIgnoringResult, period: period);
  }

  final RequestLocalDataSource _local;
  final SubmissionRemoteDataSource _remote;
  final RetryPolicy _retryPolicy;
  final ConnectivityProbe _connectivity;
  final Clock _clock;
  final ChangeBus _bus;
  final bool _scheduleRetries;

  late final SyncScheduler _scheduler;
  StreamSubscription<bool>? _connectivitySub;

  /// First attempt time of the current failure episode, per request, so the
  /// total time budget can be enforced across retries within a session.
  final Map<String, DateTime> _episodeStart = <String, DateTime>{};

  bool _running = false;

  @override
  Stream<void> get changes => _bus.stream;

  @override
  Future<void> onStartup() async {
    await _local.resetSyncingToPending();
    _bus.notify();
    if (!_scheduleRetries) return;
    _connectivitySub = _connectivity.onStatusChange.listen((bool online) {
      if (online) _scheduler.trigger();
    });
    _scheduler.start();
    _scheduler.trigger();
  }

  @override
  Future<Result<SyncSummary>> syncPending({bool userInitiated = false}) async {
    final SyncSummary summary = await _drain(userInitiated: userInitiated);
    return Ok(summary);
  }

  @override
  Future<Result<SyncStats>> stats() async => Ok(await _local.stats());

  @override
  Future<Result<List<SyncAttempt>>> recentAttempts({int limit = 100}) async =>
      Ok(await _local.recentAttempts(limit: limit));

  @override
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _scheduler.dispose();
  }

  Future<void> _drainIgnoringResult() async {
    await _drain(userInitiated: false);
  }

  Future<SyncSummary> _drain({required bool userInitiated}) async {
    if (_running) return const SyncSummary();
    _running = true;

    int synced = 0;
    int failed = 0;
    bool retryScheduled = false;

    try {
      final List<OutboxItem> items = await _local.pendingOutbox(limit: 50);

      for (final OutboxItem item in items) {
        if (!await _connectivity.isOnline()) {
          // Stop early; connectivity listener and the periodic timer will
          // resume. No attempt is consumed while offline.
          retryScheduled = true;
          break;
        }

        final ServiceRequest? request = await _local.byId(item.requestId);
        if (request == null) {
          await _local.removeOutbox(item.seq);
          continue;
        }
        if (request.status == RequestStatus.synced) {
          await _local.removeOutbox(item.seq);
          continue;
        }

        await _local.setStatus(
          request.id,
          RequestStatus.syncing,
          clearServerMessage: true,
          updatedAt: _clock.now(),
        );
        _bus.notify();
        AppLogger.d(
          'Syncing request ${request.id} (attempt ${request.attempts + 1})',
        );

        final DateTime episode = _episodeStart.putIfAbsent(
          request.id,
          () => _clock.now(),
        );
        final DateTime startedAt = _clock.now();
        final int attemptsMade = request.attempts + 1;

        try {
          final SubmitOutcome outcome = await _remote.submit(
            request: request,
            idempotencyKey: item.idempotencyKey,
          );
          final DateTime now = _clock.now();
          await _local.setStatus(
            request.id,
            RequestStatus.synced,
            serverMessage: outcome.message,
            syncedAt: now,
            updatedAt: now,
            attempts: attemptsMade,
            lastAttemptAt: now,
          );
          await _local.insertAttempt(
            SyncAttempt(
              requestId: request.id,
              attempt: attemptsMade,
              result: outcome.duplicate
                  ? SyncResult.duplicate
                  : SyncResult.success,
              at: now,
              httpStatus: outcome.duplicate ? 200 : 201,
              durationMs: now.difference(startedAt).inMilliseconds,
              message: outcome.message,
            ),
          );
          await _local.removeOutbox(item.seq);
          _episodeStart.remove(request.id);
          synced++;
          _bus.notify();
        } on AppException catch (error) {
          final bool stopQueue = await _handleFailure(
            request: request,
            error: error,
            attemptsMade: attemptsMade,
            episode: episode,
            startedAt: startedAt,
            onRetryScheduled: () => retryScheduled = true,
            onFailed: () => failed++,
          );
          // A transient failure must not let later items overtake this one, so
          // the drain stops and preserves FIFO order. A 4xx is permanent and
          // does not block the rest of the queue.
          if (stopQueue) break;
        }
      }
    } catch (error, stack) {
      AppLogger.e('Sync drain aborted', error: error, stackTrace: stack);
    } finally {
      _running = false;
    }

    AppLogger.d(
      'Drain done: synced=$synced failed=$failed retryScheduled=$retryScheduled '
      '(userInitiated=$userInitiated)',
    );
    return SyncSummary(
      synced: synced,
      failed: failed,
      retryScheduled: retryScheduled,
    );
  }

  /// Returns true when the drain should stop to preserve FIFO order (a
  /// transient failure that will be retried), false when the queue may continue
  /// (a permanent 4xx / budget exhaustion).
  Future<bool> _handleFailure({
    required ServiceRequest request,
    required AppException error,
    required int attemptsMade,
    required DateTime episode,
    required DateTime startedAt,
    required void Function() onRetryScheduled,
    required void Function() onFailed,
  }) async {
    final DateTime now = _clock.now();
    final int durationMs = now.difference(startedAt).inMilliseconds;
    final int? statusCode = error is ServerException ? error.statusCode : null;

    final RetryDecision decision = _retryPolicy.decide(
      attemptsMade: attemptsMade,
      error: error,
      elapsed: now.difference(episode),
    );

    if (decision == RetryDecision.retryLater) {
      final Duration? delay = _retryPolicy.nextDelay(attemptsMade);
      await _local.setStatus(
        request.id,
        RequestStatus.pending,
        clearServerMessage: true,
        updatedAt: now,
        attempts: attemptsMade,
        lastAttemptAt: now,
      );
      await _local.insertAttempt(
        SyncAttempt(
          requestId: request.id,
          attempt: attemptsMade,
          result: SyncResult.transientFailure,
          at: now,
          httpStatus: statusCode,
          durationMs: durationMs,
          message: error.message,
        ),
      );
      AppLogger.w(
        'Transient failure for ${request.id} '
        '(attempt $attemptsMade, retry in ${delay?.inMilliseconds ?? 0}ms)',
      );
      if (_scheduleRetries && delay != null) _scheduler.scheduleRetry(delay);
      onRetryScheduled();
      _bus.notify();
      return true;
    }

    // Gave up: either a 4xx (permanent) or the attempt/budget limit.
    final bool permanent = !_retryPolicy.isTransient(error);
    await _local.setStatus(
      request.id,
      RequestStatus.failed,
      serverMessage: error.message,
      updatedAt: now,
      attempts: attemptsMade,
      lastAttemptAt: now,
    );
    await _local.insertAttempt(
      SyncAttempt(
        requestId: request.id,
        attempt: attemptsMade,
        result: permanent
            ? SyncResult.permanentFailure
            : SyncResult.transientFailure,
        at: now,
        httpStatus: statusCode,
        durationMs: durationMs,
        message: error.message,
      ),
    );
    _episodeStart.remove(request.id);
    AppLogger.w(
      'Giving up on ${request.id} after $attemptsMade attempt(s): '
      '${error.message}',
    );
    onFailed();
    _bus.notify();
    return false;
  }
}
