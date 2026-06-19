import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Input'),
            const SizedBox(height: 4),
            TextField(
              controller: _inputController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => encodeBase64(ref),
                  child: const Text('Encode'),
                ),
                ElevatedButton(
                  onPressed: () => decodeBase64(ref),
                  child: const Text('Decode'),
                ),
                OutlinedButton(onPressed: _clear, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Output'),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: output == null
                    ? const Text('Result will appear here')
                    : SingleChildScrollView(child: SelectableText(output)),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: output != null
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: output));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  : null,
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }
}
