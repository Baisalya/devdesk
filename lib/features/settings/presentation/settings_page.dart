import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/devdesk_semantic_colors.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../app/theme/theme_preferences.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/security/data_redactor.dart';
import '../../../core/security/safe_clipboard.dart';
import '../../../core/storage/backup_utils.dart';
import '../../../core/widgets/app_tool_app_bar.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../api_tester/provider/api_provider.dart';
import '../../api_tester/provider/api_workspace_provider.dart';
import '../../dashboard/provider/tool_providers.dart';
import '../../markdown/provider/markdown_provider.dart';
import '../../markdown/vault/provider/vault_provider.dart';
import '../../pro/presentation/plan_status_card.dart';
import '../../privacy/presentation/privacy_policy_page.dart';
import '../../privacy/provider/privacy_acceptance_provider.dart';
import '../../rating/provider/rating_service.dart';
import '../../snippets/provider/snippets_provider.dart';

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
    final appearance = ref.watch(themePreferencesProvider);
    final ratingService = ref.read(ratingServiceProvider);
    return Scaffold(
      appBar: const AppToolAppBar(route: '/settings'),
      body: ListView(
        padding: AppSpacing.page(context),
        children: [
          _SettingsSection(
            title: 'Appearance',
            subtitle:
                'Choose brightness, color, contrast, and workspace density.',
            children: [
              _AppearanceControls(preferences: appearance),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'Data backup',
            subtitle: 'Export or restore local data with preview-first import.',
            children: [
              _SettingsTile(
                icon: Icons.download,
                title: 'Export Backup File',
                subtitle:
                    'Save local app data as JSON; protected secrets are excluded.',
                onTap: _exportBackupFile,
              ),
              _SettingsTile(
                icon: Icons.copy,
                title: 'Copy Backup JSON',
                subtitle:
                    'Copy a redacted backup; protected secrets are excluded.',
                onTap: _exportBackupClipboard,
              ),
              _SettingsTile(
                icon: Icons.upload_file,
                title: 'Import Backup File',
                subtitle: 'Preview a DevDesk backup before applying it.',
                onTap: _importBackupFile,
              ),
              _SettingsTile(
                icon: Icons.paste,
                title: 'Import Backup from Text',
                subtitle: 'Paste backup JSON and preview before import.',
                onTap: _importBackupText,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'File handling',
            subtitle:
                'External files stay local and are only read after you choose them.',
            children: const [
              _SettingsTile(
                icon: Icons.folder_open,
                title: 'External files',
                subtitle:
                    'Markdown, JSON, text, API collections and backups open into their matching tools.',
              ),
              _SettingsTile(
                icon: Icons.save_as,
                title: 'Save As safety',
                subtitle:
                    'External edits use explicit Save or Save As flows with overwrite confirmation.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'API tester safety',
            subtitle:
                'Secrets are protected by default when saving request history.',
            children: const [
              _SettingsTile(
                icon: Icons.security,
                title: 'Sensitive headers',
                subtitle:
                    'History, reports, snippets, exports and backups redact secret-like values. Workspace secrets use platform protection where available.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _SettingsSection(
            title: 'Plans',
            subtitle:
                'Current tools stay free; future services remain disabled until store readiness.',
            children: [PlanStatusCard()],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'Privacy & security',
            subtitle: 'Local-first behavior with no analytics or backend.',
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle:
                    'Read the complete policy and user-initiated network disclosures.',
                onTap: _showPrivacy,
              ),
              _SettingsTile(
                icon: Icons.delete_forever,
                title: 'Clear All Data',
                subtitle: 'Deletes all stored notes, API history and settings.',
                destructive: true,
                onTap: _clearAllData,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsSection(
            title: 'About',
            subtitle: 'DevDesk release information.',
            children: [
              if (ratingService.isSupportedPlatform)
                _SettingsTile(
                  icon: Icons.star_rate_rounded,
                  title: 'Rate DevDesk',
                  subtitle: ratingService.destinationDescription,
                  onTap: () async {
                    await ratingService.showRateDialog(context);
                  },
                ),
              _SettingsTile(
                icon: Icons.info,
                title: 'About DevDesk',
                subtitle: 'Version 1.0.0',
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
      ref.read(apiWorkspaceProvider.notifier).cancelRequest();
      cancelApiRequest(ref);
      try {
        await LocalStorage.clearAll();
        await ref.read(ratingServiceProvider).clearData();
      } catch (error) {
        _showSnack(
          'Local data could not be cleared safely: ${DataRedactor.safeError(error)}',
        );
        return;
      }
      _invalidateDataProviders();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
      );
      _showSnack('All local data and protected secrets were cleared');
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
    await SafeClipboard.copy(
      export,
      content: SafeClipboardContent.json,
      forceRedaction: true,
    );
    _showSnack('Backup copied with secret values excluded');
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
      _showSnack('Backup import failed safely: ${DataRedactor.safeError(e)}');
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
      ref.read(apiWorkspaceProvider.notifier).cancelRequest();
      cancelApiRequest(ref);
      await LocalStorage.importAll(document, replace: replace);
      _invalidateDataProviders();
      _showSnack(replace ? 'Backup restored' : 'Backup merged');
    } on FormatException catch (e) {
      _showSnack('Invalid backup: ${e.message}');
    } catch (e) {
      _showSnack('Backup import failed safely: ${DataRedactor.safeError(e)}');
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
                    Text('API workspaces: ${preview.apiWorkspacesCount}'),
                    Text(
                      'Workspace history: ${preview.apiWorkspaceHistoryCount}',
                    ),
                    Text(
                      'Runner reports: ${preview.apiWorkspaceReportsCount}',
                    ),
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

  void _invalidateDataProviders() {
    ref
      ..invalidate(apiWorkspaceProvider)
      ..invalidate(apiHistoryProvider)
      ..invalidate(apiEnvironmentsProvider)
      ..invalidate(dashboardPrefsProvider)
      ..invalidate(markdownFilesProvider)
      ..invalidate(markdownTextProvider)
      ..invalidate(vaultNotesProvider)
      ..invalidate(selectedNoteIdProvider)
      ..invalidate(openedNoteIdsProvider)
      ..invalidate(snippetsProvider)
      ..invalidate(snippetsSearchProvider)
      ..invalidate(themePreferencesProvider)
      ..invalidate(privacyAcceptanceProvider);
  }

  void _showPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyPage(),
      ),
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

class _AppearanceControls extends ConsumerWidget {
  final ThemePreferences preferences;

  const _AppearanceControls({required this.preferences});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(themePreferencesProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final semantic = DevDeskSemanticColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AppearanceLabel(
          title: 'Brightness',
          subtitle: 'Follow Windows or Android, or keep one mode.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _AdaptiveThemeChoice<ThemeMode>(
          value: preferences.brightnessMode,
          options: const [
            _ThemeChoice(
              value: ThemeMode.system,
              label: 'System',
              icon: Icons.brightness_auto,
            ),
            _ThemeChoice(
              value: ThemeMode.light,
              label: 'Light',
              icon: Icons.light_mode,
            ),
            _ThemeChoice(
              value: ThemeMode.dark,
              label: 'Dark',
              icon: Icons.dark_mode,
            ),
          ],
          onChanged: notifier.setBrightnessMode,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _AppearanceLabel(
          title: 'Color palette',
          subtitle:
              'Every core palette is free and includes light and dark surfaces.',
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 3 : 1;
            final gap = AppSpacing.sm * (columns - 1);
            final cardWidth = (constraints.maxWidth - gap) / columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final palette in AppPalette.values)
                  SizedBox(
                    width: cardWidth,
                    child: _PaletteCard(
                      palette: palette,
                      selected: preferences.palette == palette,
                      onTap: () => notifier.setPalette(palette),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const _AppearanceLabel(
          title: 'Contrast',
          subtitle:
              'System follows accessibility settings; High increases separation.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _AdaptiveThemeChoice<AppContrastMode>(
          value: preferences.contrastMode,
          options: const [
            _ThemeChoice(
              value: AppContrastMode.system,
              label: 'System',
              icon: Icons.settings_brightness,
            ),
            _ThemeChoice(
              value: AppContrastMode.standard,
              label: 'Standard',
              icon: Icons.contrast,
            ),
            _ThemeChoice(
              value: AppContrastMode.high,
              label: 'High',
              icon: Icons.tonality,
            ),
          ],
          onChanged: notifier.setContrastMode,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _AppearanceLabel(
          title: 'Workspace density',
          subtitle:
              'Comfortable favors touch; Compact fits more on larger screens.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _AdaptiveThemeChoice<AppDensityMode>(
          value: preferences.densityMode,
          options: const [
            _ThemeChoice(
              value: AppDensityMode.comfortable,
              label: 'Comfortable',
              icon: Icons.touch_app,
            ),
            _ThemeChoice(
              value: AppDensityMode.compact,
              label: 'Compact',
              icon: Icons.density_small,
            ),
          ],
          onChanged: notifier.setDensityMode,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _AppearanceLabel(
          title: 'Code preview',
          subtitle: 'Developer surfaces adapt to the selected palette.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: semantic.codeSurface,
            borderRadius: AppRadius.small,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: colors.onSurface,
                  ),
              children: [
                TextSpan(
                  text: 'final ',
                  style: TextStyle(color: colors.tertiary),
                ),
                const TextSpan(text: 'palette = '),
                TextSpan(
                  text: "'${preferences.palette.label}';",
                  style: TextStyle(color: semantic.success),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: notifier.reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset appearance'),
          ),
        ),
      ],
    );
  }
}

class _AppearanceLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AppearanceLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ThemeChoice<T> {
  final T value;
  final String label;
  final IconData icon;

  const _ThemeChoice({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _AdaptiveThemeChoice<T> extends StatelessWidget {
  final T value;
  final List<_ThemeChoice<T>> options;
  final ValueChanged<T> onChanged;

  const _AdaptiveThemeChoice({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: [
              for (final option in options)
                DropdownMenuItem<T>(
                  value: option.value,
                  child: Row(
                    children: [
                      Icon(option.icon),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(child: Text(option.label)),
                    ],
                  ),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          );
        }
        return SegmentedButton<T>(
          segments: [
            for (final option in options)
              ButtonSegment<T>(
                value: option.value,
                label: Text(option.label),
                icon: Icon(option.icon),
              ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        );
      },
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} theme',
      child: Material(
        color: selected ? colors.secondaryContainer : colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.small,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: SizedBox(
                    height: 46,
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ColoredBox(color: palette.lightSurface),
                            ),
                            Expanded(
                              child: ColoredBox(color: palette.darkSurface),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ColorDot(color: palette.seed),
                              _ColorDot(color: palette.secondaryPreview),
                              _ColorDot(color: palette.tertiaryPreview),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        palette.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: colors.primary, size: 20),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  palette.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.destructive(context)
        : Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: destructive
            ? TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              )
            : null,
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}
