enum DiffSource {
  text,
  file,
  folder,
  github,
  git,
  snippet,
  api,
}

class DiffContent {
  final String content;
  final String? label;
  final String? path;
  final DiffSource source;

  const DiffContent({
    required this.content,
    this.label,
    this.path,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'label': label,
      'path': path,
      'source': source.name,
    };
  }

  factory DiffContent.fromMap(Map<String, dynamic> map) {
    return DiffContent(
      content: map['content'] as String,
      label: map['label'] as String?,
      path: map['path'] as String?,
      source: DiffSource.values.byName(map['source'] as String),
    );
  }
}

class DiffOptions {
  final bool ignoreWhitespace;
  final bool ignoreCase;
  final bool ignoreEmptyLines;
  final bool trimLineEndings;
  final bool normalizeLineEndings;
  final bool jsonKeyOrderIgnore;

  const DiffOptions({
    this.ignoreWhitespace = false,
    this.ignoreCase = false,
    this.ignoreEmptyLines = false,
    this.trimLineEndings = true,
    this.normalizeLineEndings = true,
    this.jsonKeyOrderIgnore = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'ignoreWhitespace': ignoreWhitespace,
      'ignoreCase': ignoreCase,
      'ignoreEmptyLines': ignoreEmptyLines,
      'trimLineEndings': trimLineEndings,
      'normalizeLineEndings': normalizeLineEndings,
      'jsonKeyOrderIgnore': jsonKeyOrderIgnore,
    };
  }

  factory DiffOptions.fromMap(Map<String, dynamic> map) {
    return DiffOptions(
      ignoreWhitespace: map['ignoreWhitespace'] as bool? ?? false,
      ignoreCase: map['ignoreCase'] as bool? ?? false,
      ignoreEmptyLines: map['ignoreEmptyLines'] as bool? ?? false,
      trimLineEndings: map['trimLineEndings'] as bool? ?? true,
      normalizeLineEndings: map['normalizeLineEndings'] as bool? ?? true,
      jsonKeyOrderIgnore: map['jsonKeyOrderIgnore'] as bool? ?? true,
    );
  }
}

class DiffSummary {
  final int added;
  final int removed;
  final int unchanged;
  final int changedBlocks;

  const DiffSummary({
    required this.added,
    required this.removed,
    required this.unchanged,
    required this.changedBlocks,
  });

  Map<String, dynamic> toMap() {
    return {
      'added': added,
      'removed': removed,
      'unchanged': unchanged,
      'changedBlocks': changedBlocks,
    };
  }

  factory DiffSummary.fromMap(Map<String, dynamic> map) {
    return DiffSummary(
      added: map['added'] as int,
      removed: map['removed'] as int,
      unchanged: map['unchanged'] as int,
      changedBlocks: map['changedBlocks'] as int,
    );
  }
}

class DiffSession {
  final String id;
  final String title;
  final DiffContent left;
  final DiffContent right;
  final DiffOptions options;
  final DateTime createdAt;
  final DiffSummary? summary;

  const DiffSession({
    required this.id,
    required this.title,
    required this.left,
    required this.right,
    required this.options,
    required this.createdAt,
    this.summary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'left': left.toMap(),
      'right': right.toMap(),
      'options': options.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'summary': summary?.toMap(),
    };
  }

  factory DiffSession.fromMap(Map<String, dynamic> map) {
    return DiffSession(
      id: map['id'] as String,
      title: map['title'] as String,
      left: DiffContent.fromMap(map['left'] as Map<String, dynamic>),
      right: DiffContent.fromMap(map['right'] as Map<String, dynamic>),
      options: DiffOptions.fromMap(map['options'] as Map<String, dynamic>),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      summary: map['summary'] != null
          ? DiffSummary.fromMap(map['summary'] as Map<String, dynamic>)
          : null,
    );
  }
}
