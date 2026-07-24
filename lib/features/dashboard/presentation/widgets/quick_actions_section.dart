import 'package:flutter/material.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import 'dashboard_theme_extension.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onOpenFile;
  final VoidCallback onOpenApi;
  final VoidCallback onOpenJson;
  final VoidCallback onOpenMarkdown;
  final VoidCallback onOpenSnippet;

  const QuickActionsSection({
    super.key,
    required this.onOpenFile,
    required this.onOpenApi,
    required this.onOpenJson,
    required this.onOpenMarkdown,
    required this.onOpenSnippet,
  });

  @override
  Widget build(BuildContext context) {
    final dashboardColors = DashboardThemeExtension.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columnCount =
            width >= 1200 ? 5 : (width >= 800 ? 3 : (width >= 500 ? 2 : 1));

        final data = [
          (
            icon: Icons.folder_open_rounded,
            title: 'Open File',
            subtitle: 'Open a local developer file securely.',
            accentColor: dashboardColors.workspaceAccent,
            onTap: onOpenFile,
          ),
          (
            icon: Icons.bolt_rounded,
            title: 'API Request',
            subtitle: 'Build, send and inspect HTTP requests.',
            accentColor: dashboardColors.apiAccent,
            onTap: onOpenApi,
          ),
          (
            icon: Icons.data_object_rounded,
            title: 'Format JSON',
            subtitle: 'Validate, format and inspect JSON data.',
            accentColor: dashboardColors.dataAccent,
            onTap: onOpenJson,
          ),
          (
            icon: Icons.article_outlined,
            title: 'Markdown',
            subtitle: 'Create or edit Markdown documents.',
            accentColor: dashboardColors.markdownAccent,
            onTap: onOpenMarkdown,
          ),
          (
            icon: Icons.code_rounded,
            title: 'Code Snippet',
            subtitle: 'Save reusable commands and code.',
            accentColor: dashboardColors.codeAccent,
            onTap: onOpenSnippet,
          ),
        ];

        // On mobile (1 column), avoid GridView entirely for 100% height flexibility
        if (columnCount == 1) {
          return Column(
            children: [
              for (final item in data)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _QuickActionCard(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    accentColor: item.accentColor,
                    onTap: item.onTap,
                  ),
                ),
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            // Use a safe aspect ratio for 2+ columns
            childAspectRatio: columnCount == 2 ? 2.5 : 2.0,
          ),
          itemBuilder: (context, index) {
            final item = data[index];
            return _QuickActionCard(
              icon: item.icon,
              title: item.title,
              subtitle: item.subtitle,
              accentColor: item.accentColor,
              onTap: item.onTap,
            );
          },
        );
      },
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AppCard(
          onTap: widget.onTap,
          padding: EdgeInsets.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: _isHovered
                  ? LinearGradient(
                      colors: [
                        widget.accentColor.withValues(alpha: 0.15),
                        widget.accentColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: _isHovered
                  ? Border.all(
                      color: widget.accentColor.withValues(alpha: 0.5),
                      width: 1)
                  : null,
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
