import 'package:flutter/material.dart';

import '../../../../../core/design/app_spacing.dart';
import '../../../../../core/widgets/app_card.dart';

class VaultToolbar extends StatelessWidget {
  final void Function(String prefix, {String suffix}) onInsert;
  final ValueChanged<int> onHeading;
  final VoidCallback onInsertToc;
  final VoidCallback onTogglePreview;
  final VoidCallback onInsertSnippet;
  final VoidCallback onSaveSelectionAsSnippet;
  final bool isPreviewMode;
  final bool showPreviewToggle;

  const VaultToolbar({
    super.key,
    required this.onInsert,
    required this.onHeading,
    required this.onInsertToc,
    required this.onTogglePreview,
    required this.onInsertSnippet,
    required this.onSaveSelectionAsSnippet,
    this.isPreviewMode = false,
    this.showPreviewToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (showPreviewToggle)
                _ToolbarButton(
                  icon: isPreviewMode ? Icons.edit : Icons.remove_red_eye,
                  label: isPreviewMode ? 'Edit' : 'Preview',
                  onPressed: onTogglePreview,
                  color: Theme.of(context).colorScheme.primary,
                ),
              for (var level = 1; level <= 6; level++)
                _TextToolbarButton(
                  label: 'H$level',
                  onPressed: () => onHeading(level),
                ),
              _ToolbarButton(
                icon: Icons.format_bold,
                label: 'Bold',
                onPressed: () => onInsert('**', suffix: '**'),
              ),
              _ToolbarButton(
                icon: Icons.format_italic,
                label: 'Italic',
                onPressed: () => onInsert('*', suffix: '*'),
              ),
              _ToolbarButton(
                icon: Icons.format_strikethrough,
                label: 'Strike',
                onPressed: () => onInsert('~~', suffix: '~~'),
              ),
              _ToolbarButton(
                icon: Icons.code,
                label: 'Inline code',
                onPressed: () => onInsert('`', suffix: '`'),
              ),
              _ToolbarButton(
                icon: Icons.integration_instructions,
                label: 'Code block',
                onPressed: () => onInsert('```\n', suffix: '\n```'),
              ),
              _ToolbarButton(
                icon: Icons.format_quote,
                label: 'Quote',
                onPressed: () => onInsert('> '),
              ),
              _ToolbarButton(
                icon: Icons.link,
                label: 'Link',
                onPressed: () =>
                    onInsert('[', suffix: '](https://example.com)'),
              ),
              _ToolbarButton(
                icon: Icons.image,
                label: 'Image',
                onPressed: () => onInsert('![alt](', suffix: ')'),
              ),
              _ToolbarButton(
                icon: Icons.format_list_bulleted,
                label: 'Bullet list',
                onPressed: () => onInsert('- '),
              ),
              _ToolbarButton(
                icon: Icons.format_list_numbered,
                label: 'Number list',
                onPressed: () => onInsert('1. '),
              ),
              _ToolbarButton(
                icon: Icons.check_box,
                label: 'Checklist',
                onPressed: () => onInsert('- [ ] '),
              ),
              _ToolbarButton(
                icon: Icons.table_chart,
                label: 'Table',
                onPressed: () => onInsert(
                  '\n| Column 1 | Column 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\n',
                ),
              ),
              _ToolbarButton(
                icon: Icons.horizontal_rule,
                label: 'Horizontal rule',
                onPressed: () => onInsert('\n---\n'),
              ),
              _ToolbarButton(
                icon: Icons.format_list_numbered_rtl,
                label: 'Insert table of contents',
                onPressed: onInsertToc,
              ),
              _ToolbarButton(
                icon: Icons.snippet_folder,
                label: 'Insert saved snippet',
                onPressed: onInsertSnippet,
              ),
              _ToolbarButton(
                icon: Icons.bookmark_add,
                label: 'Save selection as snippet',
                onPressed: onSaveSelectionAsSnippet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }
}

class _TextToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TextToolbarButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: TextButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
