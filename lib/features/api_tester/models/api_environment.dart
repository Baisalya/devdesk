class ApiEnvironment {
  final String name;
  final String baseUrl;

  const ApiEnvironment({
    required this.name,
    required this.baseUrl,
  });

  ApiEnvironment copyWith({String? name, String? baseUrl}) {
    return ApiEnvironment(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'baseUrl': baseUrl,
    };
  }

  factory ApiEnvironment.fromMap(Map<String, dynamic> map) {
    return ApiEnvironment(
      name: (map['name'] as String?) ?? '',
      baseUrl: (map['baseUrl'] as String?) ?? '',
    );
  }
}
