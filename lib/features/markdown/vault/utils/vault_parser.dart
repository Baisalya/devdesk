import '../model/vault_note.dart';

/// Utility class for parsing markdown content for vault-specific features.
class VaultParser {
  static final wikiLinkRegExp = RegExp(r'\[\[([^\]]+)\]\]');
  static final tagRegExp = RegExp(r'(^|\s)#([a-zA-Z][a-zA-Z0-9_/-]*)');
  static final secretRegExp = RegExp(
    r'\b(API_KEY|TOKEN|SECRET|PASSWORD|PRIVATE_KEY|Authorization|Bearer)\b\s*[:=]?\s*([A-Za-z0-9._~+/\-=]{4,})',
    caseSensitive: false,
  );
  static final externalUrlRegExp = RegExp(
    r'https?:\/\/[^\s<>)"\]]+',
    caseSensitive: false,
  );
  static final markdownLinkRegExp = RegExp(r'!?\[[^\]]*\]\(([^)]+)\)');

  /// Extracts Wiki links [[Note Name]] from text.
  static List<String> extractWikiLinks(String text) {
    return _unique(
      wikiLinkRegExp
          .allMatches(text)
          .map((m) => normalizeWikiTarget(m.group(1)!))
          .where((s) => s.isNotEmpty),
    );
  }

  static String normalizeWikiTarget(String raw) {
    final noAlias = raw.split('|').first;
    final noHeading = noAlias.split('#').first;
    return noHeading.trim();
  }

  /// Extracts inline tags #tag from text, ignoring YAML frontmatter.
  static List<String> extractTags(String text) {
    final body = parseFrontmatter(text).body;
    return _unique(
      tagRegExp
          .allMatches(body)
          .map((m) => m.group(2)!.trim())
          .where((s) => s.isNotEmpty),
    );
  }

