/// Represents an HTTP response produced by the API tester.
class ApiResponse {
  final String method;
  final String url;
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final Duration duration;

  ApiResponse({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
      'durationMs': duration.inMilliseconds,
    };
  }

  factory ApiResponse.fromMap(Map<String, dynamic> map) {
    return ApiResponse(
      method: (map['method'] as String?) ?? 'GET',
      url: (map['url'] as String?) ?? '',
      statusCode: (map['statusCode'] as int?) ?? 0,
      headers: Map<String, String>.from((map['headers'] as Map?) ?? const {}),
      body: (map['body'] as String?) ?? '',
      duration: Duration(milliseconds: (map['durationMs'] as int?) ?? 0),
    );
  }
}
