/// Derives a short, human-friendly summary for a request.
///
/// Values may be typed by the user, so this handles missing/blank data and
/// picks a sensible fallback rather than throwing. No field values are logged.
class RequestSummaryExtractor {
  const RequestSummaryExtractor();

  static const String fallbackTitle = 'Service request';

  String titleFor(Map<String, Object?> values) {
    final Object? named = values['title'];
    if (named != null && named.toString().trim().isNotEmpty) {
      return named.toString().trim();
    }
    for (final Object? value in values.values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallbackTitle;
  }

  String? priorityFor(Map<String, Object?> values) {
    final String? value = values['priority']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
