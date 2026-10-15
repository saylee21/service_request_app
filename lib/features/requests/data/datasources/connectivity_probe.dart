import 'package:connectivity_plus/connectivity_plus.dart';

/// Minimal connectivity abstraction so the sync engine can be tested without
/// the platform plugin.
abstract class ConnectivityProbe {
  Future<bool> isOnline();

  /// Emits whenever connectivity changes.
  Stream<bool> get onStatusChange;
}

class PluginConnectivityProbe implements ConnectivityProbe {
  PluginConnectivityProbe(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}
