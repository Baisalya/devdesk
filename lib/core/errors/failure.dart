/// Stable severity used by DevDesk domain and infrastructure failures.
enum FailureSeverity { info, warning, error, critical }

/// Technical category safe to include in support diagnostics.
enum FailureCategory {
  validation,
  parsing,
  network,
  storage,
  fileSystem,
  permission,
  git,
  database,
  migration,
  searchIndex,
  importExport,
  security,
  platform,
  unknown,
}

/// Base typed failure used across the application.
///
/// [message] is intentionally safe for user display. Raw exception details,
/// payloads, URLs, paths, credentials, and personal data must not be placed in
/// it. [code], [category], [severity], [retryable], and [correlationId] are safe
/// diagnostic metadata and remain stable enough for support workflows.
abstract class Failure implements Exception {
  final String message;
  final String code;
  final FailureSeverity severity;
  final FailureCategory category;
  final bool retryable;
  final String correlationId;

  Failure(
    this.message, {
    required this.code,
    this.severity = FailureSeverity.error,
    this.category = FailureCategory.unknown,
    this.retryable = false,
    String? correlationId,
  }) : correlationId = correlationId ?? _FailureIds.next();

  Map<String, Object> toDiagnosticMap() {
    return {
      'code': code,
      'severity': severity.name,
      'category': category.name,
      'retryable': retryable,
      'correlationId': correlationId,
    };
  }

  @override
  String toString() => message;
}

class _FailureIds {
  static int _counter = 0;

  static String next() {
    _counter = (_counter + 1) & 0xFFFFF;
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'DD-${micros.toRadixString(36)}-${_counter.toRadixString(36)}';
  }
}

/// Represents a JSON parsing, validation, or formatting error.
class JsonFailure extends Failure {
  JsonFailure(super.message)
      : super(
          code: 'DD-JSON-001',
          category: FailureCategory.validation,
        );
}

/// Represents an invalid or unsafe regular expression.
class RegexFailure extends Failure {
  RegexFailure(super.message)
      : super(
          code: 'DD-REGEX-001',
          category: FailureCategory.validation,
        );
}

/// Represents invalid Base64 input.
class Base64Failure extends Failure {
  Base64Failure(super.message)
      : super(
          code: 'DD-BASE64-001',
          category: FailureCategory.validation,
        );
}

/// Represents invalid URL encoding/decoding input.
class UrlFailure extends Failure {
  UrlFailure(super.message)
      : super(
          code: 'DD-URL-001',
          category: FailureCategory.validation,
        );
}

/// Represents invalid timestamp conversion.
class TimestampFailure extends Failure {
  TimestampFailure(super.message)
      : super(
          code: 'DD-TIME-001',
          category: FailureCategory.validation,
        );
}

/// Represents invalid JWT input. DevDesk decodes but does not verify signatures.
class JwtFailure extends Failure {
  JwtFailure(super.message)
      : super(
          code: 'DD-JWT-001',
          category: FailureCategory.validation,
        );
}

/// Represents API request and response failures.
class ApiFailure extends Failure {
  final int? statusCode;

  ApiFailure(
    super.message, {
    this.statusCode,
    super.code = 'DD-API-001',
    super.severity = FailureSeverity.error,
    super.category = FailureCategory.network,
    super.retryable = true,
    super.correlationId,
  });
}

class ValidationFailure extends Failure {
  ValidationFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.warning,
    super.retryable = false,
    super.correlationId,
  }) : super(category: FailureCategory.validation);
}

class ParsingFailure extends Failure {
  ParsingFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.error,
    super.retryable = false,
    super.correlationId,
  }) : super(category: FailureCategory.parsing);
}

class StorageFailure extends Failure {
  StorageFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.error,
    super.retryable = false,
    super.correlationId,
  }) : super(category: FailureCategory.storage);
}

class FileAccessFailure extends Failure {
  FileAccessFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.error,
    super.category = FailureCategory.fileSystem,
    super.retryable = false,
    super.correlationId,
  });
}

class PermissionFailure extends Failure {
  PermissionFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.warning,
    super.retryable = true,
    super.correlationId,
  }) : super(category: FailureCategory.permission);
}

class PlatformCapabilityFailure extends Failure {
  PlatformCapabilityFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.info,
    super.retryable = false,
    super.correlationId,
  }) : super(category: FailureCategory.platform);
}

class GitFailure extends Failure {
  GitFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.error,
    super.retryable = false,
    super.correlationId,
  }) : super(category: FailureCategory.git);
}

class MigrationFailure extends Failure {
  MigrationFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.critical,
    super.retryable = true,
    super.correlationId,
  }) : super(category: FailureCategory.migration);
}

class SearchIndexFailure extends Failure {
  SearchIndexFailure(
    super.message, {
    required super.code,
    super.severity = FailureSeverity.warning,
    super.retryable = true,
    super.correlationId,
  }) : super(category: FailureCategory.searchIndex);
}
