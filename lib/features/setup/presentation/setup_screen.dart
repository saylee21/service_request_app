import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';

/// Shown when the app was built without `--dart-define=API_BASE_URL=...`.
///
/// Fails loudly and usefully instead of silently pointing at the wrong server.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  static const String androidHint = 'http://10.0.2.2:3000';
  static const String iosHint = 'http://localhost:3000';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.settings_ethernet, size: 48),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'API base URL not configured',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Start the app with --dart-define=API_BASE_URL pointing at the '
                  'mock server:',
                ),
                const SizedBox(height: AppSpacing.md),
                const _CodeBlock(
                  'flutter run \\\n'
                  '  --dart-define=API_BASE_URL=$androidHint   # Android emulator\n'
                  '  --dart-define=API_BASE_URL=$iosHint  # iOS simulator',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Android emulators reach the host machine at $androidHint; '
                  'iOS simulators can use $iosHint.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
