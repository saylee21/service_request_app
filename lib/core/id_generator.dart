import 'package:uuid/uuid.dart';

/// Injectable id generator so tests can produce deterministic ids.
abstract class IdGenerator {
  String newId();
}

/// Production implementation: random UUID v4, generated once per saved request
/// and reused as the outbox idempotency key on every retry attempt.
class UuidGenerator implements IdGenerator {
  const UuidGenerator();

  @override
  String newId() => const Uuid().v4();
}
