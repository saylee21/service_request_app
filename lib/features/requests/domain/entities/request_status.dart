/// Lifecycle of a saved request. Stored as text in the database.
enum RequestStatus {
  pending,
  syncing,
  failed,
  synced;

  static RequestStatus parse(String? raw) {
    switch (raw) {
      case 'pending':
        return RequestStatus.pending;
      case 'syncing':
        return RequestStatus.syncing;
      case 'failed':
        return RequestStatus.failed;
      case 'synced':
        return RequestStatus.synced;
      default:
        return RequestStatus.pending;
    }
  }

  String get label => switch (this) {
    RequestStatus.pending => 'Pending',
    RequestStatus.syncing => 'Syncing',
    RequestStatus.failed => 'Failed',
    RequestStatus.synced => 'Synced',
  };
}
