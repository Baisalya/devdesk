import 'dart:convert';

import '../errors/failure.dart';

/// Conservative, sink-oriented redaction for persisted data, clipboard text,
/// support diagnostics, and user-facing errors.
class DataRedactor {
  DataRedactor._();

  static const String replacement = '[REDACTED]';

  static final RegExp _sensitiveName = RegExp(
    r'(?:^|[_\-\s])(?:authorization|proxy-authorization|cookie|set-cookie|token|access[_\-]?token|refresh[_\-]?token|api[_\-]?key|secret|password|passwd|private[_\-]?key|client[_\-]?secret|session|credential)(?:$|[_\-\s])',
    caseSensitive: false,
  );

  static final RegExp _assignment = RegExp(
    r'''(authorization|proxy-authorization|cookie|set-cookie|token|access[_-]?token|refresh[_-]?token|api[_-]?key|secret|password|passwd|private[_-]?key|client[_-]?secret|session|credential)(\s*[=:]\s*)([^\s,;\}\]]+|"[^"]*"|'[^']*')''',
    caseSensitive: false,
  );

  static final RegExp _bearer = RegExp(
    r'\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]{4,}',
    caseSensitive: false,
  );

  static final RegExp _email = RegExp(
    r'(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?![A-Za-z0-9._%+-])',
  );

  static final RegExp _windowsPath = RegExp(
    r'(?:[A-Z]:\\|\\\\)[^\r\n\t"<>|]+',
    caseSensitive: false,
  );

  static final RegExp _unixPath = RegExp(
    r'(?<![A-Za-z0-9])/(?:Users|home|var|tmp|data|storage|sdcard)/[^\r\n\t"<>|]+',
  );

  static bool isSensitiveName(String name) {
    final normalized =
        name.trim().replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1_$2');
    return _sensitiveName.hasMatch(normalized) ||
        _sensitiveName.hasMatch('_${normalized}_');
  }

  static String redactText(
    String value, {
    bool redactEmails = false,
    bool redactPaths = false,
  }) {
    // Remove complete HTTP auth schemes before the generic assignment rule.
    // Otherwise `Authorization: Bearer token` would redact only the word
    // `Bearer` and leave the credential behind after the whitespace.
    var result = value.replaceAllMapped(
      _bearer,
      (match) => '${match.group(1)} $replacement',
    );
    result = result.replaceAllMapped(_assignment, (match) {
      return '${match.group(1)}${match.group(2)}$replacement';
    });
    if (redactEmails) result = result.replaceAll(_email, replacement);
    if (redactPaths) {
      result = result.replaceAll(_windowsPath, replacement);
      result = result.replaceAll(_unixPath, replacement);
    }
    return result;
  }

  static String redactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || (!uri.hasScheme && !value.startsWith('/'))) {
      return redactText(value);
    }
    final pairs = <String>[];
    uri.queryParametersAll.forEach((name, values) {
      for (final item in values) {
        final safe = isSensitiveName(name) ? replacement : redactText(item);
        pairs.add(
            '${Uri.encodeQueryComponent(name)}=${Uri.encodeQueryComponent(safe)}');
      }
    });
    return uri.replace(query: pairs.join('&')).toString();
  }

  static Map<String, String> redactHeaders(Map<String, String> headers) {
    return {
      for (final entry in headers.entries)
        entry.key:
            isSensitiveName(entry.key) ? replacement : redactText(entry.value),
    };
  }

  static dynamic deepRedact(dynamic value, {String? key}) {
    if (key != null && isSensitiveName(key)) return replacement;
    if (value is Map) {
      return value.map<String, dynamic>((rawKey, rawValue) {
        final name = rawKey.toString();
        return MapEntry(name, deepRedact(rawValue, key: name));
      });
    }
    if (value is Iterable) {
      return value.map((item) => deepRedact(item)).toList();
    }
    if (value is String) {
      if (key != null && key.toLowerCase().contains('url')) {
        return redactUrl(value);
      }
      return redactText(value);
    }
    return value;
  }

  static String redactJsonText(String value) {
    try {
      final decoded = jsonDecode(value);
      return jsonEncode(deepRedact(decoded));
    } catch (_) {
      return redactText(value);
    }
  }

  static String safeError(Object error) {
    if (error is Failure) {
      final safeMessage = redactText(
        error.message,
        redactEmails: true,
        redactPaths: true,
      );
      final bounded = safeMessage.length <= 420
          ? safeMessage
          : '${safeMessage.substring(0, 420)}…';
      return '$bounded [${error.code}; ref ${error.correlationId}]';
    }
    final text = redactText(
      error.toString(),
      redactEmails: true,
      redactPaths: true,
    );
    return text.length <= 500 ? text : '${text.substring(0, 500)}…';
  }
}
