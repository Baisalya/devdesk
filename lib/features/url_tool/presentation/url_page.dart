import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_result_panel.dart';
import '../provider/url_provider.dart';

/// Page for URL encoding and decoding.
class UrlPage extends ConsumerStatefulWidget {
  const UrlPage({super.key});

  @override
  ConsumerState<UrlPage> createState() => _UrlPageState();
}

class _UrlPageState extends ConsumerState<UrlPage> {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: ref.read(urlInputProvider));
    _inputController.addListener(() {
      ref.read(urlInputProvider.notifier).state = _inputController.text;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _clear() {
    _inputController.clear();
    ref.read(urlOutputProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final output = ref.watch(urlOutputProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('URL Encoder/Decoder')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final input = _UrlInputPanel(
            controller: _inputController,
            onEncode: () => encodeUrl(ref),
            onDecode: () => decodeUrl(ref),
            onClear: _clear,
            compact: !isWide,
          );
          final result = AppResultPanel(
            title: 'Output',
            text: output,
            emptyTitle: 'Result will appear here',
            emptyMessage: 'Encode or decode URL text to generate output.',
          );
          if (isWide) {
            return Padding(
              padding: AppSpacing.page(context),
              child: Row(
                children: [
                  Expanded(child: input),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: result),
                ],
              ),
            );
          }
          return ListView(
            padding: AppSpacing.page(context),
            children: [
              input,
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: constraints.maxHeight.clamp(220, 320).toDouble(),
                child: result,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UrlInputPanel extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEncode;
  final VoidCallback onDecode;
  final VoidCallback onClear;
  final bool compact;

  const _UrlInputPanel({
    required this.controller,
    required this.onEncode,
    required this.onDecode,
    required this.onClear,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final inputField = TextField(
      controller: controller,
      expands: !compact,
      minLines: compact ? 4 : null,
      maxLines: compact ? 8 : null,
      decoration: const InputDecoration(
        hintText: 'Paste URL or encoded text here',
        alignLabelWithHint: true,
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Input', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (compact) inputField else Expanded(child: inputField),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.icon(
                onPressed: onEncode,
                icon: const Icon(Icons.link),
                label: const Text('Encode'),
              ),
              OutlinedButton.icon(
                onPressed: onDecode,
                icon: const Icon(Icons.link_off),
                label: const Text('Decode'),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
