import 'dart:convert';
import 'dart:math';

import '../models/api_request.dart';
import '../models/api_variable.dart';
import '../models/api_workspace_models.dart';

class ApiVariableResolution {
  final String original;
  final String resolved;
  final List<String> missingVariables;

  const ApiVariableResolution({
    required this.original,
    required this.resolved,
    required this.missingVariables,
  });

  bool get hasMissing => missingVariables.isNotEmpty;
}

class ApiWorkspaceVariables {
  static final RegExp _variablePattern =
      RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_.-]*)\s*\}\}');

  static Map<String, String> merge({
    Iterable<ApiVariable> workspace = const [],
    Iterable<ApiVariable> collection = const [],
    Iterable<ApiVariable> environment = const [],
    Map<String, String> environmentMap = const {},
    Map<String, String> temporary = const {},
    Iterable<ApiVariable> request = const [],
  }) {
    final values = <String, String>{};
    void addVariables(Iterable<ApiVariable> variables) {
      for (final variable in variables) {
        final key = variable.key.trim();
        if (variable.enabled && key.isNotEmpty) {
          values[key] = variable.value;
        }
      }
    }

    addVariables(workspace);
    addVariables(collection);
    addVariables(environment);
    for (final entry in environmentMap.entries) {
      if (entry.key.trim().isNotEmpty) values[entry.key.trim()] = entry.value;
    }
    values.addAll(temporary);
    addVariables(request);
    return values;
  }

  static ApiVariableResolution resolve(
    String input,
    Map<String, String> variables,
  ) {
    final missing = <String>{};
    final resolved = input.replaceAllMapped(_variablePattern, (match) {
      final key = match.group(1)!.trim();
      if (!variables.containsKey(key)) {
        missing.add(key);
        return match.group(0)!;
      }
      return variables[key]!;
    });
    return ApiVariableResolution(
      original: input,
      resolved: resolved,
      missingVariables: missing.toList()..sort(),
    );
  }

  static List<String> missingVariables(
    Iterable<String> values,
    Map<String, String> variables,
  ) {
    final missing = <String>{};
    for (final value in values) {
      missing.addAll(resolve(value, variables).missingVariables);
    }
    return missing.toList()..sort();
  }
}

class ApiPreparedRequest {
  final ApiRequestItem source;
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> queryParams;
  final ApiRequestBodyType bodyType;
  final String? body;
  final Map<String, String> formFields;
  final Duration timeout;
  final bool followRedirects;
  final List<String> unresolvedVariables;

  const ApiPreparedRequest({
    required this.source,
    required this.method,
    required this.url,
    required this.headers,
    required this.queryParams,
    required this.bodyType,
    required this.body,
    required this.formFields,
    required this.timeout,
    required this.followRedirects,
    required this.unresolvedVariables,
  });

  bool get hasUnresolvedVariables => unresolvedVariables.isNotEmpty;

  ApiRequest toLegacyRequest() {
    return ApiRequest(
      method: method,
      url: url,
      headers: headers,
      queryParams: queryParams,
      body: body,
      followRedirects: followRedirects,
    );
  }
}

