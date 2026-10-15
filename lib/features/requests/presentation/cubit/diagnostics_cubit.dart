import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sync_attempt.dart';
import '../../domain/entities/sync_stats.dart';
import '../../domain/repositories/sync_repository.dart';

class DiagnosticsState extends Equatable {
  const DiagnosticsState({
    this.stats = const SyncStats(),
    this.attempts = const <SyncAttempt>[],
    this.loading = true,
  });

  final SyncStats stats;
  final List<SyncAttempt> attempts;
  final bool loading;

  @override
  List<Object?> get props => <Object?>[stats, attempts, loading];
}

/// Read-only view of the outbox health and recent sync attempts.
class DiagnosticsCubit extends Cubit<DiagnosticsState> {
  DiagnosticsCubit(this._sync) : super(const DiagnosticsState());

  final SyncRepository _sync;

  Future<void> load() async {
    final statsResult = await _sync.stats();
    final attemptsResult = await _sync.recentAttempts();
    emit(
      DiagnosticsState(
        stats: statsResult.fold(
          onOk: (SyncStats s) => s,
          onErr: (_) => const SyncStats(),
        ),
        attempts: attemptsResult.fold(
          onOk: (List<SyncAttempt> a) => a,
          onErr: (_) => const <SyncAttempt>[],
        ),
        loading: false,
      ),
    );
  }
}
