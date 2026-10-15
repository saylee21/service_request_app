import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_logger.dart';
import '../../../requests/domain/entities/service_request.dart';
import '../../../requests/domain/usecases/save_request.dart';
import '../../domain/entities/form_definition.dart';
import '../../domain/services/form_validator.dart';
import '../../domain/usecases/get_form_definition.dart';

class NewRequestState extends Equatable {
  const NewRequestState({
    this.loading = true,
    this.form,
    this.values = const <String, Object?>{},
    this.errors = const <String, String>{},
    this.submitting = false,
    this.submitError,
    this.formError,
    this.savedRequestId,
    this.unknownFields = const <String>[],
  });

  final bool loading;
  final FormDefinition? form;
  final Map<String, Object?> values;
  final Map<String, String> errors;
  final bool submitting;
  final String? submitError;

  /// Set when the form itself could not be loaded and nothing was cached.
  final String? formError;

  final String? savedRequestId;

  /// Keys of fields whose server type this app does not understand.
  final List<String> unknownFields;

  bool get isSaved => savedRequestId != null;

  NewRequestState copyWith({
    bool? loading,
    FormDefinition? form,
    Map<String, Object?>? values,
    Map<String, String>? errors,
    bool? submitting,
    String? submitError,
    String? formError,
    String? savedRequestId,
    List<String>? unknownFields,
    bool clearSubmitError = false,
    bool clearFormError = false,
  }) => NewRequestState(
    loading: loading ?? this.loading,
    form: form ?? this.form,
    values: values ?? this.values,
    errors: errors ?? this.errors,
    submitting: submitting ?? this.submitting,
    submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    formError: clearFormError ? null : (formError ?? this.formError),
    savedRequestId: savedRequestId ?? this.savedRequestId,
    unknownFields: unknownFields ?? this.unknownFields,
  );

  @override
  List<Object?> get props => <Object?>[
    loading,
    form,
    values,
    errors,
    submitting,
    submitError,
    formError,
    savedRequestId,
    unknownFields,
  ];
}

/// Drives the server-driven "new request" form.
class NewRequestCubit extends Cubit<NewRequestState> {
  NewRequestCubit({
    required GetFormDefinition getForm,
    required SaveRequest saveRequest,
    required FormValidator validator,
  }) : _getForm = getForm,
       _saveRequest = saveRequest,
       _validator = validator,
       super(const NewRequestState());

  final GetFormDefinition _getForm;
  final SaveRequest _saveRequest;
  final FormValidator _validator;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearFormError: true));
    final result = await _getForm();
    result.fold(
      onOk: (FormDefinition form) {
        final List<String> unknown = form.fields
            .where((f) => !f.isKnown)
            .map((f) => f.key)
            .toList(growable: false);
        emit(
          state.copyWith(loading: false, form: form, unknownFields: unknown),
        );
      },
      onErr: (Object error) {
        AppLogger.w('Form load failed: $error');
        emit(state.copyWith(loading: false, formError: error.toString()));
      },
    );
  }

  void setValue(String key, Object? value) {
    final Map<String, Object?> values = Map<String, Object?>.of(state.values);
    values[key] = value;
    final FormDefinition? form = state.form;
    // Recompute visibility-driven errors against the new values.
    final Map<String, String> errors = form == null
        ? state.errors
        : _validator.validate(form, values);
    emit(
      state.copyWith(values: values, errors: errors, clearSubmitError: true),
    );
  }

  Future<void> submit() async {
    final FormDefinition? form = state.form;
    if (form == null) return;

    final Map<String, String> errors = _validator.validate(form, state.values);
    if (errors.isNotEmpty) {
      emit(state.copyWith(errors: errors));
      return;
    }

    emit(
      state.copyWith(submitting: true, clearSubmitError: true, errors: errors),
    );
    final result = await _saveRequest(form: form, values: state.values);
    result.fold(
      onOk: (ServiceRequest request) {
        emit(state.copyWith(submitting: false, savedRequestId: request.id));
      },
      onErr: (Object error) {
        emit(state.copyWith(submitting: false, submitError: error.toString()));
      },
    );
  }
}
