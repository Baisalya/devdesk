import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';

enum RateUsAction { rateNow, remindLater, dontShowAgain }

/// A compact, responsive rating prompt that follows the app's Material theme.
class RateUsDialog extends StatelessWidget {
  final String primaryActionLabel;
  final String destinationDescription;

  const RateUsDialog({
    super.key,
    required this.primaryActionLabel,
    required this.destinationDescription,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.star_rounded,
        size: 48,
        color: scheme.tertiary,
      ),
      title: const Text(
        'Enjoying DevDesk?',
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (_) => Icon(
                    Icons.star_rounded,
                    color: scheme.tertiary,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'A quick rating helps other developers discover DevDesk and '
              'supports future improvements.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              destinationDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  RateUsAction.rateNow,
                ),
                icon: const Icon(Icons.open_in_new),
                label: Text(primaryActionLabel),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(
                  RateUsAction.remindLater,
                ),
                child: const Text('Maybe later'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                RateUsAction.dontShowAgain,
              ),
              child: const Text("Don't ask again for this version"),
            ),
          ],
        ),
      ),
    );
  }
}
