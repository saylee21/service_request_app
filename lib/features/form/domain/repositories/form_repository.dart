import '../../../../core/result.dart';
import '../entities/form_definition.dart';

/// Reads the form definition. Network first, cache fallback.
abstract class FormRepository {
  /// Returns the server form if reachable, otherwise the latest cached form.
  /// Fails only when the network is down *and* nothing is cached.
  Future<Result<FormDefinition>> getForm();

  /// The cached form for a specific id/version, if present. Used to render
  /// labels for a request saved under an older form version.
  Future<Result<FormDefinition?>> getCachedForm(String id, int version);
}
