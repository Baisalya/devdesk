import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../../../core/errors/failure.dart';

class FrontmatterDocument {
  final String raw;
  final String body;
  final Map<String, dynamic> fields;
  final bool hasFrontmatter;
  final String lineEnding;

  const FrontmatterDocument._({
    required this.raw,
    required this.body,
    required this.fields,
    required this.hasFrontmatter,
    required this.lineEnding,
  });

  factory FrontmatterDocument.parse(String source) {
    final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (!normalized.startsWith('---\n')) {
      return FrontmatterDocument._(
        raw: '',
        body: source,
        fields: const {},
        hasFrontmatter: false,
        lineEnding: lineEnding,
      );
    }
    final lines = normalized.split('\n');
    var closingIndex = -1;
    for (var index = 1; index < lines.length; index++) {
      if (lines[index] == '---' || lines[index] == '...') {
        closingIndex = index;
        break;
      }
    }
    if (closingIndex < 0) {
      throw ParsingFailure(
        'YAML frontmatter starts with --- but has no closing delimiter.',
        code: 'DD-FRONTMATTER-DELIMITER',
      );
    }
    final raw = lines.sublist(1, closingIndex).join('\n');
    final body = lines.sublist(closingIndex + 1).join('\n');
    return FrontmatterDocument._(
      raw: raw,
      body: body.replaceAll('\n', lineEnding),
      fields: _parseYamlMap(raw),
      hasFrontmatter: true,
      lineEnding: lineEnding,
    );
  }

  FrontmatterDocument applyFields(Map<String, Object?> changes) {
    if (changes.isEmpty) return this;
    for (final key in changes.keys) {
      if (!_validKey.hasMatch(key)) {
        throw ValidationFailure(
          'Frontmatter field "$key" is not a safe top-level YAML key.',
          code: 'DD-FRONTMATTER-KEY',
        );
      }
    }
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    if (lines.length == 1 && lines.single.isEmpty) lines.clear();
    final ranges = _topLevelRanges(lines);
    final replacements = <_LineReplacement>[];
    for (final entry in changes.entries) {
      final existing = ranges[entry.key];
      if (existing != null) {
        replacements.add(
          _LineReplacement(
            start: existing.$1,
            end: existing.$2,
            lines: _serializeField(entry.key, entry.value),
          ),
        );
      }
    }
    replacements.sort((left, right) => right.start.compareTo(left.start));
    for (final replacement in replacements) {
      lines.replaceRange(
        replacement.start,
        replacement.end,
        replacement.lines,
      );
    }
    for (final entry in changes.entries) {
      if (!ranges.containsKey(entry.key)) {
        if (lines.isNotEmpty && lines.last.trim().isNotEmpty) lines.add('');
        lines.addAll(_serializeField(entry.key, entry.value));
      }
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    final updatedRaw = lines.join('\n');
    return FrontmatterDocument._(
      raw: updatedRaw,
      body: body,
      fields: _parseYamlMap(updatedRaw),
      hasFrontmatter: true,
      lineEnding: lineEnding,
    );
  }

  String render() {
    if (!hasFrontmatter) return body;
    final normalizedBody = body.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final result = StringBuffer()
      ..writeln('---')
      ..writeln(raw)
      ..writeln('---')
      ..write(normalizedBody);
    return result.toString().replaceAll('\n', lineEnding);
  }

  String renderWithFrontmatter() {
    if (hasFrontmatter) return render();
    return FrontmatterDocument._(
      raw: raw,
      body: body,
      fields: fields,
      hasFrontmatter: true,
      lineEnding: lineEnding,
    ).render();
  }

  static final _validKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$');
  static final _keyLine = RegExp(r'^([A-Za-z_][A-Za-z0-9_.-]*):(?:\s|$)');

  static Map<String, (int, int)> _topLevelRanges(List<String> lines) {
    final starts = <(String, int)>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.isEmpty || line.startsWith(' ') || line.startsWith('\t')) {
        continue;
      }
      final match = _keyLine.firstMatch(line);
      if (match != null) starts.add((match.group(1)!, index));
    }
    final ranges = <String, (int, int)>{};
    for (var index = 0; index < starts.length; index++) {
      final current = starts[index];
      ranges[current.$1] = (
        current.$2,
        index + 1 < starts.length ? starts[index + 1].$2 : lines.length,
      );
    }
    return ranges;
  }

  static List<String> _serializeField(String key, Object? value) {
    if (value is Iterable) {
      final items = value.toList(growable: false);
      if (items.isEmpty) return ['$key: []'];
      return [
        '$key:',
        for (final item in items) '  - ${_serializeScalar(item)}',
      ];
    }
    if (value is Map) {
      return ['$key: ${jsonEncode(_jsonSafe(value))}'];
    }
    return ['$key: ${_serializeScalar(value)}'];
  }

  static String _serializeScalar(Object? value) {
    if (value == null) return 'null';
    if (value is bool || value is num) return value.toString();
    if (value is DateTime) return jsonEncode(value.toUtc().toIso8601String());
    return jsonEncode(value.toString());
  }

  static dynamic _jsonSafe(dynamic value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) return value.map(_jsonSafe).toList();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }

  static Map<String, dynamic> _parseYamlMap(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final loaded = loadYaml(raw);
      if (loaded == null) return const {};
      if (loaded is! YamlMap && loaded is! Map) {
        throw ParsingFailure(
          'YAML frontmatter must contain a top-level mapping.',
          code: 'DD-FRONTMATTER-MAP',
        );
      }
      return Map<String, dynamic>.from(_plainYaml(loaded) as Map);
    } on Failure {
      rethrow;
    } on YamlException catch (error) {
      final line = error.span?.start.line;
      final location = line == null ? '' : ' near line ${line + 1}';
      throw ParsingFailure(
        'YAML frontmatter is malformed$location.',
        code: 'DD-FRONTMATTER-YAML',
      );
    } catch (_) {
      throw ParsingFailure(
        'YAML frontmatter could not be parsed safely.',
        code: 'DD-FRONTMATTER-YAML',
      );
    }
  }

  static dynamic _plainYaml(dynamic value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _plainYaml(entry.value),
      };
    }
    if (value is Iterable) return value.map(_plainYaml).toList();
    return value;
  }
}

class _LineReplacement {
  final int start;
  final int end;
  final List<String> lines;

  const _LineReplacement({
    required this.start,
    required this.end,
    required this.lines,
  });
}
