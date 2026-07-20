import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/security/safe_clipboard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
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
        title: const Text('Snippets/Notes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSnippetEditor(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: AppSpacing.page(context),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search snippets, notes, tags, or content',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  ref.read(snippetsSearchProvider.notifier).state = value,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: snippetsAsync.when(
                loading: () =>
                    const AppLoadingState(label: 'Loading snippets...'),
                error: (err, stack) => AppErrorState(message: err.toString()),
                data: (snippets) {
                  final filtered = _filterSnippets(snippets, search);
                  if (filtered.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.note_alt_outlined,
                      title: search.isEmpty
                          ? 'No snippets yet'
                          : 'No snippets found',
                      message: search.isEmpty
                          ? 'Create your first local note or code snippet.'
                          : 'Try another title, tag, or content search.',
                    );
                  }
                  return _SnippetsContent(
                    snippets: filtered,
                    onEdit: (snippet) =>
                        _showSnippetEditor(context, ref, snippet: snippet),
                    onCopy: (snippet) => _copySnippet(context, snippet),
                    onDelete: (snippet) =>
                        _confirmDelete(context, ref, snippet.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Snippet> _filterSnippets(List<Snippet> snippets, String search) {
    final query = search.toLowerCase().trim();
    if (query.isEmpty) return snippets;
    return snippets
        .where((snippet) =>
            snippet.title.toLowerCase().contains(query) ||
            snippet.content.toLowerCase().contains(query) ||
            snippet.tags.any((tag) => tag.toLowerCase().contains(query)))
        .toList();
  }

  Future<void> _copySnippet(BuildContext context, Snippet snippet) async {
    final redacted = await SafeClipboard.copy(snippet.content);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(redacted
            ? 'Snippet copied with secrets redacted'
            : 'Snippet copied'),
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

  void _showSnippetEditor(
    BuildContext context,
    WidgetRef ref, {
    Snippet? snippet,
  }) {
    final titleController = TextEditingController(text: snippet?.title ?? '');
    final contentController =
        TextEditingController(text: snippet?.content ?? '');
    final tagsController =
        TextEditingController(text: snippet?.tags.join(', ') ?? '');
    Future<void> save(BuildContext dialogContext) async {
      final title = titleController.text.trim();
      final content = contentController.text.trim();
      final tags = tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (title.isEmpty || content.isEmpty) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('Title and content are required')),
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
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    }

    final editor = _SnippetEditorForm(
      snippet: snippet,
      titleController: titleController,
      contentController: contentController,
      tagsController: tagsController,
      onSave: save,
    );
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
    if (isWide) {
      showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            child: SizedBox(width: 680, child: editor),
          );
        },
      ).whenComplete(() {
        titleController.dispose();
        contentController.dispose();
        tagsController.dispose();
      });
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: editor,
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      contentController.dispose();
      tagsController.dispose();
    });
  }
}

class _SnippetsContent extends StatelessWidget {
  final List<Snippet> snippets;
  final ValueChanged<Snippet> onEdit;
  final ValueChanged<Snippet> onCopy;
  final ValueChanged<Snippet> onDelete;

  const _SnippetsContent({
    required this.snippets,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.medium;
        final list = ListView.separated(
          itemCount: snippets.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final snippet = snippets[index];
            return _SnippetCard(
              snippet: snippet,
              selected: isWide && index == 0,
              onEdit: () => onEdit(snippet),
              onCopy: () => onCopy(snippet),
              onDelete: () => onDelete(snippet),
            );
          },
        );
        if (!isWide) return list;
        return Row(
          children: [
            SizedBox(width: 420, child: list),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _SnippetDetailPanel(
                snippet: snippets.first,
                onEdit: () => onEdit(snippets.first),
                onCopy: () => onCopy(snippets.first),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SnippetCard extends StatelessWidget {
  final Snippet snippet;
  final bool selected;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _SnippetCard({
    required this.snippet,
    required this.selected,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onEdit,
      filled: !selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  snippet.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy snippet',
                onPressed: onCopy,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete snippet',
                color: Theme.of(context).colorScheme.error,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            snippet.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (snippet.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tag in snippet.tags) Chip(label: Text(tag)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SnippetDetailPanel extends StatelessWidget {
  final Snippet snippet;
  final VoidCallback onEdit;
  final VoidCallback onCopy;

  const _SnippetDetailPanel({
    required this.snippet,
    required this.onEdit,
    required this.onCopy,
  });

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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    snippet.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy snippet',
                  onPressed: onCopy,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit snippet',
                  onPressed: onEdit,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: AppColors.codeBackground(context),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SingleChildScrollView(
                child: SelectableText(
                  snippet.content,
                  style: AppTypography.mono(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnippetEditorForm extends StatelessWidget {
  final Snippet? snippet;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final TextEditingController tagsController;
  final Future<void> Function(BuildContext context) onSave;

  const _SnippetEditorForm({
    required this.snippet,
    required this.titleController,
    required this.contentController,
    required this.tagsController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              snippet == null ? 'New Snippet' : 'Edit Snippet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: contentController,
              decoration: InputDecoration(
                labelText: 'Content',
                alignLabelWithHint: true,
                fillColor: AppColors.codeBackground(context),
              ),
              style: AppTypography.mono(context),
              minLines: 6,
              maxLines: 12,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => onSave(context),
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
