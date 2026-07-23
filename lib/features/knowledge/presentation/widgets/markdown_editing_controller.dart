import 'package:flutter/material.dart';

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  static final _syntax = RegExp(
    r'(^#{1,6}\s+.*$|^\s*[-*+]\s+\[[ xX]\]\s+.*$|```[^\n]*|`[^`\n]+`|\[\[[^\]]+\]\]|!?\[[^\]]*\]\([^\)]+\)|(?<!\w)#[A-Za-z][\w/-]*)',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _syntax.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final tokenStyle = token.startsWith('#') && token.contains(' ')
          ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)
          : token.startsWith('```') ||
                  (token.startsWith('`') && token.endsWith('`'))
              ? TextStyle(
                  color: scheme.tertiary,
                  backgroundColor: scheme.surfaceContainerHighest,
                )
              : token.startsWith('[[') || token.contains('](')
                  ? TextStyle(
                      color: scheme.secondary,
                      decoration: TextDecoration.underline,
                    )
                  : token.contains('[ ]') || token.contains('[x]')
                      ? TextStyle(color: scheme.primary)
                      : TextStyle(color: scheme.tertiary);
      spans.add(TextSpan(text: token, style: tokenStyle));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return TextSpan(style: style, children: spans);
  }

  void wrapSelection(String before, String after) {
    final selected =
        selection.isValid ? text.substring(selection.start, selection.end) : '';
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    value = value.copyWith(
      text: text.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
      composing: TextRange.empty,
    );
  }

  void insert(String valueToInsert) {
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    value = value.copyWith(
      text: text.replaceRange(start, end, valueToInsert),
      selection: TextSelection.collapsed(offset: start + valueToInsert.length),
      composing: TextRange.empty,
    );
  }
}
