import 'package:flutter/material.dart';
import '../constants/tool_list.dart';

/// A specialized [AppBar] that automatically displays the tool name and
/// its description as a subtitle.
class AppToolAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Optional title to display instead of the tool name from [tools].
  final String? title;

  /// The route used to look up the [DevTool] for name and description.
  final String route;

  /// Optional actions to display in the [AppBar].
  final List<Widget>? actions;

  /// Optional leading widget.
  final Widget? leading;

  /// Whether to automatically imply the leading widget.
  final bool automaticallyImplyLeading;

  /// Optional bottom widget.
  final PreferredSizeWidget? bottom;

  const AppToolAppBar({
    super.key,
    this.title,
    required this.route,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // Find the tool by route. If not found, use a fallback.
    final tool = tools.firstWhere(
      (t) => t.route == route,
      orElse: () => tools.firstWhere(
        (t) => route.startsWith(t.route),
        orElse: () => const DevTool(
          name: 'Developer Tool',
          route: '',
          icon: Icons.code,
          description: '',
        ),
      ),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title ?? tool.name),
          if (tool.description.isNotEmpty)
            Text(
              tool.description,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}
