import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/app_spacing.dart';
import '../../model/vault_note.dart';
import '../../provider/vault_export_service.dart';
import '../../provider/vault_provider.dart';
import '../../utils/vault_parser.dart';

class VaultInspector extends ConsumerWidget {
  final VaultNote note;
  final ValueChanged<int> onJumpToHeading;

  const VaultInspector({
    super.key,
    required this.note,
    required this.onJumpToHeading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(vaultNotesProvider);
    final headings = VaultParser.extractHeadings(note.content);
    final tags = VaultParser.extractAllTags(note.content);
    final backlinks = VaultParser.notesLinkingTo(note, notes);
    final brokenLinks = VaultParser.brokenInternalLinks(note, notes);
    final linkMap = VaultParser.buildLinkMap(notes);

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Outline'),
              Tab(text: 'Links'),
              Tab(text: 'Tags'),
              Tab(text: 'Props'),
              Tab(text: 'History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OutlineView(headings: headings, onJump: onJumpToHeading),
                _LinksView(
                  note: note,
                  backlinks: backlinks,
                  brokenLinks: brokenLinks,
                  linkMap: linkMap,
                ),
                _TagsView(tags: tags),
                _PropertiesView(note: note),
                _HistoryView(note: note),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineView extends StatelessWidget {
  final List<MarkdownHeading> headings;
  final ValueChanged<int> onJump;

  const _OutlineView({
    required this.headings,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    if (headings.isEmpty) {
      return const Center(child: Text('No headings found'));
    }
    return ListView.builder(
      itemCount: headings.length,
      itemBuilder: (context, index) {
        final heading = headings[index];
        return ListTile(
          contentPadding: EdgeInsets.only(left: 12.0 * heading.level),
          title: Text(
            heading.text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          subtitle: Text('Line ${heading.lineIndex + 1}'),
          onTap: () => onJump(heading.lineIndex),
        );
      },
    );
  }
}

class _LinksView extends StatefulWidget {
  final VaultNote note;
  final List<String> backlinks;
  final List<String> brokenLinks;
  final Map<String, List<String>> linkMap;

  const _LinksView({
    required this.note,
    required this.backlinks,
    required this.brokenLinks,
    required this.linkMap,
  });

  @override
  State<_LinksView> createState() => _LinksViewState();
}

class _LinksViewState extends State<_LinksView> {
  bool _checkingUrls = false;
  final Map<String, UrlCheckResult> _urlResults = {};

  @override
  Widget build(BuildContext context) {
    final outgoing = VaultParser.extractWikiLinks(widget.note.content);
    final urls = VaultParser.extractExternalUrls(widget.note.content);
    final localPaths = VaultParser.extractLocalLinkPaths(widget.note.content);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const _ListHeader(title: 'Backlinks'),
        if (widget.backlinks.isEmpty)
          const Text('No backlinks found.')
        else
          for (final link in widget.backlinks)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_back, size: 16),
              title: Text(link),
            ),
        const Divider(),
        const _ListHeader(title: 'Outgoing wiki links'),
        if (outgoing.isEmpty)
          const Text('No outgoing wiki links.')
        else
          for (final link in outgoing)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_outward, size: 16),
              title: Text(link),
            ),
        const Divider(),
        const _ListHeader(title: 'Broken internal links'),
        if (widget.brokenLinks.isEmpty)
          const Text('No broken internal links.')
        else
          for (final link in widget.brokenLinks)
            ListTile(
              dense: true,
              leading: const Icon(Icons.link_off, size: 16, color: Colors.red),
              title: Text(link),
            ),
        const Divider(),
        const _ListHeader(title: 'External URLs'),
        if (urls.isEmpty)
          const Text('No external URLs found.')
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _checkingUrls ? null : () => _checkUrls(urls),
              icon: const Icon(Icons.travel_explore),
              label: Text(_checkingUrls ? 'Checking...' : 'Check URLs'),
            ),
          ),
          for (final url in urls)
            ListTile(
              dense: true,
              leading: Icon(
                _urlResults[url]?.isReachable == true
                    ? Icons.check_circle
                    : Icons.public,
                size: 16,
              ),
              title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: _urlResults[url] == null
                  ? null
                  : Text('Status: ${_urlResults[url]!.statusCode ?? 'failed'}'),
            ),
        ],
        const Divider(),
        const _ListHeader(title: 'Linked local files/images'),
        if (localPaths.isEmpty)
          const Text('No local attachment paths found.')
        else
          for (final path in localPaths)
            ListTile(
              dense: true,
              leading: const Icon(Icons.attachment, size: 16),
              title: Text(path),
            ),
        const Divider(),
        const _ListHeader(title: 'Link map'),
        for (final entry in widget.linkMap.entries)
          ListTile(
            dense: true,
            title: Text(entry.key),
            subtitle: Text(
              entry.value.isEmpty ? 'No links' : entry.value.join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Future<void> _checkUrls(List<String> urls) async {
    setState(() => _checkingUrls = true);
    for (final url in urls) {
      final result = await VaultExportService.checkExternalUrl(url);
      if (!mounted) return;
      setState(() => _urlResults[url] = result);
    }
    if (mounted) setState(() => _checkingUrls = false);
  }
}

class _TagsView extends StatelessWidget {
  final List<String> tags;

  const _TagsView({required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Center(child: Text('No tags found'));
    }
    return ListView.builder(
      itemCount: tags.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.tag, size: 16),
          title: Text('#${tags[index]}'),
        );
      },
    );
  }
}

class _PropertiesView extends StatelessWidget {
  final VaultNote note;

  const _PropertiesView({required this.note});

  @override
  Widget build(BuildContext context) {
    final metadata = {
      'title': note.title,
      'status': note.metadata['status'] ?? 'draft',
      'created': note.createdAt.toIso8601String(),
      'updated': note.updatedAt.toIso8601String(),
      'folder': note.folderPath.isEmpty ? 'Vault root' : note.folderPath,
      ...note.metadata,
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const _ListHeader(title: 'Properties'),
        for (final entry in metadata.entries)
          ListTile(
            dense: true,
            title: Text(entry.key),
            subtitle: Text(entry.value.toString()),
          ),
      ],
    );
  }
}

class _HistoryView extends ConsumerWidget {
  final VaultNote note;

  const _HistoryView({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (note.versionHistory.isEmpty) {
      return const Center(child: Text('No previous versions yet'));
    }
    final versions = note.versionHistory.reversed.toList();
    return ListView.builder(
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(version.timestamp.toString().split('.').first),
          subtitle: Text(
            version.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: () {
              ref
                  .read(vaultNotesProvider.notifier)
                  .restoreVersion(note.id, version);
            },
            child: const Text('Restore'),
          ),
        );
      },
    );
  }
}

class _ListHeader extends StatelessWidget {
  final String title;

  const _ListHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
