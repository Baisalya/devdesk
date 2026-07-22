import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_card.dart';
import 'app_copy_button.dart';
import 'app_empty_state.dart';

class AppResultPanel extends StatelessWidget {
  final String title;
  final String? text;
  final Widget? child;
  final String emptyTitle;
  final String emptyMessage;
  final bool monospace;
  final List<Widget> actions;

  const AppResultPanel({
    super.key,
    required this.title,
    this.text,
    this.child,
    this.emptyTitle = 'No result yet',
    this.emptyMessage = 'Run the tool to see output here.',
    this.monospace = true,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelBody = child ??
              (text == null || text!.isEmpty
                  ? AppEmptyState(
                      icon: Icons.terminal,
                      title: emptyTitle,
                      message: emptyMessage,
                    )
                  : Container(
                      color: AppColors.codeBackground(context),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: SelectableText(
                          text!,
                          style: monospace
                              ? AppTypography.mono(context)
                              : Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ));
          if (constraints.hasBoundedHeight && constraints.maxHeight < 72) {
            return panelBody;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (actions.isNotEmpty || text != null)
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            children: [
                              ...actions,
                              if (text != null) AppCopyButton(value: text),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: panelBody),
            ],
          );
        },
      ),
    );
  }
}
