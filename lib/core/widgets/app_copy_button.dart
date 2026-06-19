import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
              await Clipboard.setData(ClipboardData(text: value!));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(feedback)),
              );
            },
    );
  }
}
