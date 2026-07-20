import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors/failure.dart';

/// Cooperative cancellation that is shared across connection, response read,
/// assertion, extraction, and persistence phases.
class OperationCancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelled.complete();
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw ApiFailure(
        'Request cancelled.',
        code: 'DD-API-CANCELLED',
        severity: FailureSeverity.info,
      );
    }
  }
}

class BoundedHttpResponse {
  final http.StreamedResponse streamedResponse;
  final Uint8List bytes;
  final String body;
  final bool isBinary;
  final String contentType;

  const BoundedHttpResponse({
    required this.streamedResponse,
    required this.bytes,
    required this.body,
    required this.isBinary,
    required this.contentType,
  });
}

/// Sends one request and reads it with independent connection, read-idle, and
/// total deadlines. The response is rejected before its configured byte limit
/// can be exceeded.
class BoundedHttpReader {
  BoundedHttpReader._();

  static const int defaultMaxResponseBytes = 5 * 1024 * 1024;
  static const Duration defaultConnectTimeout = Duration(seconds: 10);
  static const Duration defaultReadIdleTimeout = Duration(seconds: 10);

  static Future<BoundedHttpResponse> send({
    required http.Client client,
    required http.BaseRequest request,
    required Duration totalTimeout,
    Duration connectTimeout = defaultConnectTimeout,
    Duration readIdleTimeout = defaultReadIdleTimeout,
    int maxResponseBytes = defaultMaxResponseBytes,
    OperationCancellationToken? cancellationToken,
  }) async {
    if (totalTimeout <= Duration.zero) {
      throw ApiFailure(
        'Request timeout must be greater than zero.',
        code: 'DD-API-CONFIG',
        category: FailureCategory.validation,
        retryable: false,
      );
    }
    if (maxResponseBytes <= 0) {
      throw ApiFailure(
        'Response size limit must be greater than zero.',
        code: 'DD-API-CONFIG',
        category: FailureCategory.validation,
        retryable: false,
      );
    }

    final token = cancellationToken ?? OperationCancellationToken();
    final stopwatch = Stopwatch()..start();
    token.throwIfCancelled();

    final connectionBudget = _shorter(connectTimeout, totalTimeout);
    late http.StreamedResponse streamed;
    try {
      streamed = await _raceCancellation(
        client.send(request).timeout(connectionBudget),
        token,
      );
    } on TimeoutException {
      throw ApiFailure(
        'Connection timed out after ${connectionBudget.inSeconds} seconds.',
        code: 'DD-API-CONNECT-TIMEOUT',
      );
    }
    token.throwIfCancelled();

    final declaredLength = streamed.contentLength;
    if (declaredLength != null && declaredLength > maxResponseBytes) {
      throw ApiFailure(
        'Response is larger than the ${_formatBytes(maxResponseBytes)} safety limit.',
        code: 'DD-API-RESPONSE-LIMIT',
        retryable: false,
      );
    }

    final remaining = totalTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw ApiFailure(
        'Request exceeded the ${totalTimeout.inSeconds}-second total deadline.',
        code: 'DD-API-TOTAL-TIMEOUT',
      );
    }

    final bytes = await _readBounded(
      streamed.stream,
      token: token,
      maxResponseBytes: maxResponseBytes,
      idleTimeout: _shorter(readIdleTimeout, remaining),
      totalTimeout: remaining,
      totalConfiguredTimeout: totalTimeout,
    );
    token.throwIfCancelled();

