import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/safe_markdown_image.dart';
import '../domain/frontmatter_document.dart';
import '../../../core/widgets/app_input_dialog.dart';
import '../domain/knowledge_models.dart';
import '../provider/knowledge_workspace_provider.dart';
import 'widgets/markdown_editing_controller.dart';

enum KnowledgeEditorMode { edit, preview, split }

class KnowledgeWorkspacePage extends ConsumerStatefulWidget {
  final String workspaceId;

  const KnowledgeWorkspacePage({
    super.key,
    required this.workspaceId,
  });

  @override
  ConsumerState<KnowledgeWorkspacePage> createState() =>
      _KnowledgeWorkspacePageState();
}

class _KnowledgeWorkspacePageState
    extends ConsumerState<KnowledgeWorkspacePage> {
  late final MarkdownEditingController _controller;
  final _searchController = TextEditingController();
  final _findController = TextEditingController();
  final List<String> _tabs = [];
  KnowledgeEditorMode _mode = KnowledgeEditorMode.edit;
  String _query = '';
  bool _showFind = false;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditingController();
    _controller.addListener(_publishEditorValue);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_publishEditorValue)
      ..dispose();
    _searchController.dispose();
    _findController.dispose();
    super.dispose();
  }

  void _publishEditorValue() {
    ref
        .read(knowledgeWorkspaceProvider(widget.workspaceId).notifier)
        .updateContent(_controller.text);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = knowledgeWorkspaceProvider(widget.workspaceId);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (_controller.text != next.content) {
        _controller.value = TextEditingValue(
          text: next.content,
          selection: TextSelection.collapsed(offset: next.content.length),
        );
      }
      final path = next.selectedPath;
      if (path != null && !_tabs.contains(path)) {
        setState(() => _tabs.add(path));
      }
    });
    final notifier = ref.read(provider.notifier);
    final width = MediaQuery.sizeOf(context).width;
    final expanded = width >= AppBreakpoints.medium;
    final medium = width >= AppBreakpoints.compact;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          notifier.save();
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          _showDocumentSwitcher(state, notifier);
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          setState(() => _showFind = true);
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !state.dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final discard = await _confirmDiscard();
            if (discard && context.mounted) {
              await notifier.discardDraft();
              if (context.mounted) Navigator.of(context).pop(result);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                state.selectedDocument?.title ?? 'Workspace Knowledge',
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (!expanded)
                  IconButton(
                    tooltip: 'Browse documents',
                    onPressed: () => _showDocumentSwitcher(state, notifier),
                    icon: const Icon(Icons.folder_open),
                  ),
                IconButton(
                  tooltip: 'Find in document',
                  onPressed: state.selectedPath == null
                      ? null
                      : () => setState(() => _showFind = !_showFind),
                  icon: const Icon(Icons.manage_search),
                ),
                IconButton(
                  tooltip: 'Document properties',
                  onPressed: state.selectedDocument == null
                      ? null
                      : () => _editProperties(state, notifier),
                  icon: const Icon(Icons.tune),
                ),
                IconButton(
                  tooltip: 'Validate OKF workspace',
                  onPressed: () => Navigator.of(context).pushNamed(
                    '/okf',
                    arguments: widget.workspaceId,
                  ),
                  icon: const Icon(Icons.health_and_safety_outlined),
                ),
                IconButton(
                  tooltip: 'Save document',
                  onPressed:
                      state.dirty && !state.saving ? notifier.save : null,
                  icon: state.saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          state.dirty ? Icons.save : Icons.cloud_done_outlined),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              tooltip: 'Create Markdown document',
              onPressed: () => _createDocument(notifier),
              child: const Icon(Icons.note_add_outlined),
            ),
            body: SafeArea(
              child: state.loading && state.snapshot == null
                  ? const AppLoadingState(
                      label: 'Indexing workspace knowledge...')
                  : _buildBody(
                      state,
                      notifier,
                      expanded: expanded,
                      medium: medium,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    KnowledgeWorkspaceState state,
    KnowledgeWorkspaceNotifier notifier, {
    required bool expanded,
    required bool medium,
  }) {
    final documents =
        (state.snapshot?.graph.documents ?? const []).where((document) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          document.title.toLowerCase().contains(query) ||
          document.relativePath.toLowerCase().contains(query) ||
          document.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList(growable: false);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: AppErrorState(message: state.errorMessage!),
          ),
        if (state.recoveredDraft)
          _NoticeBanner(
            icon: Icons.restore,
            message: 'Recovered the latest autosaved draft.',
            action: TextButton(
              onPressed: notifier.discardDraft,
              child: const Text('Use disk version'),
            ),
          ),
        if (state.conflictingDraft != null)
          _NoticeBanner(
            icon: Icons.merge_type,
            message:
                'The file changed outside DevDesk after this draft began. The disk version is shown.',
            action: TextButton(
              onPressed: notifier.recoverConflictingDraft,
              child: const Text('Open draft carefully'),
            ),
          ),
        if (_showFind)
          _FindBar(controller: _findController, text: state.content),
        if (medium && _tabs.isNotEmpty)
          _DocumentTabs(
            paths: _tabs,
            selectedPath: state.selectedPath,
            onSelect: notifier.selectDocument,
            onClose: _closeTab,
          ),
        _EditorToolbar(
          mode: _effectiveMode(medium),
          dirty: state.dirty,
          canSplit: medium,
          onModeChanged: (mode) => setState(() => _mode = mode),
          onInsert: _insertMarkdown,
        ),
        Expanded(
          child: state.selectedDocument == null
              ? AppEmptyState(
                  icon: Icons.article_outlined,
                  title: 'No Markdown documents found',
                  message:
                      'Create a Markdown document or add .md files to this workspace.',
                  action: FilledButton.icon(
                    onPressed: () => _createDocument(notifier),
                    icon: const Icon(Icons.note_add),
                    label: const Text('Create document'),
                  ),
                )
              : _EditorSurface(
                  controller: _controller,
                  content: state.content,
                  mode: _effectiveMode(medium),
                  readOnly: false,
                ),
        ),
      ],
    );

    if (!expanded) return content;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 280,
            child: _KnowledgeSidebar(
              documents: documents,
              selectedPath: state.selectedPath,
              queryController: _searchController,
              onQueryChanged: (value) => setState(() => _query = value),
              onSelect: notifier.selectDocument,
            ),
          ),
          const VerticalDivider(width: AppSpacing.md),
          Expanded(child: content),
          const VerticalDivider(width: AppSpacing.md),
          SizedBox(
            width: 300,
            child: _KnowledgeInspector(
              state: state,
              onOpenDocument: notifier.selectDocument,
              onEditProperties: () => _editProperties(state, notifier),
              onGoToLine: _goToLine,
            ),
          ),
        ],
      ),
    );
  }

  KnowledgeEditorMode _effectiveMode(bool medium) {
    return !medium && _mode == KnowledgeEditorMode.split
        ? KnowledgeEditorMode.edit
        : _mode;
  }

  void _closeTab(String path) {
    if (_tabs.length <= 1) return;
    final index = _tabs.indexOf(path);
    setState(() => _tabs.remove(path));
    if (path ==
        ref.read(knowledgeWorkspaceProvider(widget.workspaceId)).selectedPath) {
      final replacement = _tabs[math.min(index, _tabs.length - 1)];
      ref
          .read(knowledgeWorkspaceProvider(widget.workspaceId).notifier)
          .selectDocument(replacement);
    }
  }

  void _insertMarkdown(String action) {
    switch (action) {
      case 'heading':
        _controller.insert('## Heading\n');
      case 'bold':
        _controller.wrapSelection('**', '**');
      case 'code':
        _controller.wrapSelection('`', '`');
      case 'wiki':
        _controller.wrapSelection('[[', ']]');
      case 'checklist':
        _controller.insert('- [ ] Task\n');
      case 'table':
        _controller.insert(
          '| Column | Value |\n| --- | --- |\n| Item | Detail |\n',
        );
    }
  }

  void _goToLine(int line) {
    final lines = _controller.text.split('\n');
    var offset = 0;
    for (var index = 0; index < line - 1 && index < lines.length; index++) {
      offset += lines[index].length + 1;
    }
    _controller.selection = TextSelection.collapsed(
      offset: offset.clamp(0, _controller.text.length),
    );
  }

  Future<void> _createDocument(KnowledgeWorkspaceNotifier notifier) async {
    final path = await showDialog<String>(
      context: context,
      builder: (context) => const AppTextInputDialog(
        title: 'Create Markdown document',
        labelText: 'Relative path',
        hintText: 'guides/authentication.md',
        actionLabel: 'Create',
      ),
    );
    if (path != null) await notifier.createDocument(path);
  }

  Future<void> _editProperties(
    KnowledgeWorkspaceState state,
    KnowledgeWorkspaceNotifier notifier,
  ) async {
    final document = state.selectedDocument;
    if (document == null) return;
    final type = TextEditingController(text: document.type);
    final title = TextEditingController(text: document.title);
    final description = TextEditingController(text: document.description);
    final tags = TextEditingController(text: document.tags.join(', '));
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document properties'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: type,
                    decoration: const InputDecoration(labelText: 'Type')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: tags,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'api, authentication, runbook',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Unknown YAML fields and unrelated comments are preserved. Raw YAML remains editable in the document.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'type': type.text.trim(),
              'title': title.text.trim(),
              'description': description.text.trim(),
              'tags': tags.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false),
              'updated': DateTime.now().toUtc().toIso8601String(),
            }),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    type.dispose();
    title.dispose();
    description.dispose();
    tags.dispose();
    if (result != null) notifier.applyFrontmatterFields(result);
  }

  Future<void> _showDocumentSwitcher(
    KnowledgeWorkspaceState state,
    KnowledgeWorkspaceNotifier notifier,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: _KnowledgeSidebar(
          documents: state.snapshot?.graph.documents ?? const [],
          selectedPath: state.selectedPath,
          queryController: TextEditingController(),
          onQueryChanged: (_) {},
          onSelect: (path) => Navigator.of(context).pop(path),
        ),
      ),
    );
    if (selected != null) await notifier.selectDocument(selected);
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave with unsaved changes?'),
            content: const Text(
              'A recovery draft exists, but leaving will discard it from DevDesk. Save the file or keep editing to preserve the draft.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard draft'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _EditorToolbar extends StatelessWidget {
  final KnowledgeEditorMode mode;
  final bool dirty;
  final bool canSplit;
  final ValueChanged<KnowledgeEditorMode> onModeChanged;
  final ValueChanged<String> onInsert;

  const _EditorToolbar({
    required this.mode,
    required this.dirty,
    required this.canSplit,
    required this.onModeChanged,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          SegmentedButton<KnowledgeEditorMode>(
            segments: [
              const ButtonSegment(
                  value: KnowledgeEditorMode.edit, label: Text('Edit')),
              const ButtonSegment(
                  value: KnowledgeEditorMode.preview, label: Text('Preview')),
              if (canSplit)
                const ButtonSegment(
                    value: KnowledgeEditorMode.split, label: Text('Split')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
          const SizedBox(width: AppSpacing.md),
          if (dirty) const Chip(label: Text('Unsaved')),
          _InsertButton(
              icon: Icons.title,
              label: 'Heading',
              value: 'heading',
              onInsert: onInsert),
          _InsertButton(
              icon: Icons.format_bold,
              label: 'Bold',
              value: 'bold',
              onInsert: onInsert),
          _InsertButton(
              icon: Icons.code,
              label: 'Code',
              value: 'code',
              onInsert: onInsert),
          _InsertButton(
              icon: Icons.link,
              label: 'Wiki link',
              value: 'wiki',
              onInsert: onInsert),
          _InsertButton(
              icon: Icons.check_box_outlined,
              label: 'Checklist',
              value: 'checklist',
              onInsert: onInsert),
          _InsertButton(
              icon: Icons.table_chart_outlined,
              label: 'Table',
              value: 'table',
              onInsert: onInsert),
        ],
      ),
    );
  }
}

class _InsertButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<String> onInsert;

  const _InsertButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: () => onInsert(value),
      icon: Icon(icon),
    );
  }
}

