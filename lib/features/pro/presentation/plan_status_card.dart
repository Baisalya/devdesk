import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../domain/feature_access.dart';
import '../provider/billing_provider.dart';
import '../provider/entitlement_provider.dart';

class PlanStatusCard extends ConsumerWidget {
  const PlanStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementProvider);
    final billing = ref.watch(billingProvider);
    final config = ref.watch(commerceConfigProvider);
    final freeCapabilities = AppCapability.values
        .where((capability) => capability.includedInFree)
        .toList();
    final futurePro = AppCapability.values
        .where((capability) => !capability.includedInFree)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppBadge(
              label: entitlement.proActive ? 'Pro active' : 'Free plan',
              icon:
                  entitlement.proActive ? Icons.workspace_premium : Icons.code,
            ),
            if (!config.enabled)
              const AppBadge(
                label: 'Purchases disabled',
                icon: Icons.lock_outline,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Every feature already in DevDesk remains free.',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(freeCapabilities.map((item) => item.label).join(' • ')),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Future Pro — not for sale yet',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          futurePro.map((item) => item.label).join(' • '),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          config.enabled
              ? 'Store availability: ${billing.status.name}'
              : 'No payment is requested or collected in this build.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (config.enabled && billing.status == BillingStatus.ready) ...[
          const SizedBox(height: AppSpacing.md),
          for (final product in billing.products)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: FilledButton(
                onPressed: () =>
                    ref.read(billingProvider.notifier).purchase(product),
                child: Text('${product.title} — ${product.displayPrice}'),
              ),
            ),
          TextButton(
            onPressed: () => ref.read(billingProvider.notifier).restore(),
            child: const Text('Restore purchases'),
          ),
        ],
      ],
    );
  }
}
