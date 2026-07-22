import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../provider/uuid_provider.dart';

/// Page for generating UUIDs.
class UuidPage extends ConsumerStatefulWidget {
  const UuidPage({super.key});

  @override
  ConsumerState<UuidPage> createState() => _UuidPageState();
}

class _UuidPageState extends ConsumerState<UuidPage> {
  late final TextEditingController _countController;

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(
      text: ref.read(uuidCountProvider).toString(),
    );
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uuids = ref.watch(uuidListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('UUID Generator')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final generator = _UuidGeneratorCard(
            controller: _countController,
            onCountChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed >= 1 && parsed <= 1000) {
                ref.read(uuidCountProvider.notifier).state = parsed;
              }
            },
            onGenerate: () => generateUuids(ref),
          );
          final list = _UuidListPanel(uuids: uuids);
          if (isWide) {
            return Padding(
              padding: AppSpacing.page(context),
              child: Row(
                children: [
                  SizedBox(width: 360, child: generator),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: list),
                ],
              ),
            );
          }
          return ListView(
            padding: AppSpacing.page(context),
            children: [
              generator,
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: constraints.maxHeight.clamp(240, 360).toDouble(),
                child: list,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UuidGeneratorCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCountChanged;
  final VoidCallback onGenerate;

  const _UuidGeneratorCard({
    required this.controller,
    required this.onCountChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Generator', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: onCountChanged,
            decoration: const InputDecoration(
              labelText: 'Count',
              helperText: '1-1000',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}

class _UuidListPanel extends StatelessWidget {
  final List<String> uuids;

  const _UuidListPanel({required this.uuids});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  'Generated UUIDs',
                  style: Theme.of(context).textTheme.titleMedium,
                );
                final copyButton = OutlinedButton.icon(
                  onPressed: uuids.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: uuids.join('\n')),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All UUIDs copied')),
                          );
                        },
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy all'),
                );
                final stack = constraints.maxWidth < 480 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: AppSpacing.xs),
                      copyButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    copyButton,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: uuids.isEmpty
                ? const AppEmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'No UUIDs yet',
                    message: 'Choose a count and generate UUID v4 values.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900 ? 2 : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          childAspectRatio: columns == 1 ? 6.4 : 5.6,
                        ),
                        itemCount: uuids.length,
                        itemBuilder: (context, index) {
                          final id = uuids[index];
                          return AppCard(
                            filled: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    id,
                                    style: AppTypography.mono(context),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copy UUID',
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: id),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('UUID copied'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
