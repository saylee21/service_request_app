import '../../../../core/result.dart';
import '../entities/form_definition.dart';
import '../repositories/form_repository.dart';

/// Thin use case the presentation layer calls. Keeps cubits independent of the
/// repository implementation.
class GetFormDefinition {
  const GetFormDefinition(this._repository);

  final FormRepository _repository;

  Future<Result<FormDefinition>> call({bool forceRefresh = false}) =>
      _repository.getForm();
}
