import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/vault_note.dart';
import '../../provider/vault_export_service.dart';
import '../../provider/vault_provider.dart';
import '../../provider/vault_template_service.dart';
import '../../utils/vault_parser.dart';

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(vaultNotesProvider);
    final activeNote = ref.watch(activeNoteProvider);
    final commands = _commands(context, notes, activeNote);
    final filtered = commands
        .where((command) =>
            command.title.toLowerCase().contains(_query.toLowerCase()) ||
            command.subtitle.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Type a command...',
                  prefixIcon: Icon(Icons.terminal),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final command = filtered[index];
                    return ListTile(
                      leading: Icon(
                        command.icon,
                        color: command.isDangerous
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      title: Text(
                        command.title,
                        style: TextStyle(
                          color: command.isDangerous
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                      subtitle: Text(command.subtitle),
                      onTap: () {
                        Navigator.of(context).pop();
                        command.action();
                      },
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

  List<_Command> _commands(
    BuildContext context,
    List<VaultNote> notes,
    VaultNote? activeNote,
  ) {
    return [
      _Command(
        title: 'New Note',
        subtitle: 'Create a blank markdown note',
        icon: Icons.add,
        action: () async {
          final note = await ref.read(vaultNotesProvider.notifier).createNote();
          _openNote(note);
        },
      ),
      _Command(
        title: 'Daily Note',
        subtitle: 'Open or create today in the Daily folder',
        icon: Icons.calendar_today,
        action: () async {
          final note =
              await ref.read(vaultNotesProvider.notifier).createDailyNote();
          _openNote(note);
        },
      ),
      for (final template in VaultTemplateService.templates.entries)
        _Command(
          title: 'Template: ${template.key}',
          subtitle: 'Create a note from this template',
          icon: Icons.copy_all,
          action: () async {
            final note = await ref.read(vaultNotesProvider.notifier).createNote(
                  title: template.key,
                  content: template.value,
                  folderPath: 'Templates',
                );
            _openNote(note);
          },
        ),
      _Command(
        title: 'Generate API docs note',
        subtitle: 'Create starter API documentation markdown',
        icon: Icons.api,
        action: () async {
          final note = await ref.read(vaultNotesProvider.notifier).createNote(
                title: 'API Documentation',
                content: VaultTemplateService.apiDocsFromRequest(
                  name: 'API Documentation',
                  method: 'GET',
                  url: '/path',
                ),
                folderPath: 'Docs',
              );
          _openNote(note);
        },
      ),
      _Command(
        title: 'Open README Generator',
        subtitle: 'Use DevDesk README generator',
        icon: Icons.assignment,
        action: () => Navigator.of(context).pushNamed('/readme'),
      ),
      _Command(
        title: 'Open Diff Workspace',
        subtitle: 'Compare markdown notes or files',
        icon: Icons.difference,
        action: () => Navigator.of(context).pushNamed('/diff'),
      ),
      _Command(
        title: 'Open API Workspaces',
        subtitle: 'Create docs from saved API work',
        icon: Icons.api,
        action: () => Navigator.of(context).pushNamed('/api'),
      ),
      _Command(
        title: 'Open Snippets',
        subtitle: 'Manage saved snippets',
        icon: Icons.snippet_folder,
        action: () => Navigator.of(context).pushNamed('/snippets'),
      ),
      _Command(
        title: 'Export Vault as ZIP',
        subtitle: 'Save all notes as a local ZIP backup',
        icon: Icons.folder_zip,
        action: () => VaultExportService.exportVaultAsZip(notes),
      ),
      _Command(
        title: 'Export Vault as JSON',
        subtitle: 'Save a structured local vault backup',
        icon: Icons.data_object,
        action: () => VaultExportService.exportVaultAsJson(notes),
      ),
      if (activeNote != null)
        _Command(
          title: 'Check current note links',
          subtitle: 'Find broken wiki links and local paths',
          icon: Icons.link_off,
          action: () {
            final broken = VaultParser.brokenInternalLinks(activeNote, notes);
            final paths = VaultParser.extractLocalLinkPaths(activeNote.content);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${broken.length} broken wiki link(s), ${paths.length} local path(s)',
                ),
              ),
            );
          },
        ),
      if (activeNote != null)
        _Command(
          title: 'Delete Current Note',
          subtitle: 'Remove the active note from the vault',
          icon: Icons.delete,
          action: () async {
            await ref
                .read(vaultNotesProvider.notifier)
                .deleteNote(activeNote.id);
            ref.read(selectedNoteIdProvider.notifier).state = null;
          },
          isDangerous: true,
        ),
    ];
  }

  void _openNote(VaultNote note) {
    final tabs = [...ref.read(openedNoteIdsProvider)];
    if (!tabs.contains(note.id)) {
      tabs.add(note.id);
      ref.read(openedNoteIdsProvider.notifier).state = tabs;
    }
    ref.read(selectedNoteIdProvider.notifier).state = note.id;
  }
}

class _Command {
  final String title;
  final String subtitle;
  final IconData icon;
  final FutureOr<void> Function() action;
  final bool isDangerous;

  const _Command({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
    this.isDangerous = false,
  });
}
