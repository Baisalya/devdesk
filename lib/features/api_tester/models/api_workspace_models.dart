import 'api_environment.dart';
import 'api_request.dart';
import 'api_response.dart';
import 'api_variable.dart';

enum ApiAuthType {
  inherit,
  noAuth,
  bearerToken,
  basicAuth,
  apiKeyHeader,
  apiKeyQuery;

  static ApiAuthType fromName(String? name) {
    return ApiAuthType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => ApiAuthType.inherit,
    );
  }
}

class ApiAuthConfig {
  final ApiAuthType type;
  final String token;
  final String username;
  final String password;
  final String apiKeyName;
  final String apiKeyValue;

  const ApiAuthConfig({
    this.type = ApiAuthType.inherit,
    this.token = '',
    this.username = '',
    this.password = '',
    this.apiKeyName = '',
    this.apiKeyValue = '',
  });

  const ApiAuthConfig.inherit() : this();

  const ApiAuthConfig.noAuth() : this(type: ApiAuthType.noAuth);

  ApiAuthConfig copyWith({
    ApiAuthType? type,
    String? token,
    String? username,
    String? password,
    String? apiKeyName,
    String? apiKeyValue,
  }) {
    return ApiAuthConfig(
      type: type ?? this.type,
      token: token ?? this.token,
      username: username ?? this.username,
      password: password ?? this.password,
      apiKeyName: apiKeyName ?? this.apiKeyName,
      apiKeyValue: apiKeyValue ?? this.apiKeyValue,
    );
  }

  bool get hasSecrets {
    return token.isNotEmpty || password.isNotEmpty || apiKeyValue.isNotEmpty;
  }

  ApiAuthConfig sanitized() {
    return copyWith(token: '', password: '', apiKeyValue: '');
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'token': token,
      'username': username,
      'password': password,
      'apiKeyName': apiKeyName,
      'apiKeyValue': apiKeyValue,
    };
  }

  factory ApiAuthConfig.fromMap(Map<String, dynamic> map) {
    return ApiAuthConfig(
      type: ApiAuthType.fromName(map['type'] as String?),
      token: (map['token'] as String?) ?? '',
      username: (map['username'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      apiKeyName: (map['apiKeyName'] as String?) ?? '',
      apiKeyValue: (map['apiKeyValue'] as String?) ?? '',
    );
  }
}

enum ApiRequestBodyType {
  none,
  rawJson,
  rawText,
  formUrlEncoded,
  multipartFormData;

  static ApiRequestBodyType fromName(String? name) {
    return ApiRequestBodyType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => ApiRequestBodyType.none,
    );
  }
}

class ApiRequestBody {
  final ApiRequestBodyType type;
  final String raw;
  final Map<String, String> formFields;

  const ApiRequestBody({
    this.type = ApiRequestBodyType.none,
    this.raw = '',
    this.formFields = const {},
  });

  ApiRequestBody copyWith({
    ApiRequestBodyType? type,
    String? raw,
    Map<String, String>? formFields,
  }) {
    return ApiRequestBody(
      type: type ?? this.type,
      raw: raw ?? this.raw,
      formFields: formFields ?? this.formFields,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'raw': raw,
      'formFields': formFields,
    };
  }

  factory ApiRequestBody.fromMap(Map<String, dynamic> map) {
    return ApiRequestBody(
      type: ApiRequestBodyType.fromName(map['type'] as String?),
      raw: (map['raw'] as String?) ?? '',
      formFields:
          Map<String, String>.from((map['formFields'] as Map?) ?? const {}),
    );
  }
}

enum ApiAssertionType {
  statusCodeEquals,
  responseTimeLessThan,
  jsonPathExists,
  jsonPathEquals,
  headerExists,
  bodyContains;

  static ApiAssertionType fromName(String? name) {
    return ApiAssertionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => ApiAssertionType.statusCodeEquals,
    );
  }
}

class ApiAssertion {
  final String id;
  final String name;
  final ApiAssertionType type;
  final String target;
  final String expected;
  final bool enabled;

  const ApiAssertion({
    required this.id,
    required this.name,
    required this.type,
    this.target = '',
    this.expected = '',
    this.enabled = true,
  });

