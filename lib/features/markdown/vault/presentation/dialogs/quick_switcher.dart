import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/vault_note.dart';
import '../../provider/vault_provider.dart';
import '../../utils/vault_parser.dart';

class QuickSwitcher extends ConsumerStatefulWidget {
  const QuickSwitcher({super.key});

  @override
  ConsumerState<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends ConsumerState<QuickSwitcher> {
  final _controller = TextEditingController();
  String _query = '';
  bool _fullTextSearch = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(vaultNotesProvider);
    final results = VaultParser.searchNotes(
      notes,
      _query,
      fullText: _fullTextSearch,
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search notes...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Full text'),
                    selected: _fullTextSearch,
                    onSelected: (value) =>
                        setState(() => _fullTextSearch = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('No notes found'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(result.note.title),
                            subtitle: Text(
                              result.matchPreview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _openNote(context, result.note),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNote(BuildContext context, VaultNote note) async {
    if (ref.read(vaultHasUnsavedChangesProvider)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text(
            'Your current draft has been autosaved. Switch notes without saving?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await ref.read(vaultNotesProvider.notifier).markOpened(note.id);
    ref.read(selectedNoteIdProvider.notifier).state = note.id;
    final tabs = [...ref.read(openedNoteIdsProvider)];
    if (!tabs.contains(note.id)) {
      tabs.add(note.id);
      ref.read(openedNoteIdsProvider.notifier).state = tabs;
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}
