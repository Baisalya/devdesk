import 'package:path/path.dart' as p;

import 'knowledge_models.dart';

class KnowledgeGraphBuilder {
  const KnowledgeGraphBuilder._();

  static KnowledgeGraph build(Iterable<KnowledgeDocument> source) {
    final documents = source.toList(growable: false);
    final aliases = <String, Set<String>>{};
    final titleOwners = <String, List<KnowledgeDocument>>{};
    final stableOwners = <String, List<KnowledgeDocument>>{};
    for (final document in documents) {
      final titleKey = _key(document.title);
      titleOwners.putIfAbsent(titleKey, () => []).add(document);
      if (document.stableId?.trim() case final stableId?
          when stableId.isNotEmpty) {
        stableOwners.putIfAbsent(_key(stableId), () => []).add(document);
      }
      for (final alias in _aliases(document)) {
        aliases.putIfAbsent(alias, () => <String>{}).add(document.id);
      }
    }

    final outgoing = {
      for (final document in documents) document.id: <String>{}
    };
    final backlinks = {
      for (final document in documents) document.id: <String>{}
    };
    final issues = <KnowledgeIssue>[];
    for (final entry in titleOwners.entries) {
      if (entry.value.length < 2) continue;
      for (final document in entry.value) {
        issues.add(
          KnowledgeIssue(
            kind: KnowledgeIssueKind.duplicateTitle,
            documentId: document.id,
            message: 'Multiple documents use the title "${document.title}".',
          ),
        );
      }
    }
    for (final entry in stableOwners.entries) {
      if (entry.value.length < 2) continue;
      for (final document in entry.value) {
        issues.add(
          KnowledgeIssue(
            kind: KnowledgeIssueKind.duplicateStableId,
            documentId: document.id,
            message:
                'Stable ID "${document.stableId}" is used by more than one document.',
          ),
        );
      }
    }

    for (final document in documents) {
      for (final reference in document.outgoingReferences) {
        if (reference.external) continue;
        final candidates = <String>{};
        for (final targetKey in _referenceKeys(document, reference)) {
          candidates.addAll(aliases[targetKey] ?? const <String>{});
        }
        if (candidates.length == 1) {
          final target = candidates.single;
          outgoing[document.id]!.add(target);
          backlinks[target]!.add(document.id);
        } else if (candidates.isEmpty) {
          issues.add(
            KnowledgeIssue(
              kind: KnowledgeIssueKind.brokenLink,
              documentId: document.id,
              target: reference.target,
              message:
                  'Link target "${reference.target}" does not exist in this workspace.',
            ),
          );
        }
      }
    }
    for (final document in documents) {
      if (documents.length > 1 &&
          outgoing[document.id]!.isEmpty &&
          backlinks[document.id]!.isEmpty) {
        issues.add(
          KnowledgeIssue(
            kind: KnowledgeIssueKind.orphanDocument,
            documentId: document.id,
            message: 'This document has no resolved links to other documents.',
          ),
        );
      }
    }
    return KnowledgeGraph(
      documents: documents,
      outgoing: outgoing,
      backlinks: backlinks,
      issues: issues,
    );
  }

  static Set<String> _aliases(KnowledgeDocument document) {
    final slashPath = document.relativePath.replaceAll('\\', '/');
    final withoutExtension = p.withoutExtension(slashPath);
    final base = p.basenameWithoutExtension(slashPath);
    return {
      _key(document.title),
      _key(slashPath),
      _key(withoutExtension),
      _key(base),
      if (document.stableId != null) _key(document.stableId!),
      if (!slashPath.startsWith('/')) _key('/$slashPath'),
    };
  }

  static List<String> _referenceKeys(
    KnowledgeDocument source,
    KnowledgeReference reference,
  ) {
    var target = Uri.decodeComponent(reference.target.split('#').first)
        .replaceAll('\\', '/');
    if (reference.kind == KnowledgeReferenceKind.wikiLink) {
      if (!target.contains('/')) return [_key(target)];
      final sourceDirectory = p.posix.dirname(
        source.relativePath.replaceAll('\\', '/'),
      );
      return [
        _key(target),
        _key(p.posix.normalize(p.posix.join(sourceDirectory, target))),
      ];
    }
    if (target.startsWith('/')) return [_key(target)];
    final sourceDirectory = p.posix.dirname(
      source.relativePath.replaceAll('\\', '/'),
    );
    target = p.posix.normalize(p.posix.join(sourceDirectory, target));
    return [_key(target)];
  }

  static String _key(String value) {
    return value.trim().replaceAll('\\', '/').toLowerCase();
  }
}
