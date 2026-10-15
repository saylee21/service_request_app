import 'dart:math';

import '../../../../core/result.dart';

/// What to do after a failed attempt.
enum RetryDecision { retryLater, giveUp }

/// Exponential backoff with a cap and jitter.
///
/// Transient errors only: 5xx, timeouts and connection failures. Any 4xx is a
/// permanent failure and is surfaced to the user instead of being retried.
class RetryPolicy {
  RetryPolicy({
    this.maxAttempts = 5,
    this.base = const Duration(seconds: 2),
    this.factor = 2,
    this.cap = const Duration(seconds: 30),
    this.totalBudget = const Duration(minutes: 2),
    this.jitterRatio = 0.2,
    Random? random,
  }) : _random = random ?? Random();

  final int maxAttempts;
  final Duration base;
  final int factor;
  final Duration cap;
  final Duration totalBudget;

  /// ±20% jitter by default, so many clients do not retry in lockstep.
  final double jitterRatio;

  final Random _random;

  /// True when [error] is worth retrying.
  bool isTransient(Object error) {
    if (error is NetworkException) return true;
    if (error is ServerException) {
      final int? status = error.statusCode;
      if (status == null) return true; // timeout / no response
      return status >= 500;
    }
    return false;
  }

  /// Number of attempts already made must be `< maxAttempts` to keep going.
  bool canRetry(int attemptsMade) => attemptsMade < maxAttempts;

  /// Delay before attempt `attemptsMade + 1`, or null when out of attempts.
  Duration? nextDelay(int attemptsMade) {
    if (!canRetry(attemptsMade)) return null;
    final double raw =
        base.inMilliseconds * pow(factor, attemptsMade - 1).toDouble();
    final double capped = min(raw, cap.inMilliseconds.toDouble());
    final double jitter = 1 + (_random.nextDouble() * 2 - 1) * jitterRatio;
    final int ms = (capped * jitter).round().clamp(0, cap.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  RetryDecision decide({
    required int attemptsMade,
    required Object error,
    required Duration elapsed,
  }) {
    if (elapsed > totalBudget) return RetryDecision.giveUp;
    if (!canRetry(attemptsMade)) return RetryDecision.giveUp;
    if (!isTransient(error)) return RetryDecision.giveUp;
    return RetryDecision.retryLater;
  }
}
