import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/privacy_policy.dart';
import '../provider/privacy_acceptance_provider.dart';
import 'privacy_policy_page.dart';

class PrivacyAcceptanceGate extends ConsumerStatefulWidget {
  final Widget child;

  const PrivacyAcceptanceGate({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<PrivacyAcceptanceGate> createState() =>
      _PrivacyAcceptanceGateState();
}

class _PrivacyAcceptanceGateState extends ConsumerState<PrivacyAcceptanceGate> {
  bool _acknowledged = false;
  bool _showFullPolicy = false;

  @override
  Widget build(BuildContext context) {
    final acceptance = ref.watch(privacyAcceptanceProvider);
    if (acceptance.isAccepted) return widget.child;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showFullPolicy) {
          setState(() => _showFullPolicy = false);
        }
      },
      child: _showFullPolicy
          ? Scaffold(
              appBar: AppBar(
                leading: Semantics(
                  label: 'Back to acceptance',
                  button: true,
                  excludeSemantics: true,
                  child: IconButton(
                    key: const Key('privacy-policy-back'),
                    onPressed: () => setState(() => _showFullPolicy = false),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                title: const Text('Privacy Policy'),
              ),
              // MaterialApp.builder sits outside the root Navigator overlay.
              // Selection remains available on the Settings policy page, which
              // is routed inside that overlay.
              body: const PrivacyPolicyView(selectable: false),
            )
          : _buildGate(context, acceptance),
    );
  }

  Widget _buildGate(
    BuildContext context,
    PrivacyAcceptanceState acceptance,
  ) {
    if (acceptance.status == PrivacyAcceptanceStatus.loading) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Loading privacy policy',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('privacy-acceptance-scroll-view'),
          padding: AppSpacing.page(context),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      'Privacy before you continue',
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Please review how DevDesk stores local work and when it connects to services you choose.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: colors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'DevDesk Privacy Policy',
                                style: textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Effective ${DevDeskPrivacyPolicy.effectiveDate}  •  '
                          'Version ${DevDeskPrivacyPolicy.version}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final item in DevDeskPrivacyPolicy.gateSummary)
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
                                    item,
                                    style: textTheme.bodyMedium
                                        ?.copyWith(height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          key: const Key('read-full-privacy-policy'),
                          onPressed: () =>
                              setState(() => _showFullPolicy = true),
                          icon: const Icon(Icons.article_outlined),
                          label: const Text('Read the full privacy policy'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: CheckboxListTile(
                      key: const Key('privacy-acceptance-checkbox'),
                      value: _acknowledged,
                      enabled: !acceptance.isSaving,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      title: const Text(
                        'I have read and accept the DevDesk Privacy Policy.',
                      ),
                      subtitle: const Text(
                        'Acceptance is saved only on this device.',
                      ),
                      onChanged: (value) {
                        setState(() => _acknowledged = value ?? false);
                      },
                    ),
                  ),
                  if (acceptance.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        acceptance.errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    key: const Key('accept-privacy-policy'),
                    onPressed: !_acknowledged || acceptance.isSaving
                        ? null
                        : () => ref
                            .read(privacyAcceptanceProvider.notifier)
                            .accept(),
                    icon: acceptance.isSaving
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      acceptance.isSaving
                          ? 'Saving acceptance…'
                          : 'Accept and continue',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'You can close DevDesk without accepting. The app tools remain unavailable until this policy is accepted.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
