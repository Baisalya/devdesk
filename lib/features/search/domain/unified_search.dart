import 'package:flutter/foundation.dart';

enum SearchEntityKind {
  workspace,
  markdown,
  apiCollection,
  apiRequest,
  openApiOperation,
  gitFile,
}

@immutable
class SearchRecord {
  final String id;
  final SearchEntityKind kind;
  final String title;
  final String subtitle;
  final String searchableText;
  final String reference;
  final Map<String, String> metadata;

  const SearchRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.searchableText,
    required this.reference,
    this.metadata = const {},
  });
}

@immutable
class SearchHit {
  final SearchRecord record;
  final int score;

  const SearchHit(this.record, this.score);
}

class UnifiedSearchIndex {
  final List<SearchRecord> _records;

  UnifiedSearchIndex(Iterable<SearchRecord> records)
      : _records = List.unmodifiable(records);

  List<SearchHit> search(
    String query, {
    Set<SearchEntityKind> kinds = const {},
    int limit = 100,
  }) {
    final terms = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty || limit <= 0) return const [];
    final hits = <SearchHit>[];
    for (final record in _records) {
      if (kinds.isNotEmpty && !kinds.contains(record.kind)) continue;
      final title = record.title.toLowerCase();
      final haystack = '${record.title} ${record.subtitle} '
              '${record.searchableText} ${record.metadata.values.join(' ')}'
          .toLowerCase();
      if (!terms.every(haystack.contains)) continue;
      var score = 0;
      for (final term in terms) {
        if (title == term) score += 100;
        if (title.startsWith(term)) score += 40;
        if (title.contains(term)) score += 20;
        score += _occurrences(haystack, term).clamp(0, 10);
      }
      hits.add(SearchHit(record, score));
    }
    hits.sort((left, right) {
      final score = right.score.compareTo(left.score);
      return score != 0
          ? score
          : left.record.title.compareTo(right.record.title);
    });
    return hits.take(limit).toList(growable: false);
  }

  static int _occurrences(String source, String term) {
    var count = 0;
    var offset = 0;
    while ((offset = source.indexOf(term, offset)) != -1) {
      count++;
      offset += term.length;
    }
    return count;
  }
}

@immutable
class TypedReference {
  final String scheme;
  final String target;
  final String? fragment;

  const TypedReference({
    required this.scheme,
    required this.target,
    this.fragment,
  });

  static const supportedSchemes = {
    'workspace',
    'file',
    'api-collection',
    'api-request',
    'openapi',
    'git',
  };

  static TypedReference? tryParse(String source) {
    final separator = source.indexOf(':');
    if (separator <= 0 || separator == source.length - 1) return null;
    final scheme = source.substring(0, separator).toLowerCase();
    if (!supportedSchemes.contains(scheme)) return null;
    final value = source.substring(separator + 1);
    final fragmentIndex = value.indexOf('#');
    final target =
        fragmentIndex == -1 ? value : value.substring(0, fragmentIndex);
    if (target.trim().isEmpty || target.contains('\u0000')) return null;
    return TypedReference(
      scheme: scheme,
      target: target,
      fragment: fragmentIndex == -1 ? null : value.substring(fragmentIndex + 1),
    );
  }
}

class TypedReferenceResolver {
  final Map<String, SearchRecord> _byReference;

  TypedReferenceResolver(Iterable<SearchRecord> records)
      : _byReference = {
          for (final record in records) record.reference: record,
        };

  SearchRecord? resolve(String reference) {
    if (TypedReference.tryParse(reference) == null) return null;
    return _byReference[reference];
  }
}
