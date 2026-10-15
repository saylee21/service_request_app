import '../../../../core/result.dart';
import '../../../form/domain/entities/form_definition.dart';
import '../entities/service_request.dart';
import '../repositories/request_repository.dart';

/// Persists a request (offline-first) and returns the saved entity.
class SaveRequest {
  const SaveRequest(this._repository);

  final RequestRepository _repository;

  Future<Result<ServiceRequest>> call({
    required FormDefinition form,
    required Map<String, Object?> values,
  }) => _repository.save(form: form, values: values);
}
