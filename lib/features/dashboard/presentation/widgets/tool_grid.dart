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

        // On mobile/narrow screens or when content wraps significantly,
        // a fixed aspect ratio or even null mainAxisExtent in a GridView
        // can lead to overflows if the height is not perfectly managed.
        // For 100% responsiveness on mobile, we use a Column for 1 column
        // layout or a Grid with a safe height.

        if (crossAxisCount == 1) {
          return Column(
            children: [
              for (final tool in tools)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ToolCard(
                    tool: tool,
                    favourite: favourites.contains(tool.route),
                    onTap: () => onOpenTool(tool.route),
                    onFavouritePressed: () => onToggleFavourite(tool.route),
                    dense: true,
                  ),
                ),
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: tools.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            // We use a slightly taller ratio to ensure multi-line text fits
            // without ever overflowing on Android system fonts.
            childAspectRatio: crossAxisCount == 2 ? 2.2 : 1.8,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            final isFav = favourites.contains(tool.route);
            return ToolCard(
              tool: tool,
              favourite: isFav,
              onTap: () => onOpenTool(tool.route),
              onFavouritePressed: () => onToggleFavourite(tool.route),
              dense: crossAxisCount > 2,
            );
          },
        );
      },
    );
  }
}
