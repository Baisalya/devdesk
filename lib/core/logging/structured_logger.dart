import '../errors/failure.dart';
import '../security/data_redactor.dart';

enum LogLevel { debug, info, warning, error }

class StructuredLogEvent {
  final String code;
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? correlationId;
  final Map<String, Object?> fields;

  StructuredLogEvent({
    required this.code,
    required this.level,
    required this.message,
    DateTime? timestamp,
    this.correlationId,
    Map<String, Object?> fields = const {},
  })  : timestamp = timestamp ?? DateTime.now().toUtc(),
        fields = _safeFields(fields);

  factory StructuredLogEvent.fromFailure(Failure failure) {
    return StructuredLogEvent(
      code: failure.code,
      level: switch (failure.severity) {
        FailureSeverity.info => LogLevel.info,
        FailureSeverity.warning => LogLevel.warning,
        FailureSeverity.error || FailureSeverity.critical => LogLevel.error,
      },
      message: failure.message,
      correlationId: failure.correlationId,
      fields: failure.toDiagnosticMap(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'code': code,
      'level': level.name,
      'message': DataRedactor.redactText(message),
      'timestamp': timestamp.toIso8601String(),
      if (correlationId != null) 'correlationId': correlationId,
      'fields': fields,
    };
  }

  static Map<String, Object?> _safeFields(Map<String, Object?> input) {
    final redacted = DataRedactor.deepRedact(input);
    if (redacted is! Map) return const {};
    return {
      for (final entry in redacted.entries)
        entry.key.toString(): _primitiveValue(entry.value),
    };
  }

  static Object? _primitiveValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Iterable) {
      return value.map(_primitiveValue).toList(growable: false);
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _primitiveValue(entry.value),
      };
    }
    return value.toString();
  }
}

abstract interface class StructuredLogSink {
  Future<void> write(StructuredLogEvent event);
}

class StructuredLogger {
  final StructuredLogSink sink;

  const StructuredLogger(this.sink);

  Future<void> record(StructuredLogEvent event) => sink.write(event);

  Future<void> recordFailure(Failure failure) {
    return record(StructuredLogEvent.fromFailure(failure));
  }
}

class InMemoryStructuredLogSink implements StructuredLogSink {
  final int capacity;
  final List<StructuredLogEvent> _events = [];

  InMemoryStructuredLogSink({this.capacity = 200});

  List<StructuredLogEvent> get events => List.unmodifiable(_events);

  @override
  Future<void> write(StructuredLogEvent event) async {
    if (capacity <= 0) return;
    _events.add(event);
    if (_events.length > capacity) {
      _events.removeRange(0, _events.length - capacity);
    }
  }
}
