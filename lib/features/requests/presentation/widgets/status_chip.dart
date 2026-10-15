import 'package:flutter/material.dart';

import '../../domain/entities/request_status.dart';

/// Colour + icon + label badge for a request status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final RequestStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (
      Color background,
      Color foreground,
      IconData icon,
    ) = switch (status) {
      RequestStatus.synced => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.check_circle_outline,
      ),
      RequestStatus.pending => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.schedule,
      ),
      RequestStatus.syncing => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.sync,
      ),
      RequestStatus.failed => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
    };

    return Semantics(
      label: 'Status: ${status.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: compact ? 14 : 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
