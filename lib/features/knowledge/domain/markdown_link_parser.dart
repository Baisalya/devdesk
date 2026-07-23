import 'knowledge_models.dart';

class MarkdownLinkParser {
  const MarkdownLinkParser._();

  static final _wikiLink = RegExp(r'\[\[([^\]]+)\]\]');
  static final _markdownLink = RegExp(
    r'''(!?)\[([^\]]*)\]\(([^\s\)]+)(?:\s+["'][^\)]*["'])?\)''',
  );

  static List<KnowledgeReference> parse(String source) {
    final references = <KnowledgeReference>[];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    var fence = '';
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final original = lines[lineIndex];
      final trimmed = original.trimLeft();
      final marker = trimmed.startsWith('```')
          ? '```'
          : trimmed.startsWith('~~~')
              ? '~~~'
              : '';
      if (marker.isNotEmpty) {
        if (fence.isEmpty) {
          fence = marker;
        } else if (fence == marker) {
          fence = '';
        }
        continue;
      }
      if (fence.isNotEmpty) continue;
      final line = _withoutInlineCode(original);
      for (final match in _wikiLink.allMatches(line)) {
        final expression = match.group(1)!.trim();
        final aliasParts = expression.split('|');
        final targetAndHeading = aliasParts.first.trim().split('#');
        final target = targetAndHeading.first.trim();
        if (target.isEmpty) continue;
        references.add(
          KnowledgeReference(
            kind: KnowledgeReferenceKind.wikiLink,
            target: target,
            heading: targetAndHeading.length > 1
                ? targetAndHeading.sublist(1).join('#').trim()
                : null,
            displayText: aliasParts.length > 1
                ? aliasParts.sublist(1).join('|').trim()
                : null,
            line: lineIndex + 1,
          ),
        );
      }
      for (final match in _markdownLink.allMatches(line)) {
        final target = match.group(3)!.trim();
        if (target.isEmpty || target.startsWith('#')) continue;
        references.add(
          KnowledgeReference(
            kind: match.group(1) == '!'
                ? KnowledgeReferenceKind.image
                : KnowledgeReferenceKind.markdownLink,
            target: target,
            displayText: match.group(2),
            line: lineIndex + 1,
            external: _isExternal(target),
          ),
        );
      }
    }
    return references;
  }

  static String _withoutInlineCode(String line) {
    final buffer = StringBuffer();
    var inCode = false;
    var ticks = 0;
    for (var index = 0; index < line.length; index++) {
      if (line[index] == '`') {
        var count = 1;
        while (index + count < line.length && line[index + count] == '`') {
          count++;
        }
        if (!inCode) {
          inCode = true;
          ticks = count;
        } else if (count == ticks) {
          inCode = false;
          ticks = 0;
        }
        buffer.write(' ' * count);
        index += count - 1;
      } else {
        buffer.write(inCode ? ' ' : line[index]);
      }
    }
    return buffer.toString();
  }

  static bool _isExternal(String target) {
    final lower = target.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('data:') ||
        lower.startsWith('api://') ||
        lower.startsWith('git://') ||
        lower.startsWith('workspace://') ||
        lower.startsWith('okf://');
  }
}
