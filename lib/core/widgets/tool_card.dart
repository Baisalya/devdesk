import 'package:flutter/material.dart';

import '../../core/constants/tool_list.dart';

/// A clickable card representing a [DevTool] on the dashboard.
class ToolCard extends StatelessWidget {
  final DevTool tool;
  final VoidCallback onTap;

  const ToolCard({super.key, required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 56, 8),
        leading: Icon(tool.icon),
        title: Text(tool.name),
        subtitle: Text(
          tool.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}
