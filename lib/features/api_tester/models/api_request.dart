/// Represents an HTTP request made by the API tester.
class ApiRequest {
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> queryParams;
  final String? body;
  final DateTime timestamp;

  ApiRequest({
    required this.method,
    required this.url,
    this.headers = const {},
    this.queryParams = const {},
    this.body,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ApiRequest copyWith({
    String? method,
    String? url,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    String? body,
    DateTime? timestamp,
  }) {
    return ApiRequest(
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      queryParams: queryParams ?? this.queryParams,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'url': url,
      'headers': headers,
      'queryParams': queryParams,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  bool get hasSensitiveHeaders {
    return headers.keys.any(isSensitiveHeader);
  }

  ApiRequest withoutSensitiveHeaders() {
    return copyWith(
      headers: Map.fromEntries(
        headers.entries.where((entry) => !isSensitiveHeader(entry.key)),
      ),
    );
  }

  factory ApiRequest.fromMap(Map<String, dynamic> map) {
    return ApiRequest(
      method: (map['method'] as String?) ?? 'GET',
      url: (map['url'] as String?) ?? '',
      headers: Map<String, String>.from((map['headers'] as Map?) ?? const {}),
      queryParams:
          Map<String, String>.from((map['queryParams'] as Map?) ?? const {}),
      body: map['body'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static bool isSensitiveHeader(String key) {
    final normalized = key.toLowerCase().replaceAll('-', '');
    return normalized == 'authorization' ||
        normalized == 'proxyauthorization' ||
        normalized.contains('apikey') ||
        normalized.contains('token') ||
        normalized.contains('secret');
  }

  @override
  bool operator ==(Object other) {
    return other is ApiRequest &&
        other.method == method &&
        other.url == url &&
        _mapsEqual(other.headers, headers) &&
        _mapsEqual(other.queryParams, queryParams) &&
        other.body == body;
  }

  @override
  int get hashCode => Object.hash(
        method,
        url,
        Object.hashAll(_sortedEntryHashes(headers)),
        Object.hashAll(
          _sortedEntryHashes(queryParams),
        ),
        body,
      );

  static bool _mapsEqual(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  static List<int> _sortedEntryHashes(Map<String, String> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [for (final entry in entries) Object.hash(entry.key, entry.value)];
  }
}
