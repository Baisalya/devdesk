import 'dart:convert';

import '../models/api_request.dart';

class ApiCodeSnippets {
  static String curl(ApiRequest request) {
    request = request.sanitized();
    final buffer = StringBuffer('curl -X ${request.method.toUpperCase()}');
    for (final entry in request.headers.entries) {
      buffer.write(' -H ${_shellQuote('${entry.key}: ${entry.value}')}');
    }
    if ((request.body ?? '').isNotEmpty) {
      buffer.write(' --data ${_shellQuote(request.body!)}');
    }
    buffer.write(' ${_shellQuote(_urlWithQuery(request))}');
    return buffer.toString();
  }

  static String dartHttp(ApiRequest request) {
    request = request.sanitized();
    final method = request.method.toUpperCase();
    final buffer = StringBuffer()
      ..writeln("import 'package:http/http.dart' as http;")
      ..writeln()
      ..writeln('Future<http.Response> sendRequest() async {')
      ..writeln(
          "  final uri = Uri.parse(${_dartString(_urlWithQuery(request))});");
    if (request.headers.isNotEmpty) {
      buffer
        ..writeln('  final headers = <String, String>{')
        ..write(_dartMapEntries(request.headers))
        ..writeln('  };');
    } else {
      buffer.writeln('  final headers = <String, String>{};');
    }
    buffer
      ..writeln("  final request = http.Request('$method', uri);")
      ..writeln('  request.headers.addAll(headers);');
    if ((request.body ?? '').isNotEmpty) {
      buffer.writeln('  request.body = ${_dartString(request.body!)};');
    }
    buffer
      ..writeln('  final streamed = await request.send();')
      ..writeln('  return http.Response.fromStream(streamed);')
      ..writeln('}');
    return buffer.toString();
  }

  static String javascriptFetch(ApiRequest request) {
    request = request.sanitized();
    final options = <String, dynamic>{
      'method': request.method.toUpperCase(),
      if (request.headers.isNotEmpty) 'headers': request.headers,
      if ((request.body ?? '').isNotEmpty) 'body': request.body,
    };
    const encoder = JsonEncoder.withIndent('  ');
    return 'const response = await fetch('
        '${jsonEncode(_urlWithQuery(request))}, ${encoder.convert(options)});\n'
        'const text = await response.text();';
  }

  static String _urlWithQuery(ApiRequest request) {
    final uri = Uri.parse(request.url);
    if (request.queryParams.isEmpty) return uri.toString();
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...request.queryParams,
      },
    ).toString();
  }

  static String _shellQuote(String value) {
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  static String _dartString(String value) {
    return jsonEncode(value);
  }

  static String _dartMapEntries(Map<String, String> map) {
    final buffer = StringBuffer();
    for (final entry in map.entries) {
      buffer.writeln(
        '    ${_dartString(entry.key)}: ${_dartString(entry.value)},',
      );
    }
    return buffer.toString();
  }
}
