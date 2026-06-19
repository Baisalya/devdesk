import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/failure.dart';
import '../models/api_workspace_models.dart';
import 'api_workspace_utils.dart';

class ApiWorkspaceExecutor {
  static Future<ApiResponseRecord> execute({
    required ApiPreparedRequest prepared,
    required http.Client client,
    String? responseId,
  }) async {
    final uri = _buildUri(prepared);
    final stopwatch = Stopwatch()..start();
    try {
      final streamed = prepared.bodyType == ApiRequestBodyType.multipartFormData
          ? await _sendMultipart(prepared, uri, client)
          : await _sendStandard(prepared, uri, client);
      final response = await http.Response.fromStream(streamed);
      stopwatch.stop();
      final bodyBytes = utf8.encode(response.body).length;
      return ApiResponseRecord(
        id: responseId ?? ApiWorkspaceIds.newId('response'),
        method: prepared.method,
        url: uri.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        durationMs: stopwatch.elapsedMilliseconds,
        sizeBytes: bodyBytes,
      );
    } on TimeoutException {
      throw ApiFailure(
        'Request timed out after ${prepared.timeout.inSeconds} seconds',
      );
    } on ApiFailure {
      rethrow;
    } catch (e) {
      throw ApiFailure('Request failed: $e');
    }
  }

  static Future<http.StreamedResponse> _sendStandard(
    ApiPreparedRequest prepared,
    Uri uri,
    http.Client client,
  ) {
    final request = http.Request(prepared.method, uri)
      ..headers.addAll(prepared.headers)
      ..followRedirects = prepared.followRedirects;
    if ((prepared.body ?? '').isNotEmpty &&
        prepared.method != 'GET' &&
        prepared.method != 'HEAD') {
      request.body = prepared.body!;
      if (prepared.bodyType == ApiRequestBodyType.formUrlEncoded) {
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'application/x-www-form-urlencoded',
        );
      }
      if (prepared.bodyType == ApiRequestBodyType.rawJson) {
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'application/json',
        );
      }
    }
    return client.send(request).timeout(prepared.timeout);
  }

  static Future<http.StreamedResponse> _sendMultipart(
    ApiPreparedRequest prepared,
    Uri uri,
    http.Client client,
  ) {
    final request = http.MultipartRequest(prepared.method, uri)
      ..headers.addAll(prepared.headers)
      ..fields.addAll(prepared.formFields)
      ..followRedirects = prepared.followRedirects;
    return client.send(request).timeout(prepared.timeout);
  }

  static Uri _buildUri(ApiPreparedRequest prepared) {
    if (prepared.url.trim().isEmpty) {
      throw ApiFailure('URL is required');
    }
    final uri = Uri.tryParse(prepared.url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ApiFailure('Enter a valid http or https URL');
    }
    if (prepared.queryParams.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...prepared.queryParams,
      },
    );
  }
}

class ApiWorkspaceIds {
  static int _counter = 0;

  static String newId(String prefix) {
    _counter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }
}
