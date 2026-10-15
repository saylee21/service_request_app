import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/entities/request_status.dart';
import '../../domain/entities/service_request.dart';
import 'status_chip.dart';

/// A single row in the requests list.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.onRetry,
  });

  final ServiceRequest request;
  final VoidCallback onTap;

  /// Shown as a Retry action when the request is [RequestStatus.failed].
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String when = DateFormat('d MMM, HH:mm').format(request.createdAt);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      request.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(status: request.status, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  if (request.priority != null && request.priority!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.flag_outlined,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.priority!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  Icon(
                    Icons.schedule,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(when, style: theme.textTheme.bodySmall),
                ],
              ),
              if (request.status == RequestStatus.failed &&
                  (request.serverMessage?.isNotEmpty ?? false)) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  request.serverMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (request.status == RequestStatus.failed &&
                  onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
