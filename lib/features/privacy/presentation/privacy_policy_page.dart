import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/privacy_policy.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const PrivacyPolicyView(),
    );
  }
}

class PrivacyPolicyView extends StatelessWidget {
  final Widget? footer;
  final bool selectable;

  const PrivacyPolicyView({
    super.key,
    this.footer,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = ListView(
      key: const Key('privacy-policy-scroll-view'),
      padding: AppSpacing.page(context),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 34,
                        color: colors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'DevDesk Privacy Policy',
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Effective ${DevDeskPrivacyPolicy.effectiveDate}  •  '
                        'Version ${DevDeskPrivacyPolicy.version}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Offline-first by design, with clear disclosure for every user-initiated network action.',
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final section in DevDeskPrivacyPolicy.sections) ...[
                  _PolicySection(section: section),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  footer!,
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return selectable ? SelectionArea(child: content) : content;
  }
}

class _PolicySection extends StatelessWidget {
  final PrivacyPolicySection section;

  const _PolicySection({required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      filled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: textTheme.titleLarge),
          for (final paragraph in section.paragraphs) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              paragraph,
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          if (section.bullets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final bullet in section.bullets)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        bullet,
                        style: textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
