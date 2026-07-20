import 'dart:convert';

import '../models/api_request.dart';

class ApiCollectionPreview {
  final int requestCount;
  final bool hasSensitiveHeaders;

  const ApiCollectionPreview({
    required this.requestCount,
    required this.hasSensitiveHeaders,
  });
}

class ApiCollectionUtils {
  static const type = 'devdesk_api_collection';
  static const version = 1;

  static Map<String, dynamic> exportCollection(
    Iterable<ApiRequest> requests, {
    bool includeSecrets = false,
  }) {
    // Portable collection files are never a protected secret boundary.
    final sanitized = requests.map((request) => request.sanitized());
    return {
      'type': type,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'requests': sanitized.map((request) => request.toMap()).toList(),
    };
  }

  static Map<String, dynamic> decodeCollectionText(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('Collection root must be a JSON object.');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Collection must be valid JSON.');
    }
  }

  static ApiCollectionPreview preview(Map<String, dynamic> document) {
    final requests = _requestMaps(document);
    final parsed = requests.map(_requestFromMap).toList();
    return ApiCollectionPreview(
      requestCount: parsed.length,
      hasSensitiveHeaders: parsed.any((request) => request.hasSensitiveHeaders),
    );
  }

  static List<ApiRequest> importRequests(
    Map<String, dynamic> document, {
    bool includeSecrets = false,
  }) {
    final requests = _requestMaps(document).map(_requestFromMap).toList();
    return includeSecrets
        ? requests
        : requests.map((request) => request.withoutSensitiveHeaders()).toList();
  }

  static List<Map<String, dynamic>> _requestMaps(
      Map<String, dynamic> document) {
    final requests = document['requests'];
    if (requests is! List || requests.isEmpty) {
      throw const FormatException('API collection must contain requests.');
    }
    return [
      for (final item in requests)
        if (item is Map) Map<String, dynamic>.from(item) else _invalidRequest(),
    ];
  }

  static ApiRequest _requestFromMap(Map<String, dynamic> map) {
    final method = (map['method'] as String?)?.toUpperCase();
    final url = map['url'] as String?;
    const allowedMethods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};
    if (method == null || !allowedMethods.contains(method)) {
      throw const FormatException('API request has an unsupported method.');
    }
    if (url == null || url.trim().isEmpty) {
      throw const FormatException('API request URL is required.');
    }
    return ApiRequest.fromMap({
      ...map,
      'method': method,
      'url': url,
    });
  }

  static Map<String, dynamic> _invalidRequest() {
    throw const FormatException('API collection request must be an object.');
  }
}
