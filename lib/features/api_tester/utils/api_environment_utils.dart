class ApiEnvironmentUtils {
  static String resolveVariables(
    String input,
    Map<String, String> variables,
  ) {
    var resolved = input;
    for (final entry in variables.entries) {
      resolved = resolved.replaceAll('{{${entry.key}}}', entry.value);
    }
    return resolved;
  }
}
