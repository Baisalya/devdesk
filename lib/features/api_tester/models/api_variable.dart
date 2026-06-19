class ApiVariable {
  final String key;
  final String value;
  final bool isSecret;
  final bool enabled;
  final String description;

  const ApiVariable({
    required this.key,
    required this.value,
    this.isSecret = false,
    this.enabled = true,
    this.description = '',
  });

  ApiVariable copyWith({
    String? key,
    String? value,
    bool? isSecret,
    bool? enabled,
    String? description,
  }) {
    return ApiVariable(
      key: key ?? this.key,
      value: value ?? this.value,
      isSecret: isSecret ?? this.isSecret,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
    );
  }

  ApiVariable sanitized() {
    return isSecret ? copyWith(value: '') : this;
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'isSecret': isSecret,
      'enabled': enabled,
      'description': description,
    };
  }

  factory ApiVariable.fromMap(Map<String, dynamic> map) {
    return ApiVariable(
      key: (map['key'] as String?) ?? '',
      value: (map['value'] as String?) ?? '',
      isSecret: map['isSecret'] == true,
      enabled: map['enabled'] != false,
      description: (map['description'] as String?) ?? '',
    );
  }
}

enum ApiVariableScope {
  temporary,
  workspace,
  environment;

  static ApiVariableScope fromName(String? name) {
    return ApiVariableScope.values.firstWhere(
      (scope) => scope.name == name,
      orElse: () => ApiVariableScope.temporary,
    );
  }
}
