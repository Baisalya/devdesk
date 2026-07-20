import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/files/external_file.dart';
import '../core/files/external_file_service.dart';

final GlobalKey<NavigatorState> devDeskNavigatorKey =
    GlobalKey<NavigatorState>();

class DevDeskCommand {
  final String label;
  final String route;
  final IconData icon;
  final String? shortcut;

  const DevDeskCommand({
    required this.label,
    required this.route,
    required this.icon,
    this.shortcut,
  });
}

const devDeskCommands = <DevDeskCommand>[
  DevDeskCommand(
    label: 'Dashboard',
    route: '/dashboard',
    icon: Icons.dashboard,
    shortcut: 'Ctrl+L',
  ),
  DevDeskCommand(
    label: 'New Markdown',
    route: '/markdown',
    icon: Icons.edit_document,
    shortcut: 'Ctrl+N',
  ),
  DevDeskCommand(label: 'Markdown Vault', route: '/vault', icon: Icons.folder),
  DevDeskCommand(label: 'API Tester', route: '/api', icon: Icons.api),
  DevDeskCommand(label: 'JSON Tools', route: '/json', icon: Icons.data_object),
  DevDeskCommand(label: 'Diff Checker', route: '/diff', icon: Icons.difference),
  DevDeskCommand(label: 'Snippets', route: '/snippets', icon: Icons.note),
  DevDeskCommand(label: 'Settings', route: '/settings', icon: Icons.settings),
];

/// Global keyboard shortcuts for the application.
///
/// These should be registered in [MaterialApp.shortcuts].
final Map<ShortcutActivator, Intent> devDeskShortcuts = {
  const SingleActivator(LogicalKeyboardKey.keyK, control: true):
      const PaletteIntent(),
  const SingleActivator(LogicalKeyboardKey.keyO, control: true):
      const OpenFileIntent(),
  const SingleActivator(LogicalKeyboardKey.keyL, control: true):
      const DashboardIntent(),
  const SingleActivator(LogicalKeyboardKey.keyN, control: true):
      const NewMarkdownIntent(),
};

/// Global actions for the application.
///
/// These should be registered in [MaterialApp.actions].
final Map<Type, Action<Intent>> devDeskActions = {
  PaletteIntent: CallbackAction<PaletteIntent>(
    onInvoke: (_) {
      showDevDeskCommandPalette();
      return null;
    },
  ),
  OpenFileIntent: CallbackAction<OpenFileIntent>(
    onInvoke: (_) {
      openDeveloperFileFromCommand();
      return null;
    },
  ),
  DashboardIntent: CallbackAction<DashboardIntent>(
    onInvoke: (_) {
      _replaceWith('/dashboard');
      return null;
    },
  ),
  NewMarkdownIntent: CallbackAction<NewMarkdownIntent>(
    onInvoke: (_) {
      devDeskNavigatorKey.currentState?.pushNamed('/markdown');
      return null;
    },
  ),
};

/// Intent to open the global command palette.
class PaletteIntent extends Intent {
  const PaletteIntent();
}

/// Intent to open an external file.
class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

/// Intent to navigate to the dashboard.
class DashboardIntent extends Intent {
  const DashboardIntent();
}

/// Intent to create a new markdown file.
class NewMarkdownIntent extends Intent {
  const NewMarkdownIntent();
}

Future<void> showDevDeskCommandPalette() async {
  final context = devDeskNavigatorKey.currentContext;
  if (context == null) return;
  final queryController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final query = queryController.text.trim().toLowerCase();
          final commands = devDeskCommands
              .where((command) => command.label.toLowerCase().contains(query))
              .toList(growable: false);
          return AlertDialog(
            title: const Text('Command palette'),
            content: Semantics(
              label: 'DevDesk command palette',
              explicitChildNodes: true,
              child: SizedBox(
                width: 520,
                height: 430,
                child: Column(
                  children: [
                    TextField(
                      controller: queryController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Search commands',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: commands.length,
                        itemBuilder: (context, index) {
                          final command = commands[index];
                          return ListTile(
                            leading: Icon(command.icon),
                            title: Text(command.label),
                            trailing: command.shortcut == null
                                ? null
                                : Text(command.shortcut!),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              devDeskNavigatorKey.currentState
                                  ?.pushNamed(command.route);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
  queryController.dispose();
}

Future<void> openDeveloperFileFromCommand() async {
  final context = devDeskNavigatorKey.currentContext;
  if (context == null) return;
  try {
    final document = await ExternalFileService.pickDeveloperFile();
    if (document == null || !context.mounted) return;
    if (document.isEnvLike) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open possible secrets file?'),
          content: Text(
            '"${document.name}" may contain credentials. Keep copied and exported content protected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open locally'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    final route = switch (document.kind) {
      DevFileKind.markdown => '/markdown',
      DevFileKind.json => '/json',
      DevFileKind.text => '/external-text',
      DevFileKind.apiCollection => '/api',
      DevFileKind.backup => '/settings',
      DevFileKind.unsupported => null,
    };
    if (route == null) {
      throw const ExternalFileException('Unsupported file type.');
    }
    devDeskNavigatorKey.currentState?.pushNamed(route, arguments: document);
  } on ExternalFileException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message)),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The file could not be opened safely.')),
    );
  }
}

void _replaceWith(String route) {
  devDeskNavigatorKey.currentState?.pushNamedAndRemoveUntil(
    route,
    (candidate) => false,
  );
}
