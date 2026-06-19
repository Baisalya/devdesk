import 'api_variable.dart';

class ApiEnvironment {
  final String id;
  final String name;
  final String baseUrl;
  final List<ApiVariable> variables;
  final bool isActive;

  ApiEnvironment({
    String? id,
    required this.name,
    required this.baseUrl,
    this.variables = const [],
    this.isActive = false,
  }) : id = id ?? name;

  ApiEnvironment copyWith({
    String? id,
    String? name,
    String? baseUrl,
    List<ApiVariable>? variables,
    bool? isActive,
  }) {
    return ApiEnvironment(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      variables: variables ?? this.variables,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, String> get variableMap {
    final values = <String, String>{
      for (final variable in variables)
        if (variable.enabled && variable.key.trim().isNotEmpty)
          variable.key.trim(): variable.value,
    };
    if (baseUrl.trim().isNotEmpty && !values.containsKey('baseUrl')) {
      values['baseUrl'] = baseUrl.trim();
    }
    return values;
  }

  ApiEnvironment sanitized() {
    return copyWith(
      variables: variables.map((variable) => variable.sanitized()).toList(),
    );
  }

  bool get hasSecrets => variables.any((variable) => variable.isSecret);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'variables': variables.map((variable) => variable.toMap()).toList(),
      'isActive': isActive,
    };
  }

  factory ApiEnvironment.fromMap(Map<String, dynamic> map) {
    return ApiEnvironment(
      id: map['id'] as String?,
      name: (map['name'] as String?) ?? '',
      baseUrl: (map['baseUrl'] as String?) ?? '',
      variables: [
        for (final item in (map['variables'] as List?) ?? const [])
          if (item is Map) ApiVariable.fromMap(Map<String, dynamic>.from(item)),
      ],
      isActive: map['isActive'] == true,
    );
  }
}
