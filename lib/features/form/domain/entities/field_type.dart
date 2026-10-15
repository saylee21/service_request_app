/// The field types this app knows how to render.
///
/// Anything the server sends that is not in this list maps to [unknown], which
/// renders a placeholder instead of crashing.
enum FieldType {
  text,
  number,
  dropdown,
  date,
  unknown;

  static FieldType parse(String raw) {
    switch (raw) {
      case 'text':
        return FieldType.text;
      case 'number':
        return FieldType.number;
      case 'dropdown':
        return FieldType.dropdown;
      case 'date':
        return FieldType.date;
      default:
        return FieldType.unknown;
    }
  }
}
