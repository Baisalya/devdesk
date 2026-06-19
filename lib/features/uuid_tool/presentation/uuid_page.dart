import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Count:'),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed >= 1 && parsed <= 1000) {
                        ref.read(uuidCountProvider.notifier).state = parsed;
                      }
                    },
                    decoration: const InputDecoration(
                      helperText: '1-1000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => generateUuids(ref),
                  child: const Text('Generate'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (uuids.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
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
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: uuids.length,
                itemBuilder: (context, index) {
                  final id = uuids[index];
                  return ListTile(
                    title: SelectableText(id),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy UUID',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: id));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UUID copied')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
