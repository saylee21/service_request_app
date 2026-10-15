import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../di/injector.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/entities/sync_attempt.dart';
import '../../domain/entities/sync_stats.dart';
import '../cubit/diagnostics_cubit.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiagnosticsCubit>(
      create: (_) => getIt<DiagnosticsCubit>()..load(),
      child: const _DiagnosticsView(),
    );
  }
}

class _DiagnosticsView extends StatelessWidget {
  const _DiagnosticsView();

  Future<void> _copyLogs(BuildContext context, DiagnosticsState state) async {
    await Clipboard.setData(ClipboardData(text: _logsText(state)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard.')));
  }

  String _logsText(DiagnosticsState state) {
    final SyncStats s = state.stats;
    final StringBuffer buffer = StringBuffer()
      ..writeln('Service Request App $AppConfig.appVersion')
      ..writeln('Database schema v${s.dbVersion}')
      ..writeln(
        'Outbox: ${s.outboxSize} '
        '(pending ${s.pending}, syncing ${s.syncing}, failed ${s.failed})',
      )
      ..writeln('Synced: ${s.synced}')
      ..writeln('Last success: ${s.lastSuccessAt?.toIso8601String() ?? '—'}')
      ..writeln('Last error: ${s.lastError ?? '—'}')
      ..writeln('Recent attempts:');
    for (final SyncAttempt a in state.attempts) {
      buffer.writeln(
        '  ${a.at.toIso8601String()} attempt ${a.attempt} ${a.result.wire}'
        '${a.httpStatus != null ? ' HTTP ${a.httpStatus}' : ''}'
        '${a.durationMs != null ? ' ${a.durationMs}ms' : ''}'
        '${a.message != null ? ' ${a.message}' : ''}',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiagnosticsCubit, DiagnosticsState>(
      builder: (BuildContext context, DiagnosticsState state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Diagnostics'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Copy logs',
                onPressed: state.loading
                    ? null
                    : () => _copyLogs(context, state),
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => context.read<DiagnosticsCubit>().load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, DiagnosticsState state) {
    final SyncStats stats = state.stats;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                _StatTile(label: 'Outbox', value: '${stats.outboxSize}'),
                _StatTile(label: 'Pending', value: '${stats.pending}'),
                _StatTile(label: 'Syncing', value: '${stats.syncing}'),
                _StatTile(label: 'Failed', value: '${stats.failed}'),
                _StatTile(label: 'Synced', value: '${stats.synced}'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _InfoRow(
              label: 'Last success',
              value: stats.lastSuccessAt == null
                  ? '—'
                  : DateFormat(
                      'd MMM yyyy, HH:mm:ss',
                    ).format(stats.lastSuccessAt!),
            ),
            _InfoRow(label: 'Last error', value: stats.lastError ?? '—'),
            _InfoRow(
              label: 'Last error at',
              value: stats.lastErrorAt == null
                  ? '—'
                  : DateFormat(
                      'd MMM yyyy, HH:mm:ss',
                    ).format(stats.lastErrorAt!),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'App version', value: AppConfig.appVersion),
            _InfoRow(label: 'Database', value: 'schema v${stats.dbVersion}'),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Recent attempts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.attempts.isEmpty)
              const Text('No sync attempts logged.')
            else
              for (final SyncAttempt attempt in state.attempts)
                _AttemptRow(attempt: attempt),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: 108,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
            width: 120,
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

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt});

  final SyncAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String when = DateFormat('d MMM, HH:mm:ss').format(attempt.at);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${attempt.result.label} · attempt ${attempt.attempt}',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            <String>[
              when,
              if (attempt.httpStatus != null) 'HTTP ${attempt.httpStatus}',
              if (attempt.durationMs != null) '${attempt.durationMs}ms',
              'req ${attempt.requestId.substring(0, 8)}…',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (attempt.message != null && attempt.message!.isNotEmpty)
            Text(attempt.message!, style: theme.textTheme.bodySmall),
          const Divider(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