  ApiAssertion copyWith({
    String? id,
    String? name,
    ApiAssertionType? type,
    String? target,
    String? expected,
    bool? enabled,
  }) {
    return ApiAssertion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      target: target ?? this.target,
      expected: expected ?? this.expected,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'target': target,
      'expected': expected,
      'enabled': enabled,
    };
  }

  factory ApiAssertion.fromMap(Map<String, dynamic> map) {
    return ApiAssertion(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      type: ApiAssertionType.fromName(map['type'] as String?),
      target: (map['target'] as String?) ?? '',
      expected: (map['expected'] as String?) ?? '',
      enabled: map['enabled'] != false,
    );
  }
}

class ApiAssertionResult {
  final String assertionId;
  final String name;
  final bool passed;
  final String message;

  const ApiAssertionResult({
    required this.assertionId,
    required this.name,
    required this.passed,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'assertionId': assertionId,
      'name': name,
      'passed': passed,
      'message': message,
    };
  }

  factory ApiAssertionResult.fromMap(Map<String, dynamic> map) {
    return ApiAssertionResult(
      assertionId: (map['assertionId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      passed: map['passed'] == true,
      message: (map['message'] as String?) ?? '',
    );
  }
}

enum ApiExtractionSource {
  jsonPath,
  header,
  regexBody;

  static ApiExtractionSource fromName(String? name) {
    return ApiExtractionSource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => ApiExtractionSource.jsonPath,
    );
  }
}

class ApiExtractionRule {
  final String id;
  final String name;
  final ApiExtractionSource source;
  final String expression;
  final String variableName;
  final ApiVariableScope targetScope;
  final bool isSecret;
  final bool enabled;

  const ApiExtractionRule({
    required this.id,
    required this.name,
    required this.source,
    required this.expression,
    required this.variableName,
    this.targetScope = ApiVariableScope.temporary,
    this.isSecret = false,
    this.enabled = true,
  });

  ApiExtractionRule copyWith({
    String? id,
    String? name,
    ApiExtractionSource? source,
    String? expression,
    String? variableName,
    ApiVariableScope? targetScope,
    bool? isSecret,
    bool? enabled,
  }) {
    return ApiExtractionRule(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      expression: expression ?? this.expression,
      variableName: variableName ?? this.variableName,
      targetScope: targetScope ?? this.targetScope,
      isSecret: isSecret ?? this.isSecret,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'source': source.name,
      'expression': expression,
      'variableName': variableName,
      'targetScope': targetScope.name,
      'isSecret': isSecret,
      'enabled': enabled,
    };
  }

  factory ApiExtractionRule.fromMap(Map<String, dynamic> map) {
    return ApiExtractionRule(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      source: ApiExtractionSource.fromName(map['source'] as String?),
      expression: (map['expression'] as String?) ?? '',
      variableName: (map['variableName'] as String?) ?? '',
      targetScope: ApiVariableScope.fromName(map['targetScope'] as String?),
      isSecret: map['isSecret'] == true,
      enabled: map['enabled'] != false,
    );
  }
}

class ApiExtractionResult {
  final String ruleId;
  final String variableName;
  final String value;
  final bool isSecret;
  final bool success;
  final String message;

  const ApiExtractionResult({
    required this.ruleId,
    required this.variableName,
    required this.value,
    required this.isSecret,
    required this.success,
    required this.message,
  });

  String get displayValue => isSecret && value.isNotEmpty ? '••••••••' : value;

  Map<String, dynamic> toMap({bool includeSecrets = true}) {
    return {
      'ruleId': ruleId,
      'variableName': variableName,
      'value': includeSecrets || !isSecret ? value : '',
      'isSecret': isSecret,
      'success': success,
      'message': message,
    };
  }

  factory ApiExtractionResult.fromMap(Map<String, dynamic> map) {
    return ApiExtractionResult(
      ruleId: (map['ruleId'] as String?) ?? '',
      variableName: (map['variableName'] as String?) ?? '',
      value: (map['value'] as String?) ?? '',
      isSecret: map['isSecret'] == true,
      success: map['success'] == true,
      message: (map['message'] as String?) ?? '',
    );
  }
}

class ApiResponseRecord {
  final String id;
  final String method;
  final String url;
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final int durationMs;
  final int sizeBytes;
  final DateTime timestamp;
  final List<ApiAssertionResult> assertionResults;
  final List<ApiExtractionResult> extractionResults;

