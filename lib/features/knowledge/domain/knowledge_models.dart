import 'package:flutter/foundation.dart';

import 'frontmatter_document.dart';

enum KnowledgeReferenceKind { wikiLink, markdownLink, image }

@immutable
class KnowledgeReference {
  final KnowledgeReferenceKind kind;
  final String target;
  final String? displayText;
  final String? heading;
  final int line;
  final bool external;

  const KnowledgeReference({
    required this.kind,
    required this.target,
    required this.line,
    this.displayText,
    this.heading,
    this.external = false,
  });
}

@immutable
class KnowledgeDocument {
  final String workspaceId;
  final String relativePath;
  final String title;
  final String type;
  final String? stableId;
  final String description;
  final List<String> tags;
  final FrontmatterDocument frontmatter;
  final List<KnowledgeReference> outgoingReferences;
  final String fingerprint;
  final DateTime modifiedAt;
  final int sizeBytes;

  const KnowledgeDocument({
    required this.workspaceId,
    required this.relativePath,
    required this.title,
    required this.type,
    required this.description,
    required this.tags,
    required this.frontmatter,
    required this.outgoingReferences,
    required this.fingerprint,
    required this.modifiedAt,
    required this.sizeBytes,
    this.stableId,
  });

  String get id => '$workspaceId:$relativePath';
}

enum KnowledgeIssueKind {
  brokenLink,
  duplicateTitle,
  duplicateStableId,
  orphanDocument,
  malformedDocument,
  skippedDocument,
}

@immutable
class KnowledgeIssue {
  final KnowledgeIssueKind kind;
  final String documentId;
  final String message;
  final String? target;

  const KnowledgeIssue({
    required this.kind,
    required this.documentId,
    required this.message,
    this.target,
  });
}

@immutable
class KnowledgeGraph {
  final List<KnowledgeDocument> documents;
  final Map<String, Set<String>> outgoing;
  final Map<String, Set<String>> backlinks;
  final List<KnowledgeIssue> issues;

  const KnowledgeGraph({
    required this.documents,
    required this.outgoing,
    required this.backlinks,
    required this.issues,
  });
}

@immutable
class WorkspaceKnowledgeSnapshot {
  final KnowledgeGraph graph;
  final List<KnowledgeIssue> scanIssues;
  final int scannedMarkdownFiles;
  final int indexedBytes;
  final bool truncated;
  final DateTime generatedAt;

  const WorkspaceKnowledgeSnapshot({
    required this.graph,
    required this.scanIssues,
    required this.scannedMarkdownFiles,
    required this.indexedBytes,
    required this.truncated,
    required this.generatedAt,
  });

  List<KnowledgeIssue> get issues => [...scanIssues, ...graph.issues];
}

@immutable
class KnowledgeDraft {
  final String workspaceId;
  final String relativePath;
  final String content;
  final String baseFingerprint;
  final DateTime updatedAt;

  const KnowledgeDraft({
    required this.workspaceId,
    required this.relativePath,
    required this.content,
    required this.baseFingerprint,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'workspaceId': workspaceId,
      'relativePath': relativePath,
      'content': content,
      'baseFingerprint': baseFingerprint,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory KnowledgeDraft.fromMap(Map<dynamic, dynamic> map) {
    return KnowledgeDraft(
      workspaceId: map['workspaceId']?.toString() ?? '',
      relativePath: map['relativePath']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      baseFingerprint: map['baseFingerprint']?.toString() ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}
