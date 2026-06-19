import 'package:uuid/uuid.dart';

/// Utilities for generating UUIDs.
class UuidUtils {
  static final Uuid _uuid = const Uuid();

  /// Generates a version‑4 UUID.
  static String generate() => _uuid.v4();

  /// Generates multiple version-4 UUIDs.
  static List<String> generateMany(int count) {
    if (count < 1 || count > 1000) {
      throw ArgumentError('Count must be between 1 and 1000.');
    }
    return List<String>.generate(count, (_) => _uuid.v4());
  }
}
