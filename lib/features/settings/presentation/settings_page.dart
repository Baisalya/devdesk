import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/storage/backup_utils.dart';
import '../../../core/storage/local_storage.dart';

/// Settings page for theme selection, data management and about information.
class SettingsPage extends ConsumerStatefulWidget {
  final ExternalFileDocument? initialDocument;

  const SettingsPage({super.key, this.initialDocument});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    if (widget.initialDocument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _previewAndImportText(
          widget.initialDocument!.content,
          widget.initialDocument!.name,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Appearance')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selection.first);
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('Clear All Data'),
            subtitle: const Text(
              'Deletes all stored notes, API history and settings',
            ),
            onTap: _clearAllData,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Backup File'),
            subtitle: const Text('Save all local app data as JSON'),
            onTap: _exportBackupFile,
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Backup JSON'),
            subtitle: const Text('Clipboard fallback for backup export'),
            onTap: _exportBackupClipboard,
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Backup File'),
            subtitle: const Text('Preview a DevDesk backup before applying it'),
            onTap: _importBackupFile,
          ),
          ListTile(
            leading: const Icon(Icons.paste),
            title: const Text('Import Backup from Text'),
            subtitle: const Text('Paste backup JSON and preview before import'),
            onTap: _importBackupText,
          ),
          const Divider(),
          ListTile(
            title: const Text('Privacy'),
            subtitle: const Text('Local-first, no analytics, no backend'),
            onTap: _showPrivacy,
          ),
          ListTile(
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'DevDesk',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Copyright 2026 DevDesk Contributors',
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('This will delete all local data. Continue?'),
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
      await LocalStorage.clearAll();
      _showSnack('All data cleared');
    }
  }

  Future<void> _exportBackupFile() async {
    final export = await _exportData();
    final path = await ExternalFileService.saveTextAs(
      suggestedName: 'devdesk-backup.json',
      content: export,
      allowedExtensions: const ['json'],
      dialogTitle: 'Export DevDesk backup',
    );
    if (path != null) {
      _showSnack('Backup exported');
    }
  }

  Future<void> _exportBackupClipboard() async {
    final export = await _exportData();
    await Clipboard.setData(ClipboardData(text: export));
    _showSnack('Backup copied to clipboard');
  }

  Future<void> _importBackupFile() async {
    try {
      final document = await ExternalFileService.pickDeveloperFile();
      if (document == null) return;
      if (document.kind != DevFileKind.backup &&
          document.kind != DevFileKind.json) {
        _showSnack('Select a DevDesk backup JSON file.');
        return;
      }
      await _previewAndImportText(document.content, document.name);
    } on ExternalFileException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to import backup: $e');
    }
  }

  Future<void> _importBackupText() async {
    final controller = TextEditingController();
    final success = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Backup JSON'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Paste JSON here',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Preview'),
            ),
          ],
        );
      },
    );
    if (success == true) {
      await _previewAndImportText(controller.text, 'pasted backup');
    }
  }

  Future<void> _previewAndImportText(String text, String sourceName) async {
    try {
      final document = BackupUtils.decodeBackupText(text);
      final preview = BackupUtils.preview(document);
      final replace = await _showImportPreview(sourceName, preview);
      if (replace == null) return;
      await LocalStorage.importAll(document, replace: replace);
      _showSnack(replace ? 'Backup restored' : 'Backup merged');
    } on FormatException catch (e) {
      _showSnack('Invalid backup: ${e.message}');
    } catch (e) {
      _showSnack('Failed to import backup: $e');
    }
  }

  Future<bool?> _showImportPreview(
    String sourceName,
    BackupPreview preview,
  ) {
    var replace = true;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Backup import preview'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Source: $sourceName'),
                    const SizedBox(height: 12),
                    Text('Markdown files: ${preview.markdownFilesCount}'),
                    Text('Snippets: ${preview.snippetsCount}'),
                    Text('API history: ${preview.apiHistoryCount}'),
                    Text('Environments: ${preview.environmentsCount}'),
                    Text('Settings: ${preview.settingsCount}'),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Replace'),
                          icon: Icon(Icons.sync),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Merge'),
                          icon: Icon(Icons.call_merge),
                        ),
                      ],
                      selected: {replace},
                      onSelectionChanged: (selection) {
                        setDialogState(() => replace = selection.first);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(replace),
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Privacy'),
          content: const SingleChildScrollView(
            child: Text(
              'DevDesk stores data on this device. It has no analytics, no Firebase, and no backend. External files stay local and are read only after you choose them. The API Tester uses the internet only when you manually send a request to the URL you entered. JWT decoding stays local.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _exportData() async {
    return const JsonEncoder.withIndent('  ')
        .convert(await LocalStorage.exportBackupDocument());
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
