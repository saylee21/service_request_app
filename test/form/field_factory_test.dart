import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_request_app/features/form/domain/entities/form_field_def.dart';
import 'package:service_request_app/features/form/presentation/widgets/field_factory.dart';

FormFieldDef field(Map<String, dynamic> json) => FormFieldDef.fromJson(json);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders a text field with a required marker', (tester) async {
    await tester.pumpWidget(
      wrap(
        FieldFactory(
          field: field(<String, dynamic>{
            'key': 'title',
            'label': 'Title',
            'type': 'text',
            'required': true,
          }),
          value: null,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Title *'), findsOneWidget);
  });

  testWidgets('renders a dropdown with its options', (tester) async {
    await tester.pumpWidget(
      wrap(
        FieldFactory(
          field: field(<String, dynamic>{
            'key': 'priority',
            'label': 'Priority',
            'type': 'dropdown',
            'options': <String>['Low', 'High'],
          }),
          value: 'High',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('High'), findsWidgets);
  });

  testWidgets('renders a placeholder for an unsupported field type', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        FieldFactory(
          field: field(<String, dynamic>{
            'key': 'signature',
            'label': 'Signature',
            'type': 'signature',
          }),
          value: null,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.textContaining('Unsupported field'), findsOneWidget);
    expect(find.textContaining('signature'), findsWidgets);
    // Never blocks the rest of the form.
    expect(find.byType(TextField), findsNothing);
  });
}
