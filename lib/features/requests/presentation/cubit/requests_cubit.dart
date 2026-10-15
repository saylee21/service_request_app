import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_logger.dart';
import '../../data/datasources/connectivity_probe.dart';
import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_stats.dart';
import '../../domain/repositories/request_repository.dart';
import '../../domain/repositories/sync_repository.dart';

class RequestsState extends Equatable {
  const RequestsState({
    this.loading = true,
    this.requests = const <ServiceRequest>[],
    this.filter,
    this.stats = const SyncStats(),
    this.online = true,
    this.syncing = false,
    this.error,
  });

  final bool loading;
  final List<ServiceRequest> requests;
  final RequestStatus? filter;
  final SyncStats stats;
  final bool online;
  final bool syncing;
  final String? error;

  RequestsState copyWith({
    bool? loading,
    List<ServiceRequest>? requests,
    RequestStatus? filter,
    bool clearFilter = false,
    SyncStats? stats,
    bool? online,
    bool? syncing,
    String? error,
    bool clearError = false,
  }) => RequestsState(
    loading: loading ?? this.loading,
    requests: requests ?? this.requests,
    filter: clearFilter ? null : (filter ?? this.filter),
    stats: stats ?? this.stats,
    online: online ?? this.online,
    syncing: syncing ?? this.syncing,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => <Object?>[
    loading,
    requests,
    filter,
    stats,
    online,
    syncing,
    error,
  ];
}

/// Backs the requests list: loading, filtering, live updates, offline banner
/// and manual sync/retry.
class RequestsCubit extends Cubit<RequestsState> {
  RequestsCubit({
    required RequestRepository requestRepository,
    required SyncRepository syncRepository,
    required ConnectivityProbe connectivity,
  }) : _requests = requestRepository,
       _sync = syncRepository,
       _connectivity = connectivity,
       super(const RequestsState());

  final RequestRepository _requests;
  final SyncRepository _sync;
  final ConnectivityProbe _connectivity;

  StreamSubscription<void>? _changesSub;
  StreamSubscription<bool>? _connectivitySub;

  Future<void> init() async {
    final bool online = await _connectivity.isOnline();
    emit(state.copyWith(online: online));
    _changesSub = _requests.changes.listen((_) => _reload());
    _connectivitySub = _connectivity.onStatusChange.listen((bool online) {
      emit(state.copyWith(online: online));
      if (online) unawaited(_sync.syncPending());
    });
    await _reload();
  }

  Future<void> setFilter(RequestStatus? filter) async {
    emit(state.copyWith(filter: filter, clearFilter: filter == null));
    await _reload();
  }

  Future<void> refresh() => _reload();

  Future<void> syncNow() async {
    emit(state.copyWith(syncing: true, clearError: true));
    await _sync.syncPending(userInitiated: true);
    emit(state.copyWith(syncing: false));
    await _reload();
  }

  Future<void> retry(String id) async {
    await _requests.retry(id);
    await _reload();
  }

  Future<void> _reload() async {
    final result = await _requests.list(filter: state.filter);
    final statsResult = await _sync.stats();

    final List<ServiceRequest> requests = result.fold(
      onOk: (List<ServiceRequest> r) => r,
      onErr: (_) => state.requests,
    );
    final SyncStats stats = statsResult.fold(
      onOk: (SyncStats s) => s,
      onErr: (_) => state.stats,
    );

    String? error;
    result.fold(
      onOk: (_) {},
      onErr: (Object e) {
        error = e.toString();
        AppLogger.w('Failed to load requests: $e');
      },
    );

    emit(
      state.copyWith(
        loading: false,
        requests: requests,
        stats: stats,
        error: error,
        clearError: error == null,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _changesSub?.cancel();
    await _connectivitySub?.cancel();
    return super.close();
  }
}
