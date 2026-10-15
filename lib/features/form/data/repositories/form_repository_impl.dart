import '../../../../core/app_logger.dart';
import '../../../../core/result.dart';
import '../../domain/entities/form_definition.dart';
import '../../domain/entities/form_field_def.dart';
import '../../domain/repositories/form_repository.dart';
import '../datasources/form_local_data_source.dart';
import '../datasources/form_remote_data_source.dart';

/// Network-first with cache fallback. A cached form is a valid result even when
/// the network is down; only a cold cache with no network is an error.
class FormRepositoryImpl implements FormRepository {
  FormRepositoryImpl({
    required FormRemoteDataSource remote,
    required FormLocalDataSource local,
  }) : _remote = remote,
       _local = local;

  final FormRemoteDataSource _remote;
  final FormLocalDataSource _local;

  @override
  Future<Result<FormDefinition>> getForm() async {
    try {
      final FormDefinition form = await _remote.fetch();
      await _local.upsert(form);
      _logUnknownTypes(form);
      return Ok(form);
    } on AppException catch (error) {
      final FormDefinition? cached = await _local.latest();
      if (cached != null) {
        AppLogger.d('Form served from cache (network error: ${error.message})');
        return Ok(cached);
      }
      return Err(error);
    }
  }

  @override
  Future<Result<FormDefinition?>> getCachedForm(String id, int version) async =>
      Ok(await _local.byIdVersion(id, version));

  void _logUnknownTypes(FormDefinition form) {
    for (final FormFieldDef field in form.fields) {
      if (!field.isKnown) {
        AppLogger.w(
          'Unknown field type "${field.rawType}" for key "${field.key}" '
          '(id=${form.id} v${form.version})',
        );
      }
    }
  }
}
