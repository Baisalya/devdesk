import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/failure.dart';
import '../../../core/network/bounded_http.dart';
import '../../../core/security/data_redactor.dart';
import '../models/api_workspace_models.dart';
import 'api_workspace_utils.dart';

class ApiWorkspaceExecutor {
  static Future<ApiResponseRecord> execute({
    required ApiPreparedRequest prepared,
    required http.Client client,
    String? responseId,
    OperationCancellationToken? cancellationToken,
    int maxResponseBytes = BoundedHttpReader.defaultMaxResponseBytes,
    Duration connectTimeout = BoundedHttpReader.defaultConnectTimeout,
    Duration readIdleTimeout = BoundedHttpReader.defaultReadIdleTimeout,
  }) async {
    final uri = _buildUri(prepared);
    final token = cancellationToken ?? OperationCancellationToken();
    token.throwIfCancelled();
    final stopwatch = Stopwatch()..start();
    try {
      final request = _prepareHttpRequest(prepared, uri);
      final bounded = await BoundedHttpReader.send(
        client: client,
        request: request,
        totalTimeout: prepared.timeout,
        connectTimeout: connectTimeout,
        readIdleTimeout: readIdleTimeout,
        maxResponseBytes: maxResponseBytes,
        cancellationToken: token,
      );
      token.throwIfCancelled();
      stopwatch.stop();
      return ApiResponseRecord(
        id: responseId ?? ApiWorkspaceIds.newId('response'),
        method: prepared.method,
        url: uri.toString(),
        statusCode: bounded.streamedResponse.statusCode,
        headers: bounded.streamedResponse.headers,
        body: bounded.body,
        durationMs: stopwatch.elapsedMilliseconds,
        sizeBytes: bounded.bytes.length,
        isBinary: bounded.isBinary,
        contentType: bounded.contentType,
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      throw ApiFailure(
        'Request failed safely: ${DataRedactor.safeError(error)}',
        code: 'DD-API-SEND',
      );
    }
  }

  static http.BaseRequest _prepareHttpRequest(
    ApiPreparedRequest prepared,
    Uri uri,
  ) {
    if (prepared.bodyType == ApiRequestBodyType.multipartFormData) {
      if (prepared.method == 'GET' || prepared.method == 'HEAD') {
        throw ApiFailure(
          'GET and HEAD requests cannot send multipart data.',
          code: 'DD-API-BODY-METHOD',
          category: FailureCategory.validation,
          retryable: false,
        );
      }
      return http.MultipartRequest(prepared.method, uri)
        ..headers.addAll(prepared.headers)
        ..fields.addAll(prepared.formFields)
        ..followRedirects = prepared.followRedirects;
    }

    final request = http.Request(prepared.method, uri)
      ..headers.addAll(prepared.headers)
      ..followRedirects = prepared.followRedirects;
    if (prepared.method == 'GET' || prepared.method == 'HEAD') return request;

    switch (prepared.bodyType) {
      case ApiRequestBodyType.none:
        break;
      case ApiRequestBodyType.rawJson:
        final raw = prepared.body ?? '';
        if (raw.isNotEmpty) {
          try {
            jsonDecode(raw);
          } on FormatException {
            throw ApiFailure(
              'JSON request body is not valid JSON.',
              code: 'DD-API-BODY-JSON',
              category: FailureCategory.validation,
              retryable: false,
            );
          }
          request.body = raw;
        }
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'application/json; charset=utf-8',
        );
        break;
      case ApiRequestBodyType.rawText:
        request.body = prepared.body ?? '';
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'text/plain; charset=utf-8',
        );
        break;
      case ApiRequestBodyType.formUrlEncoded:
        request.bodyFields = prepared.formFields;
        break;
      case ApiRequestBodyType.multipartFormData:
        throw StateError('Multipart requests are prepared above.');
    }
    return request;
  }

  static Uri _buildUri(ApiPreparedRequest prepared) {
    if (prepared.url.trim().isEmpty) {
      throw ApiFailure(
        'URL is required.',
        code: 'DD-API-URL',
        category: FailureCategory.validation,
        retryable: false,
      );
    }
    final uri = Uri.tryParse(prepared.url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ApiFailure(
        'Enter a valid http or https URL.',
        code: 'DD-API-URL',
        category: FailureCategory.validation,
        retryable: false,
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw ApiFailure(
        'Credentials in URLs are not supported. Use Auth instead.',
        code: 'DD-API-URL-CREDENTIALS',
        category: FailureCategory.security,
        retryable: false,
      );
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