  ApiResponseRecord({
    required this.id,
    required this.method,
    required this.url,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.durationMs,
    required this.sizeBytes,
    DateTime? timestamp,
    this.assertionResults = const [],
    this.extractionResults = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  bool get passedAssertions =>
      assertionResults.isEmpty ||
      assertionResults.every((result) => result.passed);

  ApiResponseRecord copyWith({
    String? id,
    String? method,
    String? url,
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    int? durationMs,
    int? sizeBytes,
    DateTime? timestamp,
    List<ApiAssertionResult>? assertionResults,
    List<ApiExtractionResult>? extractionResults,
  }) {
    return ApiResponseRecord(
      id: id ?? this.id,
      method: method ?? this.method,
      url: url ?? this.url,
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      timestamp: timestamp ?? this.timestamp,
      assertionResults: assertionResults ?? this.assertionResults,
      extractionResults: extractionResults ?? this.extractionResults,
    );
  }

  Map<String, String> get cookies {
    final cookie = headers.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .map((entry) => entry.value)
        .join('; ');
    if (cookie.isEmpty) return const {};
    return {
      for (final part in cookie.split(';'))
        if (part.trim().contains('='))
          part.trim().split('=').first:
              part.trim().split('=').skip(1).join('='),
    };
  }

  ApiResponse toLegacyResponse() {
    return ApiResponse(
      method: method,
      url: url,
      statusCode: statusCode,
      headers: headers,
      body: body,
      duration: Duration(milliseconds: durationMs),
    );
  }

  Map<String, dynamic> toMap({bool includeSecrets = true}) {
    return {
      'id': id,
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
      'durationMs': durationMs,
      'sizeBytes': sizeBytes,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'assertionResults':
          assertionResults.map((result) => result.toMap()).toList(),
      'extractionResults': extractionResults
          .map((result) => result.toMap(includeSecrets: includeSecrets))
          .toList(),
    };
  }

  factory ApiResponseRecord.fromMap(Map<String, dynamic> map) {
    return ApiResponseRecord(
      id: (map['id'] as String?) ?? '',
      method: (map['method'] as String?) ?? 'GET',
      url: (map['url'] as String?) ?? '',
      statusCode: (map['statusCode'] as int?) ?? 0,
      headers: Map<String, String>.from((map['headers'] as Map?) ?? const {}),
      body: (map['body'] as String?) ?? '',
      durationMs: (map['durationMs'] as int?) ?? 0,
      sizeBytes: (map['sizeBytes'] as int?) ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      assertionResults: [
        for (final item in (map['assertionResults'] as List?) ?? const [])
          if (item is Map)
            ApiAssertionResult.fromMap(Map<String, dynamic>.from(item)),
      ],
      extractionResults: [
        for (final item in (map['extractionResults'] as List?) ?? const [])
          if (item is Map)
            ApiExtractionResult.fromMap(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class ApiRequestItem {
  final String id;
  final String name;
  final String description;
  final String method;
  final String url;
  final Map<String, String> queryParams;
  final Map<String, String> headers;
  final ApiAuthConfig auth;
  final ApiRequestBody body;
  final int timeoutMs;
  final bool followRedirects;
  final List<ApiVariable> variables;
  final List<ApiAssertion> assertions;
  final List<ApiExtractionRule> extractionRules;
  final String expectedResponseNote;
  final String exampleResponse;
  final List<String> tags;
  final bool important;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApiRequestItem({
    required this.id,
    required this.name,
    required this.method,
    required this.url,
    this.description = '',
    this.queryParams = const {},
    this.headers = const {},
    this.auth = const ApiAuthConfig.inherit(),
    this.body = const ApiRequestBody(),
    this.timeoutMs = 30000,
    this.followRedirects = true,
    this.variables = const [],
    this.assertions = const [],
    this.extractionRules = const [],
    this.expectedResponseNote = '',
    this.exampleResponse = '',
    this.tags = const [],
    this.important = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ApiRequestItem copyWith({
    String? id,
    String? name,
    String? description,
    String? method,
    String? url,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    ApiAuthConfig? auth,
    ApiRequestBody? body,
    int? timeoutMs,
    bool? followRedirects,
    List<ApiVariable>? variables,
    List<ApiAssertion>? assertions,
    List<ApiExtractionRule>? extractionRules,
    String? expectedResponseNote,
    String? exampleResponse,
    List<String>? tags,
    bool? important,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiRequestItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      method: method ?? this.method,
      url: url ?? this.url,
      queryParams: queryParams ?? this.queryParams,
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
      body: body ?? this.body,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      followRedirects: followRedirects ?? this.followRedirects,
      variables: variables ?? this.variables,
      assertions: assertions ?? this.assertions,
      extractionRules: extractionRules ?? this.extractionRules,
      expectedResponseNote: expectedResponseNote ?? this.expectedResponseNote,
      exampleResponse: exampleResponse ?? this.exampleResponse,
      tags: tags ?? this.tags,
      important: important ?? this.important,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  ApiRequestItem sanitized() {
    return copyWith(
      headers: Map.fromEntries(
        headers.entries
            .where((entry) => !ApiRequest.isSensitiveHeader(entry.key)),
      ),
      auth: auth.sanitized(),
      variables: variables.map((variable) => variable.sanitized()).toList(),
    );
  }

  bool get hasSecrets {
    return headers.keys.any(ApiRequest.isSensitiveHeader) ||
        auth.hasSecrets ||
        variables.any((variable) => variable.isSecret) ||
        extractionRules.any((rule) => rule.isSecret);
  }

  ApiRequest toLegacyRequest() {
    return ApiRequest(
      method: method,
      url: url,
      headers: headers,
      queryParams: queryParams,
      body: body.raw.isNotEmpty ? body.raw : null,
      followRedirects: followRedirects,
    );
  }

  Map<String, dynamic> toMap({bool includeSecrets = true}) {
    final request = includeSecrets ? this : sanitized();
    return {
      'id': request.id,
      'name': request.name,
      'description': request.description,
      'method': request.method,
      'url': request.url,
      'queryParams': request.queryParams,
      'headers': request.headers,
      'auth': request.auth.toMap(),
      'body': request.body.toMap(),
      'timeoutMs': request.timeoutMs,
      'followRedirects': request.followRedirects,
      'variables':
          request.variables.map((variable) => variable.toMap()).toList(),
      'assertions':
          request.assertions.map((assertion) => assertion.toMap()).toList(),
      'extractionRules':
          request.extractionRules.map((rule) => rule.toMap()).toList(),
      'expectedResponseNote': request.expectedResponseNote,
      'exampleResponse': request.exampleResponse,
      'tags': request.tags,
      'important': request.important,
      'createdAt': request.createdAt.millisecondsSinceEpoch,
      'updatedAt': request.updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ApiRequestItem.fromMap(Map<String, dynamic> map) {
    return ApiRequestItem(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Untitled Request',
      description: (map['description'] as String?) ?? '',
      method: ((map['method'] as String?) ?? 'GET').toUpperCase(),
      url: (map['url'] as String?) ?? '',
      queryParams:
          Map<String, String>.from((map['queryParams'] as Map?) ?? const {}),
      headers: Map<String, String>.from((map['headers'] as Map?) ?? const {}),
      auth: map['auth'] is Map
          ? ApiAuthConfig.fromMap(Map<String, dynamic>.from(map['auth'] as Map))
          : const ApiAuthConfig.inherit(),
      body: map['body'] is Map
          ? ApiRequestBody.fromMap(
              Map<String, dynamic>.from(map['body'] as Map))
          : ApiRequestBody(raw: (map['body'] as String?) ?? ''),
      timeoutMs: (map['timeoutMs'] as int?) ?? 30000,
      followRedirects: map['followRedirects'] != false,
      variables: [
        for (final item in (map['variables'] as List?) ?? const [])
          if (item is Map) ApiVariable.fromMap(Map<String, dynamic>.from(item)),
      ],
      assertions: [
        for (final item in (map['assertions'] as List?) ?? const [])
          if (item is Map)
            ApiAssertion.fromMap(Map<String, dynamic>.from(item)),
      ],
      extractionRules: [
        for (final item in (map['extractionRules'] as List?) ?? const [])
          if (item is Map)
            ApiExtractionRule.fromMap(Map<String, dynamic>.from(item)),
      ],
      expectedResponseNote: (map['expectedResponseNote'] as String?) ?? '',
      exampleResponse: (map['exampleResponse'] as String?) ?? '',
      tags: [
        for (final item in (map['tags'] as List?) ?? const [])
          if (item != null) item.toString(),
      ],
      important: map['important'] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class ApiFolder {
  final String id;
  final String name;
  final String description;
  final List<ApiRequestItem> requests;
  final List<ApiVariable> variables;
  final ApiAuthConfig auth;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApiFolder({
    required this.id,
    required this.name,
    this.description = '',
    this.requests = const [],
    this.variables = const [],
    this.auth = const ApiAuthConfig.inherit(),
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ApiFolder copyWith({
    String? id,
    String? name,
    String? description,
    List<ApiRequestItem>? requests,
    List<ApiVariable>? variables,
    ApiAuthConfig? auth,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      requests: requests ?? this.requests,
      variables: variables ?? this.variables,
      auth: auth ?? this.auth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  ApiFolder sanitized() {
    return copyWith(
      requests: requests.map((request) => request.sanitized()).toList(),
      variables: variables.map((variable) => variable.sanitized()).toList(),
      auth: auth.sanitized(),
    );
  }

  int get requestCount => requests.length;

  bool get hasSecrets =>
      auth.hasSecrets ||
      variables.any((variable) => variable.isSecret) ||
      requests.any((request) => request.hasSecrets);

  Map<String, dynamic> toMap({bool includeSecrets = true}) {
    final folder = includeSecrets ? this : sanitized();
    return {
      'id': folder.id,
      'name': folder.name,
      'description': folder.description,
      'requests': folder.requests
          .map((request) => request.toMap(includeSecrets: includeSecrets))
          .toList(),
      'variables':
          folder.variables.map((variable) => variable.toMap()).toList(),
      'auth': folder.auth.toMap(),
      'createdAt': folder.createdAt.millisecondsSinceEpoch,
      'updatedAt': folder.updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ApiFolder.fromMap(Map<String, dynamic> map) {
    return ApiFolder(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Folder',
      description: (map['description'] as String?) ?? '',
      requests: [
        for (final item in (map['requests'] as List?) ?? const [])
          if (item is Map)
            ApiRequestItem.fromMap(Map<String, dynamic>.from(item)),
      ],
      variables: [
        for (final item in (map['variables'] as List?) ?? const [])
          if (item is Map) ApiVariable.fromMap(Map<String, dynamic>.from(item)),
      ],
      auth: map['auth'] is Map
          ? ApiAuthConfig.fromMap(Map<String, dynamic>.from(map['auth'] as Map))
          : const ApiAuthConfig.inherit(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class ApiCollection {
  final String id;
  final String name;
  final String description;
  final List<ApiFolder> folders;
  final List<ApiRequestItem> requests;
  final List<ApiVariable> variables;
  final ApiAuthConfig auth;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApiCollection({
    required this.id,
    required this.name,
    this.description = '',
    this.folders = const [],
    this.requests = const [],
    this.variables = const [],
    this.auth = const ApiAuthConfig.inherit(),
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ApiCollection copyWith({
    String? id,
    String? name,
    String? description,
    List<ApiFolder>? folders,
    List<ApiRequestItem>? requests,
    List<ApiVariable>? variables,
    ApiAuthConfig? auth,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      folders: folders ?? this.folders,
      requests: requests ?? this.requests,
      variables: variables ?? this.variables,
      auth: auth ?? this.auth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  ApiCollection sanitized() {
    return copyWith(
      folders: folders.map((folder) => folder.sanitized()).toList(),
      requests: requests.map((request) => request.sanitized()).toList(),
      variables: variables.map((variable) => variable.sanitized()).toList(),
      auth: auth.sanitized(),
    );
  }

  int get requestCount {
    return requests.length +
        folders.fold(0, (total, folder) => total + folder.requestCount);
  }

  int get folderCount => folders.length;

  bool get hasSecrets {
    return auth.hasSecrets ||
        variables.any((variable) => variable.isSecret) ||
        requests.any((request) => request.hasSecrets) ||
        folders.any((folder) => folder.hasSecrets);
  }

  Map<String, dynamic> toMap({bool includeSecrets = true}) {
    final collection = includeSecrets ? this : sanitized();
    return {
      'id': collection.id,
      'name': collection.name,
      'description': collection.description,
      'folders': collection.folders
          .map((folder) => folder.toMap(includeSecrets: includeSecrets))
          .toList(),
      'requests': collection.requests
          .map((request) => request.toMap(includeSecrets: includeSecrets))
          .toList(),
      'variables':
          collection.variables.map((variable) => variable.toMap()).toList(),
      'auth': collection.auth.toMap(),
      'createdAt': collection.createdAt.millisecondsSinceEpoch,
      'updatedAt': collection.updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ApiCollection.fromMap(Map<String, dynamic> map) {
    return ApiCollection(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Collection',
      description: (map['description'] as String?) ?? '',
      folders: [
        for (final item in (map['folders'] as List?) ?? const [])
          if (item is Map) ApiFolder.fromMap(Map<String, dynamic>.from(item)),
      ],
      requests: [
        for (final item in (map['requests'] as List?) ?? const [])
          if (item is Map)
            ApiRequestItem.fromMap(Map<String, dynamic>.from(item)),
      ],
      variables: [
        for (final item in (map['variables'] as List?) ?? const [])
          if (item is Map) ApiVariable.fromMap(Map<String, dynamic>.from(item)),
      ],
      auth: map['auth'] is Map
          ? ApiAuthConfig.fromMap(Map<String, dynamic>.from(map['auth'] as Map))
          : const ApiAuthConfig.inherit(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class ApiWorkspace {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final bool favorite;
  final bool archived;
  final List<ApiCollection> collections;
  final List<ApiEnvironment> environments;
  final String activeEnvironmentId;
  final List<ApiVariable> variables;
  final ApiAuthConfig auth;
  final bool saveSecrets;
  final String overviewMarkdown;
  final String baseUrlNotes;
  final String authInstructions;

  ApiWorkspace({
    required this.id,
    required this.name,
    this.description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastUsedAt,
    this.favorite = false,
    this.archived = false,
    this.collections = const [],
    this.environments = const [],
    this.activeEnvironmentId = '',
    this.variables = const [],
    this.auth = const ApiAuthConfig.noAuth(),
    this.saveSecrets = false,
    this.overviewMarkdown = '',
    this.baseUrlNotes = '',
    this.authInstructions = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ApiEnvironment? get activeEnvironment {
    if (activeEnvironmentId.isEmpty && environments.isNotEmpty) {
      return environments.first;
    }
    for (final environment in environments) {
      if (environment.id == activeEnvironmentId ||
          environment.name == activeEnvironmentId) {
        return environment;
      }
    }
    return environments.isEmpty ? null : environments.first;
  }

  int get requestCount {
    return collections.fold(
      0,
      (total, collection) => total + collection.requestCount,
    );
  }

  int get folderCount {
    return collections.fold(
      0,
      (total, collection) => total + collection.folderCount,
    );
  }

  int get environmentCount => environments.length;

  bool get hasSecrets {
    return auth.hasSecrets ||
        variables.any((variable) => variable.isSecret) ||
        environments.any((environment) => environment.hasSecrets) ||
        collections.any((collection) => collection.hasSecrets);
  }

  ApiWorkspace copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    bool? favorite,
    bool? archived,
    List<ApiCollection>? collections,
    List<ApiEnvironment>? environments,
    String? activeEnvironmentId,
    List<ApiVariable>? variables,
    ApiAuthConfig? auth,
    bool? saveSecrets,
    String? overviewMarkdown,
    String? baseUrlNotes,
    String? authInstructions,
  }) {
    return ApiWorkspace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      collections: collections ?? this.collections,
      environments: environments ?? this.environments,
      activeEnvironmentId: activeEnvironmentId ?? this.activeEnvironmentId,
      variables: variables ?? this.variables,
      auth: auth ?? this.auth,
      saveSecrets: saveSecrets ?? this.saveSecrets,
      overviewMarkdown: overviewMarkdown ?? this.overviewMarkdown,
      baseUrlNotes: baseUrlNotes ?? this.baseUrlNotes,
      authInstructions: authInstructions ?? this.authInstructions,
    );
  }

  ApiWorkspace sanitized() {
    return copyWith(
      collections:
          collections.map((collection) => collection.sanitized()).toList(),
      environments:
          environments.map((environment) => environment.sanitized()).toList(),
      variables: variables.map((variable) => variable.sanitized()).toList(),
      auth: auth.sanitized(),
      saveSecrets: false,
    );
  }

  Map<String, dynamic> toMap({bool includeSecrets = true}) {
    final workspace = includeSecrets ? this : sanitized();
    return {
      'id': workspace.id,
      'name': workspace.name,
      'description': workspace.description,
      'createdAt': workspace.createdAt.millisecondsSinceEpoch,
      'updatedAt': workspace.updatedAt.millisecondsSinceEpoch,
      'lastUsedAt': workspace.lastUsedAt?.millisecondsSinceEpoch,
      'favorite': workspace.favorite,
      'archived': workspace.archived,
      'collections': workspace.collections
          .map((collection) => collection.toMap(includeSecrets: includeSecrets))
          .toList(),
      'environments': workspace.environments
          .map((environment) => environment.toMap())
          .toList(),
      'activeEnvironmentId': workspace.activeEnvironmentId,
      'variables':
          workspace.variables.map((variable) => variable.toMap()).toList(),
      'auth': workspace.auth.toMap(),
      'saveSecrets': workspace.saveSecrets,
      'overviewMarkdown': workspace.overviewMarkdown,
      'baseUrlNotes': workspace.baseUrlNotes,
      'authInstructions': workspace.authInstructions,
    };
  }

  factory ApiWorkspace.fromMap(Map<String, dynamic> map) {
    return ApiWorkspace(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Workspace',
      description: (map['description'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      lastUsedAt: map['lastUsedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUsedAt'] as int)
          : null,
      favorite: map['favorite'] == true,
      archived: map['archived'] == true,
      collections: [
        for (final item in (map['collections'] as List?) ?? const [])
          if (item is Map)
            ApiCollection.fromMap(Map<String, dynamic>.from(item)),
      ],
      environments: [
        for (final item in (map['environments'] as List?) ?? const [])
          if (item is Map)
            ApiEnvironment.fromMap(Map<String, dynamic>.from(item)),
      ],
      activeEnvironmentId: (map['activeEnvironmentId'] as String?) ?? '',
      variables: [
        for (final item in (map['variables'] as List?) ?? const [])
          if (item is Map) ApiVariable.fromMap(Map<String, dynamic>.from(item)),
      ],
      auth: map['auth'] is Map
          ? ApiAuthConfig.fromMap(Map<String, dynamic>.from(map['auth'] as Map))
          : const ApiAuthConfig.noAuth(),
      saveSecrets: map['saveSecrets'] == true,
      overviewMarkdown: (map['overviewMarkdown'] as String?) ?? '',
      baseUrlNotes: (map['baseUrlNotes'] as String?) ?? '',
      authInstructions: (map['authInstructions'] as String?) ?? '',
    );
  }
}

class ApiHistoryItem {
  final String id;
  final String workspaceId;
  final String requestId;
  final String requestName;
  final String method;
  final String url;
  final int? statusCode;
  final int? durationMs;
  final DateTime timestamp;
  final ApiRequestItem request;
  final ApiResponseRecord? response;

  ApiHistoryItem({
    required this.id,
    required this.workspaceId,
    required this.requestId,
    required this.requestName,
    required this.method,
    required this.url,
    required this.request,
    this.statusCode,
    this.durationMs,
    this.response,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ApiHistoryItem sanitized() {
    return ApiHistoryItem(
      id: id,
      workspaceId: workspaceId,
      requestId: requestId,
      requestName: requestName,
      method: method,
      url: url,
      statusCode: statusCode,
      durationMs: durationMs,
      timestamp: timestamp,
      request: request.sanitized().copyWith(body: const ApiRequestBody()),
      response: response,
    );
  }

  Map<String, dynamic> toMap({bool includeSecrets = true}) {
    final item = includeSecrets ? this : sanitized();
    return {
      'id': item.id,
      'workspaceId': item.workspaceId,
      'requestId': item.requestId,
      'requestName': item.requestName,
      'method': item.method,
      'url': item.url,
      'statusCode': item.statusCode,
      'durationMs': item.durationMs,
      'timestamp': item.timestamp.millisecondsSinceEpoch,
      'request': item.request.toMap(includeSecrets: includeSecrets),
      'response': item.response?.toMap(includeSecrets: includeSecrets),
    };
  }

  factory ApiHistoryItem.fromMap(Map<String, dynamic> map) {
    return ApiHistoryItem(
      id: (map['id'] as String?) ?? '',
      workspaceId: (map['workspaceId'] as String?) ?? '',
      requestId: (map['requestId'] as String?) ?? '',
      requestName: (map['requestName'] as String?) ?? '',
      method: (map['method'] as String?) ?? 'GET',
      url: (map['url'] as String?) ?? '',
      statusCode: map['statusCode'] as int?,
      durationMs: map['durationMs'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      request: map['request'] is Map
          ? ApiRequestItem.fromMap(
              Map<String, dynamic>.from(map['request'] as Map),
            )
          : ApiRequestItem(id: '', name: '', method: 'GET', url: ''),
      response: map['response'] is Map
          ? ApiResponseRecord.fromMap(
              Map<String, dynamic>.from(map['response'] as Map),
            )
          : null,
    );
  }
}

class ApiRunnerRequestResult {
  final String requestId;
  final String requestName;
  final bool passed;
  final bool skipped;
  final String message;
  final int? statusCode;
  final int? durationMs;

  const ApiRunnerRequestResult({
    required this.requestId,
    required this.requestName,
    required this.passed,
    this.skipped = false,
    this.message = '',
    this.statusCode,
    this.durationMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'requestName': requestName,
      'passed': passed,
      'skipped': skipped,
      'message': message,
      'statusCode': statusCode,
      'durationMs': durationMs,
    };
  }

  factory ApiRunnerRequestResult.fromMap(Map<String, dynamic> map) {
    return ApiRunnerRequestResult(
      requestId: (map['requestId'] as String?) ?? '',
      requestName: (map['requestName'] as String?) ?? '',
      passed: map['passed'] == true,
      skipped: map['skipped'] == true,
      message: (map['message'] as String?) ?? '',
      statusCode: map['statusCode'] as int?,
      durationMs: map['durationMs'] as int?,
    );
  }
}

class ApiRunnerResult {
  final String id;
  final String workspaceId;
  final String collectionId;
  final String targetName;
  final String environmentId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<ApiRunnerRequestResult> results;

  ApiRunnerResult({
    required this.id,
    required this.workspaceId,
    required this.collectionId,
    required this.targetName,
    required this.environmentId,
    required this.results,
    DateTime? startedAt,
    DateTime? finishedAt,
  })  : startedAt = startedAt ?? DateTime.now(),
        finishedAt = finishedAt ?? DateTime.now();

  int get totalRequests => results.length;

  int get passed => results.where((result) => result.passed).length;

  int get failed =>
      results.where((result) => !result.passed && !result.skipped).length;

  int get skipped => results.where((result) => result.skipped).length;

  int get averageResponseTimeMs {
    final durations = results
        .map((result) => result.durationMs)
        .whereType<int>()
        .toList(growable: false);
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a + b) ~/ durations.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'collectionId': collectionId,
      'targetName': targetName,
      'environmentId': environmentId,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'finishedAt': finishedAt.millisecondsSinceEpoch,
      'results': results.map((result) => result.toMap()).toList(),
      'summary': {
        'totalRequests': totalRequests,
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'averageResponseTimeMs': averageResponseTimeMs,
      },
    };
  }

  factory ApiRunnerResult.fromMap(Map<String, dynamic> map) {
    return ApiRunnerResult(
      id: (map['id'] as String?) ?? '',
      workspaceId: (map['workspaceId'] as String?) ?? '',
      collectionId: (map['collectionId'] as String?) ?? '',
      targetName: (map['targetName'] as String?) ?? '',
      environmentId: (map['environmentId'] as String?) ?? '',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['startedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      finishedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['finishedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      results: [
        for (final item in (map['results'] as List?) ?? const [])
          if (item is Map)
            ApiRunnerRequestResult.fromMap(Map<String, dynamic>.from(item)),
      ],
    );
  }
}
