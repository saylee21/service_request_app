import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/core/result.dart';
import 'package:service_request_app/features/requests/domain/services/retry_policy.dart';

void main() {
  group('RetryPolicy backoff', () {
    test('grows exponentially and is capped', () {
      final RetryPolicy policy = RetryPolicy(
        maxAttempts: 10,
        base: const Duration(seconds: 2),
        factor: 2,
        cap: const Duration(seconds: 30),
        jitterRatio: 0,
        random: Random(1),
      );
      expect(policy.nextDelay(1)!.inSeconds, 2);
      expect(policy.nextDelay(2)!.inSeconds, 4);
      expect(policy.nextDelay(3)!.inSeconds, 8);
      expect(policy.nextDelay(4)!.inSeconds, 16);
      expect(policy.nextDelay(5)!.inSeconds, 30); // 32 capped to 30
      expect(policy.nextDelay(6)!.inSeconds, 30);
    });

    test('returns null once attempts are exhausted', () {
      final RetryPolicy policy = RetryPolicy(jitterRatio: 0, random: Random(1));
      expect(policy.nextDelay(4), isNotNull);
      expect(policy.nextDelay(5), isNull);
    });

    test('applies jitter within ±20%', () {
      final RetryPolicy policy = RetryPolicy(
        base: const Duration(seconds: 2),
        jitterRatio: 0.2,
        random: Random(7),
      );
      for (int i = 0; i < 50; i++) {
        final int ms = policy.nextDelay(1)!.inMilliseconds;
        expect(ms, inInclusiveRange(1600, 2400));
      }
    });
  });

  group('RetryPolicy classification', () {
    test('4xx is permanent; 5xx, timeout and network are transient', () {
      final RetryPolicy policy = RetryPolicy();
      expect(
        policy.isTransient(const ServerException('bad', statusCode: 422)),
        isFalse,
      );
      expect(
        policy.isTransient(const ServerException('bad', statusCode: 400)),
        isFalse,
      );
      expect(
        policy.isTransient(const ServerException('oops', statusCode: 500)),
        isTrue,
      );
      expect(policy.isTransient(const ServerException('timeout')), isTrue);
      expect(policy.isTransient(const NetworkException()), isTrue);
    });

    test('decide retries transients and gives up on permanent/exhausted', () {
      final RetryPolicy policy = RetryPolicy();
      expect(
        policy.decide(
          attemptsMade: 1,
          error: const NetworkException(),
          elapsed: Duration.zero,
        ),
        RetryDecision.retryLater,
      );
      expect(
        policy.decide(
          attemptsMade: 1,
          error: const ServerException('bad', statusCode: 400),
          elapsed: Duration.zero,
        ),
        RetryDecision.giveUp,
      );
      expect(
        policy.decide(
          attemptsMade: 5,
          error: const NetworkException(),
          elapsed: Duration.zero,
        ),
        RetryDecision.giveUp,
      );
    });

    test('decide gives up after the total time budget', () {
      final RetryPolicy policy = RetryPolicy(
        totalBudget: const Duration(seconds: 30),
      );
      expect(
        policy.decide(
          attemptsMade: 1,
          error: const NetworkException(),
          elapsed: const Duration(seconds: 31),
        ),
        RetryDecision.giveUp,
      );
    });
  });
}
