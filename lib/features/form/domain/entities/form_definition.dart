import 'form_field_def.dart';

/// A form as defined by the server.
///
/// The raw JSON is kept as-is so that any properties this app does not yet know
/// about survive a cache round-trip (important for forward compatibility).
class FormDefinition {
  const FormDefinition({
    required this.id,
    required this.version,
    required this.title,
    required this.fields,
    required this.rawJson,
  });

  final String id;
  final int version;
  final String title;
  final List<FormFieldDef> fields;
  final Map<String, dynamic> rawJson;

  factory FormDefinition.fromJson(Map<String, dynamic> json) {
    final List<dynamic> fieldsJson =
        (json['fields'] as List<dynamic>?) ?? const <dynamic>[];
    return FormDefinition(
      id: (json['id'] ?? 'request-form').toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      title: (json['title'] ?? 'Form').toString(),
      fields: fieldsJson
          .whereType<Map<String, dynamic>>()
          .map(FormFieldDef.fromJson)
          .toList(growable: false),
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => rawJson;

  FormFieldDef? fieldByKey(String key) {
    for (final FormFieldDef f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }
}
