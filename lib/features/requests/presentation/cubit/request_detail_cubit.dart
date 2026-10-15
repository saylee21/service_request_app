import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../form/domain/entities/form_definition.dart';
import '../../../form/domain/repositories/form_repository.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_attempt.dart';
import '../../domain/repositories/request_repository.dart';

class RequestDetailState extends Equatable {
  const RequestDetailState({
    this.loading = true,
    this.request,
    this.attempts = const <SyncAttempt>[],
    this.form,
    this.error,
  });

  final bool loading;
  final ServiceRequest? request;
  final List<SyncAttempt> attempts;

  /// The form version this request was saved against, for labels and ordering.
  final FormDefinition? form;

  final String? error;

  RequestDetailState copyWith({
    bool? loading,
    ServiceRequest? request,
    List<SyncAttempt>? attempts,
    FormDefinition? form,
    String? error,
    bool clearError = false,
  }) => RequestDetailState(
    loading: loading ?? this.loading,
    request: request ?? this.request,
    attempts: attempts ?? this.attempts,
    form: form ?? this.form,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => <Object?>[loading, request, attempts, form, error];
}

/// Backs the detail screen: the request, its sync timeline and manual retry.
class RequestDetailCubit extends Cubit<RequestDetailState> {
  RequestDetailCubit({
    required RequestRepository requestRepository,
    required FormRepository formRepository,
    required this.requestId,
  }) : _requests = requestRepository,
       _forms = formRepository,
       super(const RequestDetailState());

  final RequestRepository _requests;
  final FormRepository _forms;
  final String requestId;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));

    final result = await _requests.byId(requestId);
    final ServiceRequest? request = result.fold(
      onOk: (ServiceRequest? r) => r,
      onErr: (_) => null,
    );

    if (request == null) {
      emit(state.copyWith(loading: false, error: 'Request not found.'));
      return;
    }

    final attemptsResult = await _requests.attempts(requestId);
    final List<SyncAttempt> attempts = attemptsResult.fold(
      onOk: (List<SyncAttempt> a) => a,
      onErr: (_) => const <SyncAttempt>[],
    );

    final cachedForm = await _forms.getCachedForm(
      request.formId,
      request.formVersion,
    );
    final FormDefinition? form = cachedForm.fold(
      onOk: (FormDefinition? f) => f,
      onErr: (_) => null,
    );

    emit(
      state.copyWith(
        loading: false,
        request: request,
        attempts: attempts,
        form: form,
      ),
    );
  }

  Future<void> retry() async {
    await _requests.retry(requestId);
    await load();
  }
}