  static List<String> extractMetadataTags(Map<String, dynamic> metadata) {
    final value = metadata['tags'] ?? metadata['tag'];
    if (value is Iterable) {
      return _unique(value.map((item) => item.toString().trim()));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        return _unique(
          trimmed.substring(1, trimmed.length - 1).split(',').map(
              (item) => item.trim().replaceAll('"', '').replaceAll("'", '')),
        );
      }
      return _unique(
        trimmed
            .split(RegExp(r'[, ]+'))
            .map((item) => item.trim().replaceFirst('#', '')),
      );
    }
    return const [];
  }

  static List<String> extractAllTags(String text) {
    final frontmatter = parseFrontmatter(text);
    return _unique([
      ...extractMetadataTags(frontmatter.metadata),
      ...extractTags(frontmatter.body),
    ]);
  }

  /// Checks if text contains potential secrets.
  static bool containsSecrets(String text) {
    return secretRegExp.hasMatch(text);
  }

  static String maskSecrets(String text) {
    return text.replaceAllMapped(secretRegExp, (match) {
      final keyword = match.group(1) ?? 'SECRET';
      return '$keyword=[masked]';
    });
  }

  /// Extracts headings for outline. Fenced code blocks are ignored.
  static List<MarkdownHeading> extractHeadings(String text) {
    final headings = <MarkdownHeading>[];
    final lines = text.split('\n');
    var inFence = false;
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimRight();
      if (trimmed.trimLeft().startsWith('```') ||
          trimmed.trimLeft().startsWith('~~~')) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;
      final match = RegExp(r'^(#{1,6})\s+(.+?)\s*#*$').firstMatch(trimmed);
      if (match != null) {
        headings.add(
          MarkdownHeading(
            level: match.group(1)!.length,
            text: match.group(2)!.trim(),
            lineIndex: i,
          ),
        );
      }
    }
    return headings;
  }

  static String generateTableOfContents(String text) {
    final headings = extractHeadings(text);
    final seen = <String, int>{};
    final lines = <String>[];
    for (final heading in headings) {
      final baseSlug = slugForHeading(heading.text);
      final count = seen[baseSlug] ?? 0;
      seen[baseSlug] = count + 1;
      final slug = count == 0 ? baseSlug : '$baseSlug-$count';
      final indent = List.filled(heading.level - 1, '  ').join();
      lines.add('$indent- [${heading.text}](#$slug)');
    }
    return lines.join('\n');
  }

  static String slugForHeading(String heading) {
    return heading
        .toLowerCase()
        .replaceAll(RegExp(r'[`*_~\[\]().,!?;:/\\]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// Strips frontmatter from markdown content for rendering.
  static String stripFrontmatter(String text) {
    return parseFrontmatter(text).body.trim();
  }

  static FrontmatterData parseFrontmatter(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('---\n')) {
      return FrontmatterData(metadata: const {}, body: text, raw: '');
    }
    final end = normalized.indexOf('\n---\n', 4);
    if (end == -1) {
      return FrontmatterData(metadata: const {}, body: text, raw: '');
    }
    final raw = normalized.substring(4, end);
    final body = normalized.substring(end + 5);
    return FrontmatterData(
      metadata: parseYamlMetadata(raw),
      body: body,
      raw: raw,
    );
  }

  static Map<String, dynamic> parseYamlMetadata(String raw) {
    final metadata = <String, dynamic>{};
    String? listKey;
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (listKey != null && trimmed.startsWith('- ')) {
        final list = metadata.putIfAbsent(listKey, () => <String>[]);
        if (list is List) {
          list.add(_unquote(trimmed.substring(2).trim()));
        }
        continue;
      }
      listKey = null;
      final separator = trimmed.indexOf(':');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (value.isEmpty) {
        metadata[key] = <String>[];
        listKey = key;
      } else if (value.startsWith('[') && value.endsWith(']')) {
        metadata[key] = value
            .substring(1, value.length - 1)
            .split(',')
            .map((item) => _unquote(item.trim()))
            .where((item) => item.isNotEmpty)
            .toList();
      } else {
        metadata[key] = _unquote(value);
      }
    }
    return metadata;
  }

  static String buildFrontmatter(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) return '';
    final buffer = StringBuffer()..writeln('---');
    for (final entry in metadata.entries) {
      final value = entry.value;
      if (value is Iterable) {
        buffer.writeln('${entry.key}:');
        for (final item in value) {
          buffer.writeln('- $item');
        }
      } else {
        buffer.writeln('${entry.key}: $value');
      }
    }
    buffer.writeln('---');
    return buffer.toString();
  }

  static MarkdownStats stats(String text) {
    final trimmed = text.trim();
    final words = trimmed.isEmpty
        ? 0
        : trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    return MarkdownStats(
      words: words,
      characters: text.length,
      readingMinutes: words == 0 ? 0 : (words / 200).ceil(),
    );
  }

  static List<String> extractExternalUrls(String text) {
    return _unique(externalUrlRegExp.allMatches(text).map((m) => m.group(0)!));
  }

  static List<String> extractLocalLinkPaths(String text) {
    return _unique(
      markdownLinkRegExp.allMatches(text).map((m) => m.group(1)!.trim()).where(
          (target) =>
              target.isNotEmpty &&
              !target.startsWith('#') &&
              !target.startsWith('http://') &&
              !target.startsWith('https://') &&
              !target.startsWith('mailto:') &&
              !target.startsWith('data:')),
    );
  }

  static List<String> brokenInternalLinks(
    VaultNote note,
    Iterable<VaultNote> allNotes,
  ) {
    final existing = allNotes.map((n) => n.title.toLowerCase()).toSet();
    return extractWikiLinks(note.content)
        .where((link) => !existing.contains(link.toLowerCase()))
        .toList();
  }

  static Map<String, List<String>> buildLinkMap(Iterable<VaultNote> notes) {
    return {
      for (final note in notes) note.title: extractWikiLinks(note.content),
    };
  }

  static List<String> notesLinkingTo(
    VaultNote target,
    Iterable<VaultNote> notes,
  ) {
    final targetTitle = target.title.toLowerCase();
    return notes
        .where((note) =>
            note.id != target.id &&
            extractWikiLinks(note.content)
                .map((link) => link.toLowerCase())
                .contains(targetTitle))
        .map((note) => note.title)
        .toList()
      ..sort();
  }

  static List<VaultSearchResult> searchNotes(
    Iterable<VaultNote> notes,
    String query, {
    bool fullText = true,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return notes
          .map((note) =>
              VaultSearchResult(note: note, matchPreview: note.fullPath))
          .toList();
    }
    final results = <VaultSearchResult>[];
    for (final note in notes) {
      final titleIndex = note.title.toLowerCase().indexOf(normalized);
      if (titleIndex >= 0) {
        results.add(VaultSearchResult(note: note, matchPreview: note.fullPath));
        continue;
      }
      if (!fullText) continue;
      final contentIndex = note.content.toLowerCase().indexOf(normalized);
      if (contentIndex >= 0) {
        results.add(
          VaultSearchResult(
            note: note,
            matchPreview: _previewAround(note.content, contentIndex),
          ),
        );
      }
    }
    return results;
  }

  static List<String> _unique(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) result.add(trimmed);
    }
    return result;
  }

  static String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static String _previewAround(String content, int index) {
    final start = index - 36 < 0 ? 0 : index - 36;
    final end = index + 96 > content.length ? content.length : index + 96;
    return content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
  }
}

class FrontmatterData {
  final Map<String, dynamic> metadata;
  final String body;
  final String raw;

  const FrontmatterData({
    required this.metadata,
    required this.body,
    required this.raw,
  });
}

class MarkdownHeading {
  final int level;
  final String text;
  final int lineIndex;

  const MarkdownHeading({
    required this.level,
    required this.text,
    required this.lineIndex,
  });
}

class MarkdownStats {
  final int words;
  final int characters;
  final int readingMinutes;

  const MarkdownStats({
    required this.words,
    required this.characters,
    required this.readingMinutes,
  });
}

class VaultSearchResult {
  final VaultNote note;
  final String matchPreview;

  const VaultSearchResult({
    required this.note,
    required this.matchPreview,
  });
}
