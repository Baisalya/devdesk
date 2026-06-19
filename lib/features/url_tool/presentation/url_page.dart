import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  onPressed: () => encodeUrl(ref),
                  child: const Text('Encode'),
                ),
                ElevatedButton(
                  onPressed: () => decodeUrl(ref),
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