class ApiWorkspaceRequestComposer {
  static ApiPreparedRequest prepare({
    required ApiWorkspace workspace,
    required ApiCollection? collection,
    required ApiFolder? folder,
    required ApiRequestItem request,
    required Map<String, String> temporaryVariables,
  }) {
    final environment = workspace.activeEnvironment;
    final collectionVariables = [
      if (collection != null) ...collection.variables,
      if (folder != null) ...folder.variables,
    ];
    final variables = ApiWorkspaceVariables.merge(
      workspace: workspace.variables,
      collection: collectionVariables,
      environment: environment?.variables ?? const [],
      environmentMap: environment?.variableMap ?? const {},
      temporary: temporaryVariables,
      request: request.variables,
    );

    final missing = <String>{};
    String resolve(String value) {
      final resolution = ApiWorkspaceVariables.resolve(value, variables);
      missing.addAll(resolution.missingVariables);
      return resolution.resolved;
    }

    final resolvedHeaders = {
      for (final entry in request.headers.entries)
        resolve(entry.key): resolve(entry.value),
    };
    final resolvedQuery = {
      for (final entry in request.queryParams.entries)
        resolve(entry.key): resolve(entry.value),
    };
    final resolvedAuth = ApiAuthResolver.resolveAuth(
      workspaceAuth: workspace.auth,
      collectionAuth: collection?.auth,
      folderAuth: folder?.auth,
      requestAuth: request.auth,
      resolve: resolve,
    );
    ApiAuthResolver.applyAuth(
      auth: resolvedAuth,
      headers: resolvedHeaders,
      queryParams: resolvedQuery,
    );

    final body = _resolveBody(request.body, resolve);
    return ApiPreparedRequest(
      source: request,
      method: request.method.toUpperCase(),
      url: resolve(request.url),
      headers: resolvedHeaders,
      queryParams: resolvedQuery,
      bodyType: body.type,
      body: body.raw.isEmpty ? null : body.raw,
      formFields: body.formFields,
      timeout: Duration(milliseconds: request.timeoutMs),
      followRedirects: request.followRedirects,
      unresolvedVariables: missing.toList()..sort(),
    );
  }

  static ApiRequestBody _resolveBody(
    ApiRequestBody body,
    String Function(String value) resolve,
  ) {
    if (body.type == ApiRequestBodyType.formUrlEncoded ||
        body.type == ApiRequestBodyType.multipartFormData) {
      return body.copyWith(
        formFields: {
          for (final entry in body.formFields.entries)
            resolve(entry.key): resolve(entry.value),
        },
      );
    }
    return body.copyWith(raw: resolve(body.raw));
  }
}

class ApiAuthResolver {
  static ApiAuthConfig effectiveAuth({
    required ApiAuthConfig workspaceAuth,
    ApiAuthConfig? collectionAuth,
    ApiAuthConfig? folderAuth,
    required ApiAuthConfig requestAuth,
  }) {
    if (requestAuth.type != ApiAuthType.inherit) return requestAuth;
    if (folderAuth != null && folderAuth.type != ApiAuthType.inherit) {
      return folderAuth;
    }
    if (collectionAuth != null && collectionAuth.type != ApiAuthType.inherit) {
      return collectionAuth;
    }
    if (workspaceAuth.type != ApiAuthType.inherit) return workspaceAuth;
    return const ApiAuthConfig.noAuth();
  }

  static ApiAuthConfig resolveAuth({
    required ApiAuthConfig workspaceAuth,
    ApiAuthConfig? collectionAuth,
    ApiAuthConfig? folderAuth,
    required ApiAuthConfig requestAuth,
    required String Function(String value) resolve,
  }) {
    final auth = effectiveAuth(
      workspaceAuth: workspaceAuth,
      collectionAuth: collectionAuth,
      folderAuth: folderAuth,
      requestAuth: requestAuth,
    );
    return auth.copyWith(
      token: resolve(auth.token),
      username: resolve(auth.username),
      password: resolve(auth.password),
      apiKeyName: resolve(auth.apiKeyName),
      apiKeyValue: resolve(auth.apiKeyValue),
    );
  }

  static void applyAuth({
    required ApiAuthConfig auth,
    required Map<String, String> headers,
    required Map<String, String> queryParams,
  }) {
    switch (auth.type) {
      case ApiAuthType.inherit:
      case ApiAuthType.noAuth:
        return;
      case ApiAuthType.bearerToken:
        if (auth.token.trim().isNotEmpty) {
          headers['Authorization'] = 'Bearer ${auth.token.trim()}';
        }
        return;
      case ApiAuthType.basicAuth:
        final raw = '${auth.username}:${auth.password}';
        headers['Authorization'] = 'Basic ${base64Encode(utf8.encode(raw))}';
        return;
      case ApiAuthType.apiKeyHeader:
        if (auth.apiKeyName.trim().isNotEmpty) {
          headers[auth.apiKeyName.trim()] = auth.apiKeyValue;
        }
        return;
      case ApiAuthType.apiKeyQuery:
        if (auth.apiKeyName.trim().isNotEmpty) {
          queryParams[auth.apiKeyName.trim()] = auth.apiKeyValue;
        }
        return;
    }
  }
}

