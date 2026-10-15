import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../form/presentation/screens/new_request_screen.dart';
import '../../../../di/injector.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/entities/sync_stats.dart';
import '../cubit/requests_cubit.dart';
import '../widgets/offline_banner.dart';
import '../widgets/request_card.dart';
import 'diagnostics_screen.dart';
import 'request_detail_screen.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RequestsCubit>(
      create: (_) => getIt<RequestsCubit>()..init(),
      child: const _RequestsView(),
    );
  }
}

class _RequestsView extends StatelessWidget {
  const _RequestsView();

  Future<void> _openNewRequest(BuildContext context) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NewRequestScreen()),
    );
    if (saved == true && context.mounted) {
      await context.read<RequestsCubit>().refresh();
    }
  }

  Future<void> _openDetail(BuildContext context, ServiceRequest request) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailScreen(requestId: request.id),
      ),
    );
    if (context.mounted) await context.read<RequestsCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestsCubit, RequestsState>(
      builder: (BuildContext context, RequestsState state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Service requests'),
            actions: <Widget>[
              if (state.syncing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Sync now',
                  onPressed: () => context.read<RequestsCubit>().syncNow(),
                  icon: Badge(
                    isLabelVisible: state.stats.outboxSize > 0,
                    label: Text('${state.stats.outboxSize}'),
                    child: const Icon(Icons.sync),
                  ),
                ),
              IconButton(
                tooltip: 'Diagnostics',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const DiagnosticsScreen(),
                  ),
                ),
                icon: const Icon(Icons.monitor_heart_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openNewRequest(context),
            icon: const Icon(Icons.add),
            label: const Text('New request'),
          ),
          body: Column(
            children: <Widget>[
              if (!state.online) const OfflineBanner(),
              _FilterBar(state: state),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => context.read<RequestsCubit>().syncNow(),
                  child: _list(context, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, RequestsState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.requests.isEmpty && state.error != null) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => context.read<RequestsCubit>().refresh(),
      );
    }
    if (state.requests.isEmpty) {
      return _EmptyState(filter: state.filter);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl * 2,
          ),
          itemCount: state.requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int index) {
            final ServiceRequest request = state.requests[index];
            return RequestCard(
              request: request,
              onTap: () => _openDetail(context, request),
              onRetry: () => context.read<RequestsCubit>().retry(request.id),
            );
          },
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state});

  final RequestsState state;

  @override
  Widget build(BuildContext context) {
    final SyncStats stats = state.stats;
    final List<(String, RequestStatus?, int)> filters =
        <(String, RequestStatus?, int)>[
          ('All', null, stats.total),
          ('Pending', RequestStatus.pending, stats.pending),
          ('Syncing', RequestStatus.syncing, stats.syncing),
          ('Failed', RequestStatus.failed, stats.failed),
          ('Synced', RequestStatus.synced, stats.synced),
        ];

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: <Widget>[
          for (final (String label, RequestStatus? status, int count)
              in filters)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: Text('$label ($count)'),
                selected: state.filter == status,
                onSelected: (_) =>
                    context.read<RequestsCubit>().setFilter(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filter});

  final RequestStatus? filter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: <Widget>[
        const SizedBox(height: AppSpacing.xxl),
        Icon(
          Icons.inbox_outlined,
          size: 56,
          color: Theme.of(context).hintColor,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          filter == null
              ? 'No requests yet'
              : 'No ${filter!.label.toLowerCase()} requests',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          filter == null
              ? 'Tap “New request” to create your first one.'
              : 'Try another filter.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: <Widget>[
        const SizedBox(height: AppSpacing.xxl),
        Icon(
          Icons.error_outline,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Could not load requests',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
