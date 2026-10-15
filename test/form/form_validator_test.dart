import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/form/domain/entities/field_type.dart';
import 'package:service_request_app/features/form/domain/entities/form_definition.dart';
import 'package:service_request_app/features/form/domain/entities/form_field_def.dart';
import 'package:service_request_app/features/form/domain/services/form_validator.dart';

FormDefinition formWith(List<Map<String, dynamic>> fields) => FormDefinition(
  id: 'request-form',
  version: 2,
  title: 'Request',
  fields: fields.map(FormFieldDef.fromJson).toList(),
  rawJson: const <String, dynamic>{},
);

void main() {
  const FormValidator validator = FormValidator();

  group('FieldType.parse', () {
    test('maps known types and defaults to unknown', () {
      expect(FieldType.parse('text'), FieldType.text);
      expect(FieldType.parse('number'), FieldType.number);
      expect(FieldType.parse('dropdown'), FieldType.dropdown);
      expect(FieldType.parse('date'), FieldType.date);
      expect(FieldType.parse('checkbox'), FieldType.unknown);
      expect(FieldType.parse('totally-new'), FieldType.unknown);
    });
  });

  group('FormValidator', () {
    test('flags a missing required field', () {
      final FormDefinition form = formWith(<Map<String, dynamic>>[
        <String, dynamic>{
          'key': 'title',
          'label': 'Title',
          'type': 'text',
          'required': true,
        },
      ]);
      final Map<String, String> errors = validator.validate(
        form,
        <String, Object?>{},
      );
      expect(errors['title'], 'Title is required');
    });

    test('enforces numeric min and max', () {
      final FormDefinition form = formWith(<Map<String, dynamic>>[
        <String, dynamic>{
          'key': 'cost',
          'label': 'Cost',
          'type': 'number',
          'min': 1,
          'max': 100,
        },
      ]);
      expect(
        validator.validate(form, <String, Object?>{'cost': '0'})['cost'],
        'Cost must be at least 1',
      );
      expect(
        validator.validate(form, <String, Object?>{'cost': '101'})['cost'],
        'Cost must be at most 100',
      );
      expect(
        validator.validate(form, <String, Object?>{'cost': '50'}),
        isEmpty,
      );
      expect(
        validator.validate(form, <String, Object?>{'cost': 'abc'})['cost'],
        'Cost must be a number',
      );
    });

    test('enforces maxLength on text', () {
      final FormDefinition form = formWith(<Map<String, dynamic>>[
        <String, dynamic>{
          'key': 'title',
          'label': 'Title',
          'type': 'text',
          'maxLength': 5,
        },
      ]);
      expect(
        validator.validate(form, <String, Object?>{
          'title': 'toolong',
        })['title'],
        'Title must be at most 5 characters',
      );
      expect(
        validator.validate(form, <String, Object?>{'title': 'ok'}),
        isEmpty,
      );
    });

    test('skips validation for hidden fields', () {
      final FormDefinition form = formWith(<Map<String, dynamic>>[
        <String, dynamic>{
          'key': 'priority',
          'label': 'Priority',
          'type': 'dropdown',
          'options': <String>['Low', 'High'],
        },
        <String, dynamic>{
          'key': 'reason',
          'label': 'Reason',
          'type': 'text',
          'required': true,
          'visibleIf': <String, dynamic>{'field': 'priority', 'equals': 'High'},
        },
      ]);
      // Hidden -> no error even though required.
      expect(
        validator.validate(form, <String, Object?>{'priority': 'Low'}),
        isEmpty,
      );
      // Visible -> required triggers.
      expect(
        validator.validate(form, <String, Object?>{
          'priority': 'High',
        })['reason'],
        'Reason is required',
      );
    });

    test('compares visibleIf values leniently ("5" vs 5)', () {
      final FormDefinition form = formWith(<Map<String, dynamic>>[
        <String, dynamic>{'key': 'count', 'label': 'Count', 'type': 'number'},
        <String, dynamic>{
          'key': 'extra',
          'label': 'Extra',
          'type': 'text',
          'required': true,
          'visibleIf': <String, dynamic>{'field': 'count', 'equals': 5},
        },
      ]);
      expect(
        validator.validate(form, <String, Object?>{'count': '5'})['extra'],
        'Extra is required',
      );
      expect(
        validator.validate(form, <String, Object?>{'count': '4'}),
        isEmpty,
      );
    });

    test('does not crash on an unknown field type', () {
      final FormDefinition form = formWith(<Map<String, dynamic>>[
        <String, dynamic>{
          'key': 'signature',
          'label': 'Signature',
          'type': 'signature',
        },
      ]);
      expect(
        validator.validate(form, <String, Object?>{'signature': 'x'}),
        isEmpty,
      );
    });

    test('stripHidden drops hidden and empty values', () {
      final FormDefinition form = formWith(<Map<String, dynamic>>[
        <String, dynamic>{'key': 'title', 'label': 'Title', 'type': 'text'},
        <String, dynamic>{'key': 'note', 'label': 'Note', 'type': 'text'},
        <String, dynamic>{
          'key': 'reason',
          'label': 'Reason',
          'type': 'text',
          'visibleIf': <String, dynamic>{
            'field': 'title',
            'equals': 'something-else',
          },
        },
      ]);
      final Map<String, Object?> clean = validator.stripHidden(
        form,
        <String, Object?>{'title': 'x', 'note': '   ', 'reason': 'hidden-here'},
      );
      expect(clean, <String, Object?>{'title': 'x'});
    });
  });
}
