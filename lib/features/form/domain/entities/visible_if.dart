/// Conditional visibility rule: a field is shown only when another field has a
/// specific value, e.g. `{ "field": "priority", "equals": "High" }`.
class VisibleIf {
  const VisibleIf({required this.field, required this.equals});

  final String field;
  final Object? equals;

  factory VisibleIf.fromJson(Map<String, dynamic> json) =>
      VisibleIf(field: json['field'] as String, equals: json['equals']);

  Map<String, dynamic> toJson() => {'field': field, 'equals': equals};
}
