/// Base failure class used across the application.
///
/// Instead of throwing strings or raw exceptions, use [Failure] or one of its
/// subclasses to represent domain or infrastructure errors. This makes error
/// handling in the UI easier and allows passing along context.
abstract class Failure {
  final String message;

  Failure(this.message);

  @override
  String toString() => message;
}

/// Represents a JSON parsing or formatting error.
class JsonFailure extends Failure {
  JsonFailure(super.message);
}

/// Represents an invalid regular expression.
class RegexFailure extends Failure {
  RegexFailure(super.message);
}

/// Represents invalid Base64 input.
class Base64Failure extends Failure {
  Base64Failure(super.message);
}

/// Represents invalid URL encoding/decoding input.
class UrlFailure extends Failure {
  UrlFailure(super.message);
}

/// Represents invalid timestamp conversion.
class TimestampFailure extends Failure {
  TimestampFailure(super.message);
}

/// Represents invalid JWT tokens.
class JwtFailure extends Failure {
  JwtFailure(super.message);
}

/// Represents general API request failures.
class ApiFailure extends Failure {
  final int? statusCode;
  ApiFailure(super.message, {this.statusCode});
}
