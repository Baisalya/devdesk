/// Utilities for detecting and masking secrets in text.
class SecretUtils {
  static const List<String> _secretKeywords = [
    'API_KEY',
    'TOKEN',
    'SECRET',
    'PASSWORD',
    'AUTHORIZATION',
    'PRIVATE_KEY',
    'CLIENT_SECRET',
    'ACCESS_KEY',
    'DATABASE_URL',
    'CONNECTION_STRING',
  ];

  static final RegExp _genericSecretPattern = RegExp(
    r'(?:api_key|token|secret|password|authorization|private_key|client_secret|access_key)["' "'" r']?\s*[:=]\s*["' "'" r']?([a-zA-Z0-9_\-\.\/]{8,})["' "'" r']?',
    caseSensitive: false,
  );

  /// Returns true if the given [text] or [fileName] likely contains a secret.
  static bool containsSecret(String text, {String? fileName}) {
    if (fileName != null) {
      final lowerName = fileName.toLowerCase();
      if (lowerName == '.env' || lowerName.endsWith('.env') || lowerName.contains('.env.')) {
        return true;
      }
    }

    final upperText = text.toUpperCase();
    for (final keyword in _secretKeywords) {
      if (upperText.contains(keyword)) {
        return true;
      }
    }

    return _genericSecretPattern.hasMatch(text);
  }

  /// Masks potential secrets in the given [text].
  static String maskSecrets(String text) {
    return text.replaceAllMapped(_genericSecretPattern, (match) {
      final fullMatch = match.group(0)!;
      final secretValue = match.group(1)!;
      final maskedValue = '*' * 8;
      return fullMatch.replaceFirst(secretValue, maskedValue);
    });
  }

  /// Checks if a file name indicates a sensitive file.
  static bool isSensitiveFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower == '.env' || 
           lower.endsWith('.pem') || 
           lower.endsWith('.key') || 
           lower.endsWith('.p12') ||
           lower.endsWith('.jks');
  }
}
