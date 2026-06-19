import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_result_panel.dart';
import '../provider/base64_provider.dart';

/// Page for Base64 encoding and decoding.
class Base64Page extends ConsumerStatefulWidget {
  const Base64Page({super.key});

  @override
  ConsumerState<Base64Page> createState() => _Base64PageState();
}

class _Base64PageState extends ConsumerState<Base64Page> {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController =
        TextEditingController(text: ref.read(base64InputProvider));
    _inputController.addListener(() {
      ref.read(base64InputProvider.notifier).state = _inputController.text;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _clear() {
    _inputController.clear();
    ref.read(base64OutputProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final output = ref.watch(base64OutputProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Base64 Tool')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final input = _Base64InputPanel(
            controller: _inputController,
            onEncode: () => encodeBase64(ref),
            onDecode: () => decodeBase64(ref),
            onClear: _clear,
          );
          final result = AppResultPanel(
            title: 'Output',
            text: output,
            emptyTitle: 'Result will appear here',
            emptyMessage: 'Encode or decode text to generate output.',
          );
          return Padding(
            padding: AppSpacing.page(context),
            child: isWide
                ? Row(
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: result),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: input),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(child: result),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _Base64InputPanel extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEncode;
  final VoidCallback onDecode;
  final VoidCallback onClear;

  const _Base64InputPanel({
    required this.controller,
    required this.onEncode,
    required this.onDecode,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Input', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              minLines: null,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Paste text or Base64 here',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.icon(
                onPressed: onEncode,
                icon: const Icon(Icons.lock),
                label: const Text('Encode'),
              ),
              OutlinedButton.icon(
                onPressed: onDecode,
                icon: const Icon(Icons.lock_open),
                label: const Text('Decode'),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Uses UTF-8 text for human-readable developer data.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
