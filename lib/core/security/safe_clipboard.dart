import 'package:flutter/services.dart';

import '../utils/secret_utils.dart';
import 'data_redactor.dart';

enum SafeClipboardContent { plainText, json, url }

/// Copies text through the same conservative redaction boundary used by
/// persistence and exports. The raw value remains visible/selectable in the UI;
/// explicit copy actions do not place likely credentials into OS clipboard
/// history by default.
class SafeClipboard {
  SafeClipboard._();

  static Future<bool> copy(
    String value, {
    SafeClipboardContent content = SafeClipboardContent.plainText,
    bool forceRedaction = false,
    String? fileName,
  }) async {
    final shouldRedact =
        forceRedaction || SecretUtils.containsSecret(value, fileName: fileName);
    final safeValue = shouldRedact ? _redact(value, content) : value;
    await Clipboard.setData(ClipboardData(text: safeValue));
    return safeValue != value;
  }

  static String _redact(String value, SafeClipboardContent content) {
    return switch (content) {
      SafeClipboardContent.json => DataRedactor.redactJsonText(value),
      SafeClipboardContent.url => DataRedactor.redactUrl(value),
      SafeClipboardContent.plainText => DataRedactor.redactText(value),
    };
  }
}