class ApiJsonBodyTools {
  static String format(String input) {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(input));
  }

  static String minify(String input) {
    return jsonEncode(jsonDecode(input));
  }

  static String? validate(String input) {
    if (input.trim().isEmpty) return null;
    try {
      jsonDecode(input);
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}

class ApiJsonPath {
  static Object? read(String body, String path) {
    final decoded = jsonDecode(body);
    return readDecoded(decoded, path);
  }

  static Object? readDecoded(Object? decoded, String path) {
    var current = decoded;
    var clean = path.trim();
    if (clean.startsWith('json.')) clean = clean.substring(5);
    if (clean.startsWith(r'$.')) clean = clean.substring(2);
    if (clean == r'$') return current;
    if (clean.isEmpty) return current;
    for (final segment in clean.split('.')) {
      if (segment.isEmpty) continue;
      final keyMatch = RegExp(r'^([A-Za-z0-9_-]+)').firstMatch(segment);
      if (keyMatch != null) {
        final key = keyMatch.group(1)!;
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          return null;
        }
      }
      final indexes = RegExp(r'\[(\d+)\]').allMatches(segment);
      for (final match in indexes) {
        final index = int.parse(match.group(1)!);
        if (current is List && index >= 0 && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      }
    }
    return current;
  }
}

class ApiAssertionEvaluator {
  static List<ApiAssertionResult> evaluate(
    List<ApiAssertion> assertions,
    ApiResponseRecord response,
  ) {
    return [
      for (final assertion in assertions)
        if (assertion.enabled) evaluateOne(assertion, response),
    ];
  }

  static ApiAssertionResult evaluateOne(
    ApiAssertion assertion,
    ApiResponseRecord response,
  ) {
    bool passed = false;
    String message = '';
    try {
      switch (assertion.type) {
        case ApiAssertionType.statusCodeEquals:
          final expected = int.tryParse(assertion.expected.trim());
          passed = response.statusCode == expected;
          message = 'Expected status ${assertion.expected}, got '
              '${response.statusCode}.';
          break;
        case ApiAssertionType.responseTimeLessThan:
          final expected = int.tryParse(assertion.expected.trim());
          passed = expected != null && response.durationMs < expected;
          message = 'Expected response time < ${assertion.expected} ms, got '
              '${response.durationMs} ms.';
          break;
        case ApiAssertionType.jsonPathExists:
          final value = ApiJsonPath.read(response.body, assertion.target);
          passed = value != null;
          message = passed
              ? '${assertion.target} exists.'
              : '${assertion.target} was not found.';
          break;
        case ApiAssertionType.jsonPathEquals:
          final value = ApiJsonPath.read(response.body, assertion.target);
          passed = value?.toString() == assertion.expected;
          message = 'Expected ${assertion.target} to equal '
              '"${assertion.expected}", got "${value ?? 'null'}".';
          break;
        case ApiAssertionType.headerExists:
          final exists = response.headers.keys.any(
            (key) => key.toLowerCase() == assertion.target.toLowerCase(),
          );
          passed = exists;
          message = exists
              ? 'Header ${assertion.target} exists.'
              : 'Header ${assertion.target} was not found.';
          break;
        case ApiAssertionType.bodyContains:
          passed = response.body.contains(assertion.expected);
          message = passed
              ? 'Body contains "${assertion.expected}".'
              : 'Body does not contain "${assertion.expected}".';
          break;
      }
    } catch (e) {
      passed = false;
      message = e.toString();
    }
    return ApiAssertionResult(
      assertionId: assertion.id,
      name: assertion.name.isEmpty ? assertion.type.name : assertion.name,
      passed: passed,
      message: message,
    );
  }
}

class ApiExtractionEvaluator {
  static const int maxRegexBodyBytes = 100 * 1024;
  static const int maxRegexLength = 240;

  static List<ApiExtractionResult> extract(
    List<ApiExtractionRule> rules,
    ApiResponseRecord response,
  ) {
    return [
      for (final rule in rules)
        if (rule.enabled) extractOne(rule, response),
    ];
  }

  static ApiExtractionResult extractOne(
    ApiExtractionRule rule,
    ApiResponseRecord response,
  ) {
    try {
      if (rule.variableName.trim().isEmpty) {
        return _failure(rule, 'Variable name is required.');
      }
      final value = switch (rule.source) {
        ApiExtractionSource.jsonPath =>
          ApiJsonPath.read(response.body, rule.expression)?.toString(),
        ApiExtractionSource.header => _headerValue(response, rule.expression),
        ApiExtractionSource.regexBody => _regexValue(response.body, rule),
      };
      if (value == null) return _failure(rule, 'No value matched.');
      return ApiExtractionResult(
        ruleId: rule.id,
        variableName: rule.variableName.trim(),
        value: value,
        isSecret: rule.isSecret,
        success: true,
        message: 'Extracted ${rule.variableName}.',
      );
    } catch (e) {
      return _failure(rule, e.toString());
    }
  }

  static String? _headerValue(ApiResponseRecord response, String header) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == header.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  static String? _regexValue(String body, ApiExtractionRule rule) {
    if (rule.expression.length > maxRegexLength) {
      throw const FormatException('Regex is too long for safe extraction.');
    }
    final capped = body.substring(0, min(body.length, maxRegexBodyBytes));
    final match = RegExp(rule.expression).firstMatch(capped);
    if (match == null) return null;
    return match.groupCount >= 1 ? match.group(1) : match.group(0);
  }

  static ApiExtractionResult _failure(ApiExtractionRule rule, String message) {
    return ApiExtractionResult(
      ruleId: rule.id,
      variableName: rule.variableName,
      value: '',
      isSecret: rule.isSecret,
      success: false,
      message: message,
    );
  }
}

class ApiWorkspaceImportPreview {
  final int collectionsCount;
  final int foldersCount;
  final int requestsCount;
  final int environmentsCount;
  final int secretsCount;
  final String sourceType;

  const ApiWorkspaceImportPreview({
    required this.collectionsCount,
    required this.foldersCount,
    required this.requestsCount,
    required this.environmentsCount,
    required this.secretsCount,
    required this.sourceType,
  });

  bool get hasSecrets => secretsCount > 0;
}

class ApiWorkspaceImportExport {
  static const workspaceType = 'devdesk_api_workspace';
  static const collectionType = 'devdesk_api_collection_v2';
  static const version = 1;

  static Map<String, dynamic> exportWorkspace(
    ApiWorkspace workspace, {
    bool includeSecrets = false,
  }) {
    return {
      'type': workspaceType,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'workspace': workspace.toMap(includeSecrets: includeSecrets),
    };
  }

  static Map<String, dynamic> exportCollection(
    ApiCollection collection, {
    bool includeSecrets = false,
  }) {
    return {
      'type': collectionType,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'collection': collection.toMap(includeSecrets: includeSecrets),
    };
  }

  static Map<String, dynamic> decodeJsonText(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('Import root must be a JSON object.');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Import file must be valid JSON.');
    }
  }

  static ApiWorkspaceImportPreview preview(Map<String, dynamic> document) {
    final workspace = _workspaceFromDocument(document, includeSecrets: true);
    return ApiWorkspaceImportPreview(
      collectionsCount: workspace.collections.length,
      foldersCount: workspace.folderCount,
      requestsCount: workspace.requestCount,
      environmentsCount: workspace.environments.length,
      secretsCount: _secretCount(workspace),
      sourceType: _sourceType(document),
    );
  }

  static ApiWorkspace importWorkspace(
    Map<String, dynamic> document, {
    bool includeSecrets = false,
    String? fallbackId,
  }) {
    final workspace = _workspaceFromDocument(
      document,
      includeSecrets: includeSecrets,
    );
    if (workspace.id.isEmpty && fallbackId != null) {
      return workspace.copyWith(id: fallbackId);
    }
    return workspace;
  }

  static ApiCollection importCollection(
    Map<String, dynamic> document, {
    bool includeSecrets = false,
    required String fallbackId,
  }) {
    if (document['type'] == collectionType && document['collection'] is Map) {
      final collection = ApiCollection.fromMap(
        Map<String, dynamic>.from(document['collection'] as Map),
      );
      return includeSecrets ? collection : collection.sanitized();
    }
    final workspace = _workspaceFromDocument(
      document,
      includeSecrets: includeSecrets,
      fallbackId: fallbackId,
    );
    if (workspace.collections.isEmpty) {
      throw const FormatException('No API collection found.');
    }
    return workspace.collections.first;
  }

  static ApiWorkspace _workspaceFromDocument(
    Map<String, dynamic> document, {
    required bool includeSecrets,
    String? fallbackId,
  }) {
    ApiWorkspace workspace;
    if (document['type'] == workspaceType && document['workspace'] is Map) {
      workspace = ApiWorkspace.fromMap(
        Map<String, dynamic>.from(document['workspace'] as Map),
      );
    } else if (document['type'] == collectionType &&
        document['collection'] is Map) {
      final collection = ApiCollection.fromMap(
        Map<String, dynamic>.from(document['collection'] as Map),
      );
      workspace = ApiWorkspace(
        id: fallbackId ?? '',
        name: collection.name,
        collections: [collection],
      );
    } else if (_looksLikePostman(document)) {
      workspace = _postmanWorkspace(document, fallbackId: fallbackId ?? '');
    } else if (document['collections'] is List || document['name'] is String) {
      workspace = ApiWorkspace.fromMap(document);
    } else if (document['requests'] is List) {
      workspace = _legacyCollectionWorkspace(document, fallbackId ?? '');
    } else {
      throw const FormatException('Unsupported API import document.');
    }
    return includeSecrets ? workspace : workspace.sanitized();
  }

  static bool _looksLikePostman(Map<String, dynamic> document) {
    final info = document['info'];
    return info is Map && document['item'] is List;
  }

  static ApiWorkspace _postmanWorkspace(
    Map<String, dynamic> document, {
    required String fallbackId,
  }) {
    final info = Map<String, dynamic>.from(document['info'] as Map);
    final collection = ApiCollection(
      id: '$fallbackId-collection',
      name: (info['name'] as String?) ?? 'Postman Collection',
      folders: [
        for (final item in document['item'] as List)
          if (item is Map && item['item'] is List)
            _postmanFolder(Map<String, dynamic>.from(item), fallbackId),
      ],
      requests: [
        for (final item in document['item'] as List)
          if (item is Map && item['request'] is Map)
            _postmanRequest(Map<String, dynamic>.from(item), fallbackId),
      ],
    );
    return ApiWorkspace(
      id: fallbackId,
      name: collection.name,
      collections: [collection],
    );
  }

  static ApiFolder _postmanFolder(Map<String, dynamic> item, String prefix) {
    final id = '$prefix-folder-${item['name'] ?? 'folder'}';
    return ApiFolder(
      id: id,
      name: (item['name'] as String?) ?? 'Folder',
      requests: [
        for (final child in (item['item'] as List?) ?? const [])
          if (child is Map && child['request'] is Map)
            _postmanRequest(Map<String, dynamic>.from(child), prefix),
      ],
    );
  }

  static ApiRequestItem _postmanRequest(
    Map<String, dynamic> item,
    String prefix,
  ) {
    final request = Map<String, dynamic>.from(item['request'] as Map);
    final url = request['url'];
    final rawUrl =
        url is Map ? (url['raw'] as String?) ?? '' : (url is String ? url : '');
    final headers = <String, String>{};
    for (final header in (request['header'] as List?) ?? const []) {
      if (header is Map && header['key'] is String) {
        headers[header['key'] as String] = (header['value'] ?? '').toString();
      }
    }
    final body = request['body'] is Map
        ? Map<String, dynamic>.from(request['body'] as Map)
        : const <String, dynamic>{};
    final mode = body['mode'] as String?;
    return ApiRequestItem(
      id: '$prefix-request-${item['name'] ?? rawUrl}',
      name: (item['name'] as String?) ?? 'Request',
      method: ((request['method'] as String?) ?? 'GET').toUpperCase(),
      url: rawUrl,
      headers: headers,
      body: ApiRequestBody(
        type: mode == 'raw'
            ? ApiRequestBodyType.rawText
            : ApiRequestBodyType.none,
        raw: body['raw'] as String? ?? '',
      ),
      description: (request['description'] ?? '').toString(),
    );
  }

  static ApiWorkspace _legacyCollectionWorkspace(
    Map<String, dynamic> document,
    String fallbackId,
  ) {
    final requests = <ApiRequestItem>[];
    for (final item in document['requests'] as List) {
      if (item is! Map) continue;
      final legacy = ApiRequest.fromMap(Map<String, dynamic>.from(item));
      requests.add(
        ApiRequestItem(
          id: '$fallbackId-${requests.length}',
          name: '${legacy.method} ${legacy.url}',
          method: legacy.method,
          url: legacy.url,
          headers: legacy.headers,
          queryParams: legacy.queryParams,
          body: ApiRequestBody(
            type: (legacy.body ?? '').isEmpty
                ? ApiRequestBodyType.none
                : ApiRequestBodyType.rawText,
            raw: legacy.body ?? '',
          ),
        ),
      );
    }
    return ApiWorkspace(
      id: fallbackId,
      name: 'Imported API Collection',
      collections: [
        ApiCollection(
          id: '$fallbackId-collection',
          name: 'Imported Collection',
          requests: requests,
        ),
      ],
    );
  }

  static String documentationMarkdown(ApiWorkspace workspace) {
    workspace = workspace.sanitized();
    final buffer = StringBuffer()
      ..writeln('# ${workspace.name}')
      ..writeln()
      ..writeln(workspace.description)
      ..writeln()
      ..writeln('## Overview')
      ..writeln(workspace.overviewMarkdown.isEmpty
          ? 'No workspace overview yet.'
          : workspace.overviewMarkdown)
      ..writeln()
      ..writeln('## Environments');
    for (final env in workspace.environments) {
      buffer.writeln('- ${env.name}: ${env.baseUrl}');
    }
    buffer
      ..writeln()
      ..writeln('## Collections');
    for (final collection in workspace.collections) {
      buffer
        ..writeln('### ${collection.name}')
        ..writeln(collection.description);
      for (final request in collection.requests) {
        _writeRequestDoc(buffer, request);
      }
      for (final folder in collection.folders) {
        buffer.writeln('#### ${folder.name}');
        for (final request in folder.requests) {
          _writeRequestDoc(buffer, request);
        }
      }
    }
    return buffer.toString();
  }

  static void _writeRequestDoc(StringBuffer buffer, ApiRequestItem request) {
    buffer
      ..writeln('- `${request.method}` ${request.name}')
      ..writeln('  - URL: `${request.url}`');
    if (request.description.isNotEmpty) {
      buffer.writeln('  - Notes: ${request.description}');
    }
    if (request.expectedResponseNote.isNotEmpty) {
      buffer.writeln('  - Expected: ${request.expectedResponseNote}');
    }
  }

  static String _sourceType(Map<String, dynamic> document) {
    if (document['type'] == workspaceType) return 'DevDesk workspace';
    if (document['type'] == collectionType) return 'DevDesk collection';
    if (_looksLikePostman(document)) return 'Postman collection';
    if (document['requests'] is List) return 'Legacy DevDesk collection';
    return 'DevDesk workspace';
  }

  static int _secretCount(ApiWorkspace workspace) {
    var count = 0;
    if (workspace.auth.hasSecrets) count++;
    count += workspace.variables.where((variable) => variable.isSecret).length;
    for (final environment in workspace.environments) {
      count +=
          environment.variables.where((variable) => variable.isSecret).length;
    }
    for (final collection in workspace.collections) {
      if (collection.auth.hasSecrets) count++;
      count +=
          collection.variables.where((variable) => variable.isSecret).length;
      for (final request in collection.requests) {
        if (request.hasSecrets) count++;
      }
      for (final folder in collection.folders) {
        if (folder.auth.hasSecrets) count++;
        count += folder.variables.where((variable) => variable.isSecret).length;
        for (final request in folder.requests) {
          if (request.hasSecrets) count++;
        }
      }
    }
    return count;
  }
}
