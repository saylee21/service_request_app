import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/requests/domain/services/request_summary_extractor.dart';

void main() {
  const RequestSummaryExtractor extractor = RequestSummaryExtractor();

  test('prefers an explicit title', () {
    expect(
      extractor.titleFor(<String, Object?>{'title': 'Leaking tap', 'x': 'y'}),
      'Leaking tap',
    );
  });

  test('falls back to the first non-empty text value', () {
    expect(
      extractor.titleFor(<String, Object?>{'note': '  ', 'other': 'Hello'}),
      'Hello',
    );
  });

  test('uses a stable fallback when there is nothing to show', () {
    expect(
      extractor.titleFor(<String, Object?>{}),
      RequestSummaryExtractor.fallbackTitle,
    );
  });

  test('reads a trimmed priority or null', () {
    expect(
      extractor.priorityFor(<String, Object?>{'priority': ' High '}),
      'High',
    );
    expect(extractor.priorityFor(<String, Object?>{'priority': '   '}), isNull);
    expect(extractor.priorityFor(<String, Object?>{}), isNull);
  });
}
