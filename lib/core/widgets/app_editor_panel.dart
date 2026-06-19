import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'app_card.dart';

class AppEditorPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final String? subtitle;

  const AppEditorPanel({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AppCodeField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final ValueChanged<String>? onChanged;

  const AppCodeField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: expands ? null : minLines,
      maxLines: expands ? null : maxLines,
      expands: expands,
      onChanged: onChanged,
      style: AppTypography.mono(context),
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.codeBackground(context),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }
}
