import 'field_type.dart';
import 'visible_if.dart';

/// A single field in a server-driven form.
///
/// [rawType] keeps the original server string so unknown types can be logged
/// and reported without losing information.
class FormFieldDef {
  const FormFieldDef({
    required this.key,
    required this.rawType,
    required this.type,
    required this.label,
    this.required = false,
    this.maxLength,
    this.min,
    this.max,
    this.options = const <String>[],
    this.visibleIf,
    this.helperText,
  });

  final String key;
  final String rawType;
  final FieldType type;
  final String label;
  final bool required;
  final int? maxLength;
  final num? min;
  final num? max;
  final List<String> options;
  final VisibleIf? visibleIf;
  final String? helperText;

  bool get isKnown => type != FieldType.unknown;

  factory FormFieldDef.fromJson(Map<String, dynamic> json) {
    final String raw = (json['type'] ?? '').toString();
    return FormFieldDef(
      key: json['key'] as String,
      rawType: raw,
      type: FieldType.parse(raw),
      label: (json['label'] ?? json['key']).toString(),
      required: json['required'] == true,
      maxLength: (json['maxLength'] as num?)?.toInt(),
      min: json['min'] as num?,
      max: json['max'] as num?,
      options:
          (json['options'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      visibleIf: json['visibleIf'] is Map<String, dynamic>
          ? VisibleIf.fromJson(json['visibleIf'] as Map<String, dynamic>)
          : null,
      helperText: json['helperText'] as String?,
    );
  }

  /// True when this field should be shown for the given [values].
  bool isVisible(Map<String, Object?> values) {
    final VisibleIf? rule = visibleIf;
    if (rule == null) return true;
    return normalizeValue(values[rule.field]) == normalizeValue(rule.equals);
  }
}

/// Compares values leniently so `"5"` and `5`, or `"High"` and `"High"`, match.
Object? normalizeValue(Object? value) {
  if (value == null) return null;
  if (value is num) return value;
  final String text = value.toString();
  return num.tryParse(text) ?? text;
}
