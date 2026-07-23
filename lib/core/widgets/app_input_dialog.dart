import 'package:flutter/material.dart';

/// A reusable, stateful dialog that manages its own [TextEditingController].
///
/// This prevents "TextEditingController used after being disposed" errors
/// that can occur when a controller is disposed before the dialog's pop
/// animation completes.
class AppTextInputDialog extends StatefulWidget {
  final String title;
  final String? labelText;
  final String? hintText;
  final String? initialValue;
  final String actionLabel;
  final int? maxLength;
  final int maxLines;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AppTextInputDialog({
    super.key,
    required this.title,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.actionLabel = 'OK',
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = true,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  State<AppTextInputDialog> createState() => _AppTextInputDialogState();
}

class _AppTextInputDialogState extends State<AppTextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      Navigator.of(context).pop(value);
      widget.onSubmitted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        textInputAction: widget.textInputAction,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _handleSubmit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _handleSubmit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
