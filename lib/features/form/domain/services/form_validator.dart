import '../entities/field_type.dart';
import '../entities/form_definition.dart';
import '../entities/form_field_def.dart';

/// Pure validation and visibility helpers. No IO, no Flutter, easy to test.
class FormValidator {
  const FormValidator();

  /// Returns a map of `field.key -> user-readable error` for visible fields.
  Map<String, String> validate(
    FormDefinition form,
    Map<String, Object?> values,
  ) {
    final Map<String, String> errors = <String, String>{};

    for (final FormFieldDef field in form.fields) {
      if (!field.isVisible(values)) continue; // hidden fields are not validated

      final Object? value = values[field.key];
      final bool empty =
          value == null || (value is String && value.trim().isEmpty);

      if (field.required && empty) {
        errors[field.key] = '${field.label} is required';
        continue;
      }
      if (empty) continue;

      switch (field.type) {
        case FieldType.number:
          final num? parsed = value is num
              ? value
              : num.tryParse(value.toString());
          if (parsed == null) {
            errors[field.key] = '${field.label} must be a number';
          } else if (field.min != null && parsed < field.min!) {
            errors[field.key] =
                '${field.label} must be at least ${_format(field.min!)}';
          } else if (field.max != null && parsed > field.max!) {
            errors[field.key] =
                '${field.label} must be at most ${_format(field.max!)}';
          }
        case FieldType.text:
          if (field.maxLength != null &&
              value is String &&
              value.length > field.maxLength!) {
            errors[field.key] =
                '${field.label} must be at most ${field.maxLength} characters';
          }
        case FieldType.dropdown:
        case FieldType.date:
        case FieldType.unknown:
          break;
      }
    }

    return errors;
  }

  /// Fields that should currently be shown.
  List<FormFieldDef> visibleFields(
    FormDefinition form,
    Map<String, Object?> values,
  ) => form.fields.where((FormFieldDef f) => f.isVisible(values)).toList();

  /// Drops hidden and empty values before saving/submitting, so a hidden field
  /// never travels to the server.
  Map<String, Object?> stripHidden(
    FormDefinition form,
    Map<String, Object?> values,
  ) {
    final Map<String, Object?> out = <String, Object?>{};
    for (final FormFieldDef field in form.fields) {
      if (!field.isVisible(values)) continue;
      final Object? value = values[field.key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      out[field.key] = value;
    }
    return out;
  }

  String _format(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
