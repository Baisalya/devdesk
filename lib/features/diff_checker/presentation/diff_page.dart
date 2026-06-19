import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/diff_provider.dart';

/// Page for comparing two text blocks.
class DiffPage extends ConsumerStatefulWidget {
  const DiffPage({super.key});

  @override
  ConsumerState<DiffPage> createState() => _DiffPageState();
}

class _DiffPageState extends ConsumerState<DiffPage> {
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController(text: ref.read(diffLeftProvider));
    _rightController = TextEditingController(text: ref.read(diffRightProvider));
    _leftController.addListener(() {
      ref.read(diffLeftProvider.notifier).state = _leftController.text;
    });
    _rightController.addListener(() {
      ref.read(diffRightProvider.notifier).state = _rightController.text;
    });
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  void _clear() {
    _leftController.clear();
    _rightController.clear();
    ref.read(diffResultProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final diffs = ref.watch(diffResultProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Diff Checker')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final left =
                      _Editor(label: 'Text A', controller: _leftController);
                  final right =
                      _Editor(label: 'Text B', controller: _rightController);
                  if (constraints.maxWidth >= 720) {
                    return Row(
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 8),
                        Expanded(child: right),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: left),
                      const SizedBox(height: 8),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => computeDiff(ref),
                  child: const Text('Compare'),
                ),
                OutlinedButton(onPressed: _clear, child: const Text('Clear')),
                OutlinedButton.icon(
                  onPressed: diffs.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: _summary(diffs)),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Diff summary copied'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy summary'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: diffs.isEmpty
                    ? const Text('Differences will appear here')
                    : SingleChildScrollView(
                        child: _buildDiffText(context, diffs),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffText(BuildContext context, List<dmp.Diff> diffs) {
    final spans = <TextSpan>[];
    for (final diff in diffs) {
      Color? bgColor;
      if (diff.operation == dmp.DIFF_INSERT) {
        bgColor = Colors.green.withValues(alpha: 0.2);
      } else if (diff.operation == dmp.DIFF_DELETE) {
        bgColor = Colors.red.withValues(alpha: 0.2);
      }
      spans.add(
        TextSpan(
          text: diff.text,
          style: TextStyle(backgroundColor: bgColor),
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  String _summary(List<dmp.Diff> diffs) {
    final added = diffs
        .where((diff) => diff.operation == dmp.DIFF_INSERT)
        .fold<int>(0, (sum, diff) => sum + diff.text.length);
    final removed = diffs
        .where((diff) => diff.operation == dmp.DIFF_DELETE)
        .fold<int>(0, (sum, diff) => sum + diff.text.length);
    final unchanged = diffs
        .where((diff) => diff.operation == dmp.DIFF_EQUAL)
        .fold<int>(0, (sum, diff) => sum + diff.text.length);
    return 'Added: $added characters\n'
        'Removed: $removed characters\n'
        'Unchanged: $unchanged characters';
  }
}

class _Editor extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _Editor({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Expanded(
          child: TextField(
            controller: controller,
            expands: true,
            minLines: null,
            maxLines: null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
      ],
    );
  }
}
