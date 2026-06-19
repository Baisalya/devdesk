import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/snippet.dart';
import '../provider/snippets_provider.dart';

/// Page for viewing and managing local snippets/notes.
class SnippetsPage extends ConsumerWidget {
  const SnippetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snippetsAsync = ref.watch(snippetsProvider);
    final search = ref.watch(snippetsSearchProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snippets'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSnippetEditor(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  ref.read(snippetsSearchProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: snippetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text(err.toString())),
              data: (snippets) {
                final filtered = search.isEmpty
                    ? snippets
                    : snippets
                        .where((snippet) =>
                            snippet.title
                                .toLowerCase()
                                .contains(search.toLowerCase()) ||
                            snippet.content
                                .toLowerCase()
                                .contains(search.toLowerCase()) ||
                            snippet.tags.any((tag) => tag
                                .toLowerCase()
                                .contains(search.toLowerCase())))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No snippets found'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final snip = filtered[index];
                    return ListTile(
                      title: Text(snip.title),
                      subtitle: Text(snip.tags.join(', ')),
                      onTap: () =>
                          _showSnippetEditor(context, ref, snippet: snip),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy snippet',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: snip.content),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Snippet copied'),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete snippet',
                            onPressed: () =>
                                _confirmDelete(context, ref, snip.id),
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int snippetId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete snippet?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await ref.read(snippetsProvider.notifier).deleteSnippet(snippetId);
    }
  }

  void _showSnippetEditor(BuildContext context, WidgetRef ref,
      {Snippet? snippet}) {
    final titleController = TextEditingController(text: snippet?.title ?? '');
    final contentController =
        TextEditingController(text: snippet?.content ?? '');
    final tagsController =
        TextEditingController(text: snippet?.tags.join(', ') ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 12,
            right: 12,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snippet == null ? 'New Snippet' : 'Edit Snippet',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final content = contentController.text.trim();
                      final tags = tagsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      if (title.isEmpty || content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Title and content are required')),
                        );
                        return;
                      }
                      final notifier = ref.read(snippetsProvider.notifier);
                      if (snippet == null) {
                        final id = await notifier.nextId();
                        final newSnippet = Snippet(
                          id: id,
                          title: title,
                          content: content,
                          tags: tags,
                        );
                        await notifier.addSnippet(newSnippet);
                      } else {
                        final updated = snippet.copyWith(
                          title: title,
                          content: content,
                          tags: tags,
                        );
                        await notifier.updateSnippet(updated);
                      }
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
