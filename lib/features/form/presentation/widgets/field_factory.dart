import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/entities/field_type.dart';
import '../../domain/entities/form_field_def.dart';

/// Builds the correct input widget for a [FormFieldDef].
///
/// Unknown types render a non-blocking placeholder so a new server field never
/// crashes the form or stops the user from submitting everything else.
class FieldFactory extends StatelessWidget {
  const FieldFactory({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.controller,
    this.enabled = true,
  });

  final FormFieldDef field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? errorText;
  final TextEditingController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case FieldType.text:
        return _textField(TextInputType.text);
      case FieldType.number:
        return _textField(
          const TextInputType.numberWithOptions(decimal: true, signed: false),
        );
      case FieldType.dropdown:
        return _dropdown(context);
      case FieldType.date:
        return _datePicker(context);
      case FieldType.unknown:
        return _UnknownFieldPlaceholder(field: field);
    }
  }

  Widget _textField(TextInputType keyboard) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboard,
    maxLength: field.maxLength,
    decoration: _decoration(),
    onChanged: onChanged,
  );

  Widget _dropdown(BuildContext context) {
    final String? current = value?.toString();
    final bool valid = current != null && field.options.contains(current);
    return DropdownButtonFormField<String>(
      initialValue: valid ? current : null,
      decoration: _decoration(),
      items: field.options
          .map(
            (String option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(growable: false),
      onChanged: enabled ? (String? v) => onChanged(v) : null,
    );
  }

  Widget _datePicker(BuildContext context) {
    final String current = value?.toString() ?? '';
    return InkWell(
      onTap: enabled ? () => _pickDate(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: _decoration().copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          current.isEmpty ? 'Select a date' : current,
          style: current.isEmpty
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initial = DateTime.tryParse(value?.toString() ?? '') ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      onChanged(DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  InputDecoration _decoration() => InputDecoration(
    labelText: field.required ? '${field.label} *' : field.label,
    helperText: field.helperText,
    errorText: errorText,
    alignLabelWithHint: true,
  );
}

class _UnknownFieldPlaceholder extends StatelessWidget {
  const _UnknownFieldPlaceholder({required this.field});

  final FormFieldDef field;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Unsupported field ${field.label}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.help_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Unsupported field: ${field.label}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This field type ("${field.rawType}") is not supported. '
                    'It will be skipped.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
