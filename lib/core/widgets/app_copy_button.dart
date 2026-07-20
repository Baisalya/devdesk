import 'package:flutter/material.dart';

import '../security/safe_clipboard.dart';

class AppCopyButton extends StatelessWidget {
  final String? value;
  final String tooltip;
  final String feedback;

  const AppCopyButton({
    super.key,
    required this.value,
    this.tooltip = 'Copy',
    this.feedback = 'Copied to clipboard',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: const Icon(Icons.copy),
      tooltip: tooltip,
      onPressed: value == null
          ? null
          : () async {
              final redacted = await SafeClipboard.copy(value!);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      redacted ? '$feedback (secrets redacted)' : feedback),
                ),
              );
            },
    );
  }
}
