import 'package:flutter/material.dart';

import '../../../../core/constants/tool_list.dart';
import '../../../../core/design/app_breakpoints.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/tool_card.dart';

class ToolGrid extends StatelessWidget {
  final List<DevTool> tools;
  final Set<String> favourites;
  final ValueChanged<String> onOpenTool;
  final ValueChanged<String> onToggleFavourite;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ToolGrid({
    super.key,
    required this.tools,
    required this.favourites,
    required this.onOpenTool,
    required this.onToggleFavourite,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1600
            ? 4
            : width >= 900
                ? 3
                : width >= AppBreakpoints.compact
                    ? 2
                    : 1;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final narrow = AppBreakpoints.isNarrow(width);
        final mainAxisExtent = switch (crossAxisCount) {
          1 when narrow => 72.0 + ((textScale - 1).clamp(0, 1) * 24),
          1 => 104.0 + ((textScale - 1).clamp(0, 1) * 36),
          2 => 120.0 + ((textScale - 1).clamp(0, 1) * 36),
          _ => 104.0 + ((textScale - 1).clamp(0, 1) * 24),
        };
        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: tools.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            final isFav = favourites.contains(tool.route);
            return ToolCard(
              tool: tool,
              favourite: isFav,
              onTap: () => onOpenTool(tool.route),
              onFavouritePressed: () => onToggleFavourite(tool.route),
              dense: crossAxisCount > 2 || narrow,
            );
          },
        );
      },
    );
  }
}