    final contentType = streamed.headers.entries
            .where((entry) => entry.key.toLowerCase() == 'content-type')
            .map((entry) => entry.value)
            .firstOrNull ??
        '';
    final decoded = _decodeBody(bytes, contentType);
    return BoundedHttpResponse(
      streamedResponse: streamed,
      bytes: bytes,
      body: decoded.body,
      isBinary: decoded.isBinary,
      contentType: contentType,
    );
  }

  static Future<Uint8List> _readBounded(
    Stream<List<int>> stream, {
    required OperationCancellationToken token,
    required int maxResponseBytes,
    required Duration idleTimeout,
    required Duration totalTimeout,
    required Duration totalConfiguredTimeout,
  }) {
    final completer = Completer<Uint8List>();
    final builder = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? subscription;
    Timer? idleTimer;
    Timer? totalTimer;
    var count = 0;

    void cleanup() {
      idleTimer?.cancel();
      totalTimer?.cancel();
    }

    void fail(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted) return;
      cleanup();
      subscription?.cancel();
      completer.completeError(error, stackTrace);
    }

    void armIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(idleTimeout, () {
        fail(
          ApiFailure(
            'Response stalled for ${idleTimeout.inSeconds} seconds.',
            code: 'DD-API-READ-IDLE-TIMEOUT',
          ),
        );
      });
    }

    totalTimer = Timer(totalTimeout, () {
      fail(
        ApiFailure(
          'Request exceeded the ${totalConfiguredTimeout.inSeconds}-second total deadline.',
          code: 'DD-API-TOTAL-TIMEOUT',
        ),
      );
    });
    armIdleTimer();

    subscription = stream.listen(
      (chunk) {
        if (token.isCancelled) {
          fail(
            ApiFailure(
              'Request cancelled.',
              code: 'DD-API-CANCELLED',
              severity: FailureSeverity.info,
            ),
          );
          return;
        }
        count += chunk.length;
        if (count > maxResponseBytes) {
          fail(
            ApiFailure(
              'Response is larger than the ${_formatBytes(maxResponseBytes)} safety limit.',
              code: 'DD-API-RESPONSE-LIMIT',
              retryable: false,
            ),
          );
          return;
        }
        builder.add(chunk);
        armIdleTimer();
      },
      onError: (Object error, StackTrace stackTrace) {
        fail(
          ApiFailure(
            'Response stream failed safely.',
            code: 'DD-API-STREAM',
          ),
          stackTrace,
        );
      },
      onDone: () {
        if (completer.isCompleted) return;
        cleanup();
        if (token.isCancelled) {
          completer.completeError(
            ApiFailure(
              'Request cancelled.',
              code: 'DD-API-CANCELLED',
              severity: FailureSeverity.info,
            ),
          );
        } else {
          completer.complete(builder.takeBytes());
        }
      },
      cancelOnError: true,
    );

    token.whenCancelled.then((_) {
      fail(
        ApiFailure(
          'Request cancelled.',
          code: 'DD-API-CANCELLED',
          severity: FailureSeverity.info,
        ),
      );
    });
    return completer.future;
  }

  static Future<T> _raceCancellation<T>(
    Future<T> operation,
    OperationCancellationToken token,
  ) {
    return Future.any<T>([
      operation,
      token.whenCancelled.then<T>(
        (_) => throw ApiFailure(
          'Request cancelled.',
          code: 'DD-API-CANCELLED',
          severity: FailureSeverity.info,
        ),
      ),
    ]);
  }

  static ({String body, bool isBinary}) _decodeBody(
    Uint8List bytes,
    String contentType,
  ) {
    if (bytes.isEmpty) return (body: '', isBinary: false);
    final normalized = contentType.toLowerCase();
    final advertisedText = normalized.startsWith('text/') ||
        normalized.contains('json') ||
        normalized.contains('xml') ||
        normalized.contains('javascript') ||
        normalized.contains('x-www-form-urlencoded') ||
        normalized.contains('graphql');
    final hasUtfBom = bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;

    if (advertisedText || hasUtfBom || normalized.isEmpty) {
      try {
        return (body: utf8.decode(bytes), isBinary: false);
      } on FormatException {
        if (advertisedText || hasUtfBom) {
          return (
            body: utf8.decode(bytes, allowMalformed: true),
            isBinary: false,
          );
        }
      }
    }

    final previewLength = bytes.length < 768 ? bytes.length : 768;
    final preview = base64Encode(bytes.sublist(0, previewLength));
    final suffix = previewLength < bytes.length ? '…' : '';
    return (
      body:
          '[Binary response: ${_formatBytes(bytes.length)}]\nBase64 preview: $preview$suffix',
      isBinary: true,
    );
  }

  static Duration _shorter(Duration left, Duration right) {
    return left <= right ? left : right;
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes bytes';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
