/// Injectable clock so time-dependent logic (backoff, retries, timelines) can
/// be tested deterministically.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
