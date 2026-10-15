import 'dart:async';

/// Broadcasts a signal whenever persisted data changes, so the UI can reload
/// without polling. Emits no payload; consumers just re-query.
class ChangeBus {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
