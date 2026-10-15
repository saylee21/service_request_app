import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../di/injector.dart';
import '../../../../theme/app_spacing.dart';
import '../../../form/domain/entities/form_definition.dart';
import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_attempt.dart';
import '../cubit/request_detail_cubit.dart';
import '../widgets/status_chip.dart';

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RequestDetailCubit>(
      create: (_) => getIt<RequestDetailCubit>(param1: requestId)..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request')),
      body: BlocBuilder<RequestDetailCubit, RequestDetailState>(
        builder: (BuildContext context, RequestDetailState state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final ServiceRequest? request = state.request;
          if (request == null) {
            return Center(child: Text(state.error ?? 'Request not found.'));
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          request.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      StatusChip(status: request.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _MetaRow(
                    label: 'Created',
                    value: DateFormat(
                      'd MMM yyyy, HH:mm',
                    ).format(request.createdAt),
                  ),
                  _MetaRow(
                    label: 'Form',
                    value: '${request.formId} v${request.formVersion}',
                  ),
                  if (request.priority != null)
                    _MetaRow(label: 'Priority', value: request.priority!),
                  _MetaRow(label: 'Attempts', value: '${request.attempts}'),
                  if (request.lastAttemptAt != null)
                    _MetaRow(
                      label: 'Last attempt',
                      value: DateFormat(
                        'd MMM yyyy, HH:mm:ss',
                      ).format(request.lastAttemptAt!),
                    ),
                  if (request.syncedAt != null)
                    _MetaRow(
                      label: 'Synced',
                      value: DateFormat(
                        'd MMM yyyy, HH:mm',
                      ).format(request.syncedAt!),
                    ),
                  if (request.serverMessage != null &&
                      request.serverMessage!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _MessageBox(
                      message: request.serverMessage!,
                      isError: request.status == RequestStatus.failed,
                    ),
                  ],
                  if (request.status == RequestStatus.failed) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () =>
                          context.read<RequestDetailCubit>().retry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry now'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _SectionTitle('Submitted values'),
                  _ValuesCard(request: request, form: state.form),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionTitle('Sync timeline'),
                  if (state.attempts.isEmpty)
                    Text(
                      request.status == RequestStatus.synced
                          ? 'Synced on the first attempt.'
                          : 'No attempts recorded yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    for (final SyncAttempt attempt in state.attempts)
                      _AttemptTile(attempt: attempt),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: isError
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuesCard extends StatelessWidget {
  const _ValuesCard({required this.request, required this.form});

  final ServiceRequest request;
  final FormDefinition? form;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (request.data.isEmpty) {
      return Text('No values.', style: theme.textTheme.bodyMedium);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final MapEntry<String, Object?> entry
                in request.data.entries) ...<Widget>[
              _MetaRow(
                label: form?.fieldByKey(entry.key)?.label ?? entry.key,
                value: entry.value?.toString() ?? '—',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt});

  final SyncAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (IconData icon, Color color) = switch (attempt.result) {
      SyncResult.success => (
        Icons.check_circle_outline,
        theme.colorScheme.primary,
      ),
      SyncResult.duplicate => (
        Icons.content_copy_outlined,
        theme.colorScheme.secondary,
      ),
      SyncResult.transientFailure => (
        Icons.schedule,
        theme.colorScheme.tertiary,
      ),
      SyncResult.permanentFailure => (
        Icons.error_outline,
        theme.colorScheme.error,
      ),
    };
    final String when = DateFormat('d MMM, HH:mm:ss').format(attempt.at);
    final String detail = <String>[
      'attempt ${attempt.attempt}',
      if (attempt.httpStatus != null) 'HTTP ${attempt.httpStatus}',
      if (attempt.durationMs != null) '${attempt.durationMs}ms',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(attempt.result.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$when · $detail'),
          if (attempt.message != null && attempt.message!.isNotEmpty)
            Text(attempt.message!),
        ],
      ),
      isThreeLine: attempt.message?.isNotEmpty ?? false,
    );
  }
}
