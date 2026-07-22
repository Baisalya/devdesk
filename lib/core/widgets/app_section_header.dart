import 'package:flutter/material.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null)
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (trailing != null && constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 8),
              trailing!,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            if (trailing != null) trailing!,
          ],
        );
      },
    );
  }
}
