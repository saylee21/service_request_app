import '../../../../core/result.dart';
import '../../../form/domain/entities/form_definition.dart';
import '../entities/request_status.dart';
import '../entities/service_request.dart';
import '../entities/sync_attempt.dart';

/// Read/write access to saved requests for the UI.
abstract class RequestRepository {
  /// Validates, strips hidden/empty values, then saves the request and its
  /// outbox row in a single transaction. Also kicks off a sync attempt.
  Future<Result<ServiceRequest>> save({
    required FormDefinition form,
    required Map<String, Object?> values,
  });

  Future<Result<List<ServiceRequest>>> list({RequestStatus? filter});

  Future<Result<ServiceRequest?>> byId(String id);

  /// Moves a failed request back to pending and schedules a sync.
  Future<Result<void>> retry(String id);

  Future<Result<List<SyncAttempt>>> attempts(String id);

  /// Emits whenever the requests/outbox tables change.
  Stream<void> get changes;
}
