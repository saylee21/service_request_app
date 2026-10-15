import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../di/injector.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/entities/field_type.dart';
import '../../domain/entities/form_definition.dart';
import '../../domain/entities/form_field_def.dart';
import '../cubit/new_request_cubit.dart';
import '../widgets/field_factory.dart';

class NewRequestScreen extends StatelessWidget {
  const NewRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NewRequestCubit>(
      create: (_) => getIt<NewRequestCubit>()..load(),
      child: const _NewRequestView(),
    );
  }
}

class _NewRequestView extends StatefulWidget {
  const _NewRequestView();

  @override
  State<_NewRequestView> createState() => _NewRequestViewState();
}

class _NewRequestViewState extends State<_NewRequestView> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NewRequestCubit, NewRequestState>(
      listener: (BuildContext context, NewRequestState state) {
        if (state.isSaved) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request saved. Syncing in the background.'),
            ),
          );
        }
        if (state.submitError != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.submitError!)));
        }
      },
      builder: (BuildContext context, NewRequestState state) {
        final bool dirty = state.values.isNotEmpty && !state.isSaved;
        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) return;
            final NavigatorState navigator = Navigator.of(context);
            final bool? discard = await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) => AlertDialog(
                title: const Text('Discard request?'),
                content: const Text('Your changes will be lost.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            if (discard == true && navigator.mounted) navigator.pop();
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('New request')),
            body: _body(context, state),
            bottomNavigationBar: state.form == null
                ? null
                : _saveButton(context, state),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, NewRequestState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.form == null) {
      return _FormError(
        message: state.formError ?? 'Could not load the form.',
        onRetry: () => context.read<NewRequestCubit>().load(),
      );
    }

    final FormDefinition form = state.form!;
    final List<FormFieldDef> visible = form.fields
        .where((FormFieldDef f) => f.isVisible(state.values))
        .toList(growable: false);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(form.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Form version ${form.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.unknownFields.isNotEmpty) ...<Widget>[
              _UnknownNotice(count: state.unknownFields.length),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (final FormFieldDef field in visible) ...<Widget>[
              FieldFactory(
                field: field,
                value: state.values[field.key],
                errorText: state.errors[field.key],
                controller: _needsController(field)
                    ? _controllerFor(field.key)
                    : null,
                onChanged: (Object? value) =>
                    context.read<NewRequestCubit>().setValue(field.key, value),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _saveButton(BuildContext context, NewRequestState state) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: FilledButton.icon(
          onPressed: state.submitting
              ? null
              : () => context.read<NewRequestCubit>().submit(),
          icon: state.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(state.submitting ? 'Saving…' : 'Save request'),
        ),
      ),
    );
  }

  bool _needsController(FormFieldDef field) =>
      field.type == FieldType.text || field.type == FieldType.number;
}

class _UnknownNotice extends StatelessWidget {
  const _UnknownNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count field(s) use a type this app does not support yet. '
              'They will be skipped.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
