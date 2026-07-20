import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/core/network/bounded_http.dart';

class _StreamClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      handler;
  bool closed = false;

  _StreamClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  test('reads a delayed streamed response within independent deadlines',
      () async {
    final controller = StreamController<List<int>>();
    final client = _StreamClient(
      (_) async => http.StreamedResponse(
        controller.stream,
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final future = BoundedHttpReader.send(
      client: client,
      request: http.Request('GET', Uri.parse('https://example.test')),
      totalTimeout: const Duration(seconds: 2),
      connectTimeout: const Duration(milliseconds: 200),
      readIdleTimeout: const Duration(milliseconds: 200),
      maxResponseBytes: 64,
    );
    controller.add(Uint8List.fromList('{"ok":'.codeUnits));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    controller.add(Uint8List.fromList('true}'.codeUnits));
    await controller.close();

    final response = await future;
    expect(response.body, '{"ok":true}');
    expect(response.isBinary, isFalse);
  });

  test('rejects a stalled body after headers', () async {
    final controller = StreamController<List<int>>();
    final client = _StreamClient(
      (_) async => http.StreamedResponse(controller.stream, 200),
    );

    await expectLater(
      BoundedHttpReader.send(
        client: client,
        request: http.Request('GET', Uri.parse('https://example.test')),
        totalTimeout: const Duration(seconds: 1),
        readIdleTimeout: const Duration(milliseconds: 20),
      ),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.message,
          'message',
          contains('stalled'),
        ),
      ),
    );
    await controller.close();
  });

  test('rejects oversized streamed responses before buffering all bytes',
      () async {
    final client = _StreamClient(
      (_) async => http.StreamedResponse(
        Stream<List<int>>.fromIterable([
          List<int>.filled(8, 1),
          List<int>.filled(8, 2),
        ]),
        200,
      ),
    );

    await expectLater(
      BoundedHttpReader.send(
        client: client,
        request: http.Request('GET', Uri.parse('https://example.test')),
        totalTimeout: const Duration(seconds: 1),
        maxResponseBytes: 10,
      ),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('treats non-text bytes as binary with bounded preview', () async {
    final bytes = Uint8List.fromList([0, 159, 146, 150, 255]);
    final client = _StreamClient(
      (_) async => http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        200,
        headers: {'content-type': 'application/octet-stream'},
      ),
    );

    final response = await BoundedHttpReader.send(
      client: client,
      request: http.Request('GET', Uri.parse('https://example.test')),
      totalTimeout: const Duration(seconds: 1),
    );
    expect(response.isBinary, isTrue);
    expect(response.body, contains('Binary response'));
  });

  test('cancellation is terminal during response reading', () async {
    final listening = Completer<void>();
    final controller = StreamController<List<int>>(
      onListen: listening.complete,
    );
    final token = OperationCancellationToken();
    final client = _StreamClient(
      (_) async => http.StreamedResponse(controller.stream, 200),
    );
    final future = BoundedHttpReader.send(
      client: client,
      request: http.Request('GET', Uri.parse('https://example.test')),
      totalTimeout: const Duration(seconds: 1),
      cancellationToken: token,
    );
    await listening.future;
    token.cancel();

    await expectLater(future, throwsA(isA<ApiFailure>()));
    await controller.close();
  });
}