class _EditorSurface extends StatelessWidget {
  final MarkdownEditingController controller;
  final String content;
  final KnowledgeEditorMode mode;
  final bool readOnly;

  const _EditorSurface({
    required this.controller,
    required this.content,
    required this.mode,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final editor = Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: AppTypography.mono(context),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.all(AppSpacing.md),
        ),
      ),
    );
    String body;
    try {
      body = FrontmatterDocument.parse(content).body;
    } catch (_) {
      body = content;
    }
    final preview = body.trim().isEmpty
        ? const AppEmptyState(
            icon: Icons.preview_outlined,
            title: 'Nothing to preview',
            message: 'Write Markdown to render a preview.',
          )
        : Markdown(
            data: '$body\n\n',
            selectable: true,
            imageBuilder: buildSafeMarkdownImage,
            padding: const EdgeInsets.all(AppSpacing.md),
            styleSheet:
                MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              code: AppTypography.mono(context),
              codeblockDecoration: BoxDecoration(
                color: AppColors.codeBackground(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
    return switch (mode) {
      KnowledgeEditorMode.edit => editor,
      KnowledgeEditorMode.preview => preview,
      KnowledgeEditorMode.split => Row(
          children: [
            Expanded(child: editor),
            const VerticalDivider(width: 1),
            Expanded(child: preview),
          ],
        ),
    };
  }
}

class _KnowledgeSidebar extends StatelessWidget {
  final List<KnowledgeDocument> documents;
  final String? selectedPath;
  final TextEditingController queryController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelect;

  const _KnowledgeSidebar({
    required this.documents,
    required this.selectedPath,
    required this.queryController,
    required this.onQueryChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            controller: queryController,
            decoration: const InputDecoration(
              hintText: 'Quick open',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: documents.isEmpty
              ? const Center(child: Text('No matching documents'))
              : ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    return ListTile(
                      selected: selectedPath == document.relativePath,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        document.relativePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelect(document.relativePath),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _KnowledgeInspector extends StatelessWidget {
  final KnowledgeWorkspaceState state;
  final ValueChanged<String> onOpenDocument;
  final VoidCallback onEditProperties;
  final ValueChanged<int> onGoToLine;

  const _KnowledgeInspector({
    required this.state,
    required this.onOpenDocument,
    required this.onEditProperties,
    required this.onGoToLine,
  });

  @override
  Widget build(BuildContext context) {
    final document = state.selectedDocument;
    if (document == null) return const SizedBox.shrink();
    final graph = state.snapshot!.graph;
    final backlinks = graph.backlinks[document.id] ?? const <String>{};
    final outgoing = graph.outgoing[document.id] ?? const <String>{};
    final byId = {for (final item in graph.documents) item.id: item};
    final issues = state.snapshot!.issues
        .where((issue) => issue.documentId == document.id)
        .toList(growable: false);
    final headings = _headings(state.content);
    final linked = {...backlinks, ...outgoing};
    final body = document.frontmatter.body.toLowerCase();
    final unlinkedMentions = graph.documents
        .where((candidate) =>
            candidate.id != document.id &&
            !linked.contains(candidate.id) &&
            candidate.title.trim().length >= 3 &&
            body.contains(candidate.title.toLowerCase()))
        .toList(growable: false);
    final selectedTags = document.tags.map((tag) => tag.toLowerCase()).toSet();
    final related = graph.documents
        .where((candidate) =>
            candidate.id != document.id &&
            candidate.tags
                .map((tag) => tag.toLowerCase())
                .any(selectedTags.contains))
        .take(12)
        .toList(growable: false);
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Properties'),
              Tab(text: 'Outline'),
              Tab(text: 'Links'),
              Tab(text: 'Issues'),
              Tab(text: 'Graph'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _Property(label: 'Type', value: document.type),
                    _Property(label: 'Title', value: document.title),
                    _Property(
                        label: 'Stable ID', value: document.stableId ?? ''),
                    _Property(
                        label: 'Description', value: document.description),
                    _Property(label: 'Tags', value: document.tags.join(', ')),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.tonalIcon(
                      onPressed: onEditProperties,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit properties'),
                    ),
                  ],
                ),
                headings.isEmpty
                    ? const Center(child: Text('No headings'))
                    : ListView.builder(
                        itemCount: headings.length,
                        itemBuilder: (context, index) {
                          final heading = headings[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.only(
                              left: 8.0 + (heading.level - 1) * 12,
                              right: 8,
                            ),
                            title: Text(heading.text),
                            onTap: () => onGoToLine(heading.line),
                          );
                        },
                      ),
                ListView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  children: [
                    Text('Backlinks (${backlinks.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                    for (final id in backlinks)
                      _LinkedDocumentTile(
                          document: byId[id], onOpen: onOpenDocument),
                    const SizedBox(height: AppSpacing.md),
                    Text('Outgoing (${outgoing.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                    for (final id in outgoing)
                      _LinkedDocumentTile(
                          document: byId[id], onOpen: onOpenDocument),
                    const SizedBox(height: AppSpacing.md),
                    Text('Unlinked mentions (${unlinkedMentions.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                    for (final item in unlinkedMentions)
                      _LinkedDocumentTile(
                          document: item, onOpen: onOpenDocument),
                    const SizedBox(height: AppSpacing.md),
                    Text('Related by tag (${related.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                    for (final item in related)
                      _LinkedDocumentTile(
                          document: item, onOpen: onOpenDocument),
                  ],
                ),
                issues.isEmpty
                    ? const Center(child: Text('No document issues'))
                    : ListView.builder(
                        itemCount: issues.length,
                        itemBuilder: (context, index) => ListTile(
                          leading: const Icon(Icons.warning_amber),
                          title: Text(issues[index].kind.name),
                          subtitle: Text(issues[index].message),
                        ),
                      ),
                _KnowledgeGraphPanel(
                  graph: graph,
                  selected: document,
                  onOpen: onOpenDocument,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingEntry {
  final int level;
  final String text;
  final int line;

  const _HeadingEntry({
    required this.level,
    required this.text,
    required this.line,
  });
}

List<_HeadingEntry> _headings(String source) {
  String body;
  var lineOffset = 0;
  try {
    final parsed = FrontmatterDocument.parse(source);
    body = parsed.body;
    if (parsed.hasFrontmatter) {
      lineOffset = parsed.raw.replaceAll('\r\n', '\n').split('\n').length + 2;
    }
  } catch (_) {
    body = source;
  }
  final result = <_HeadingEntry>[];
  final lines = body.replaceAll('\r\n', '\n').split('\n');
  var inFence = false;
  for (var index = 0; index < lines.length; index++) {
    final trimmed = lines[index].trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    final match = RegExp(r'^(#{1,6})\s+(.+?)\s*#*$').firstMatch(trimmed);
    if (match != null) {
      result.add(
        _HeadingEntry(
          level: match.group(1)!.length,
          text: match.group(2)!.trim(),
          line: index + 1 + lineOffset,
        ),
      );
    }
  }
  return result;
}

class _KnowledgeGraphPanel extends StatelessWidget {
  final KnowledgeGraph graph;
  final KnowledgeDocument selected;
  final ValueChanged<String> onOpen;

  const _KnowledgeGraphPanel({
    required this.graph,
    required this.selected,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final ids = <String>{
      selected.id,
      ...graph.outgoing[selected.id] ?? const <String>{},
      ...graph.backlinks[selected.id] ?? const <String>{},
    }.take(80).toList(growable: false);
    final byId = {for (final item in graph.documents) item.id: item};
    const canvas = 720.0;
    return InteractiveViewer(
      minScale: 0.45,
      maxScale: 2.8,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      child: SizedBox.square(
        dimension: canvas,
        child: Stack(
          children: [
            CustomPaint(
              size: const Size.square(canvas),
              painter: _GraphEdgesPainter(ids: ids, graph: graph),
            ),
            for (var index = 0; index < ids.length; index++)
              _GraphNode(
                document: byId[ids[index]]!,
                selected: ids[index] == selected.id,
                position: _nodePosition(index, ids.length, canvas),
                onTap: () => onOpen(byId[ids[index]]!.relativePath),
              ),
          ],
        ),
      ),
    );
  }

  static Offset _nodePosition(int index, int count, double size) {
    if (index == 0) return Offset(size / 2 - 45, size / 2 - 24);
    final angle = (index - 1) / math.max(1, count - 1) * math.pi * 2;
    final radius = math.min(250.0, 100 + count * 8);
    return Offset(
      size / 2 + math.cos(angle) * radius - 45,
      size / 2 + math.sin(angle) * radius - 24,
    );
  }
}

class _GraphEdgesPainter extends CustomPainter {
  final List<String> ids;
  final KnowledgeGraph graph;

  const _GraphEdgesPainter({required this.ids, required this.graph});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.42)
      ..strokeWidth = 1.5;
    for (var source = 0; source < ids.length; source++) {
      for (final targetId in graph.outgoing[ids[source]] ?? const <String>{}) {
        final target = ids.indexOf(targetId);
        if (target < 0) continue;
        canvas.drawLine(
          _KnowledgeGraphPanel._nodePosition(source, ids.length, size.width) +
              const Offset(45, 24),
          _KnowledgeGraphPanel._nodePosition(target, ids.length, size.width) +
              const Offset(45, 24),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphEdgesPainter oldDelegate) {
    return oldDelegate.ids != ids || oldDelegate.graph != graph;
  }
}

class _GraphNode extends StatelessWidget {
  final KnowledgeDocument document;
  final bool selected;
  final Offset position;
  final VoidCallback onTap;

  const _GraphNode({
    required this.document,
    required this.selected,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: 90,
      height: 48,
      child: Tooltip(
        message: document.relativePath,
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkedDocumentTile extends StatelessWidget {
  final KnowledgeDocument? document;
  final ValueChanged<String> onOpen;

  const _LinkedDocumentTile({required this.document, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final value = document;
    if (value == null) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(value.title),
      subtitle: Text(value.relativePath),
      onTap: () => onOpen(value.relativePath),
    );
  }
}

class _Property extends StatelessWidget {
  final String label;
  final String value;

  const _Property({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

class _DocumentTabs extends StatelessWidget {
  final List<String> paths;
  final String? selectedPath;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  const _DocumentTabs({
    required this.paths,
    required this.selectedPath,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final path = paths[index];
          return InputChip(
            selected: path == selectedPath,
            label: Text(path.split('/').last),
            onPressed: () => onSelect(path),
            onDeleted: paths.length > 1 ? () => onClose(path) : null,
          );
        },
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget action;

  const _NoticeBanner({
    required this.icon,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: Icon(icon),
      content: Text(message),
      actions: [action],
    );
  }
}

class _FindBar extends StatelessWidget {
  final TextEditingController controller;
  final String text;

  const _FindBar({required this.controller, required this.text});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        final query = controller.text;
        final count = query.isEmpty
            ? 0
            : RegExp(RegExp.escape(query), caseSensitive: false)
                .allMatches(text)
                .length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            0,
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Find in document',
              prefixIcon: const Icon(Icons.search),
              suffixText: '$count match${count == 1 ? '' : 'es'}',
            ),
            onChanged: (_) => setState(() {}),
          ),
        );
      },
    );
  }
}
