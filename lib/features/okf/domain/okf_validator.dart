import 'package:path/path.dart' as p;

import '../../knowledge/domain/knowledge_models.dart';
import 'okf_models.dart';

class OkfValidator {
  static const specificationVersion = '0.1';

  const OkfValidator._();

  static OkfHealthReport validate(
    WorkspaceKnowledgeSnapshot snapshot, {
    DateTime? now,
  }) {
    final checkedAt = (now ?? DateTime.now()).toUtc();
    final issues = <OkfValidationIssue>[];
    final concepts = snapshot.graph.documents
        .where((document) => !_isReserved(document.relativePath))
        .toList(growable: false);
    final reserved = snapshot.graph.documents.length - concepts.length;
    final paths = snapshot.graph.documents
        .map((document) => document.relativePath.replaceAll('\\', '/'))
        .toSet();
    final directories = <String>{''};
    for (final concept in concepts) {
      final directory = p.posix.dirname(concept.relativePath);
      var current = directory == '.' ? '' : directory;
      while (true) {
        directories.add(current);
        if (current.isEmpty) break;
        final parent = p.posix.dirname(current);
        current = parent == '.' ? '' : parent;
      }
    }
    for (final directory in directories) {
      final indexPath = directory.isEmpty ? 'index.md' : '$directory/index.md';
      if (!paths.contains(indexPath)) {
        issues.add(
          OkfValidationIssue(
            code: 'OKF-INDEX-MISSING',
            severity: OkfSeverity.recommendation,
            relativePath: indexPath,
            message:
                'This directory has no optional index.md for progressive disclosure.',
            remediation:
                'Preview and generate an index without replacing custom prose.',
          ),
        );
      }
    }

    var unverified = 0;
    var reviewDue = 0;
    var deprecated = 0;
    final documentsWithErrors = <String>{};
    for (final concept in concepts) {
      final fields = concept.frontmatter.fields;
      if (!concept.frontmatter.hasFrontmatter) {
        _addError(
          issues,
          documentsWithErrors,
          concept,
          code: 'OKF-FRONTMATTER-MISSING',
          message: 'Concept documents require YAML frontmatter.',
        );
      }
      if (concept.type.trim().isEmpty) {
        _addError(
          issues,
          documentsWithErrors,
          concept,
          code: 'OKF-TYPE-MISSING',
          message: 'Concept frontmatter requires a non-empty type field.',
        );
      }
      for (final field in const [
        'timestamp',
        'created',
        'updated',
        'verified_at',
        'review_after',
      ]) {
        final value = fields[field];
        if (value != null &&
            value.toString().trim().isNotEmpty &&
            DateTime.tryParse(value.toString()) == null) {
          issues.add(
            OkfValidationIssue(
              code: 'OKF-TIMESTAMP-INVALID',
              severity: OkfSeverity.warning,
              relativePath: concept.relativePath,
              message: '$field is not a valid ISO 8601 timestamp.',
              remediation: 'Use an ISO 8601 date or date-time value.',
            ),
          );
        }
      }
      final verified = fields['verified_at']?.toString().trim() ?? '';
      if (verified.isEmpty) unverified++;
      final review =
          DateTime.tryParse(fields['review_after']?.toString() ?? '');
      if (review != null && review.toUtc().isBefore(checkedAt)) {
        reviewDue++;
        issues.add(
          OkfValidationIssue(
            code: 'OKF-REVIEW-DUE',
            severity: OkfSeverity.recommendation,
            relativePath: concept.relativePath,
            message: 'The DevDesk review_after date has passed.',
          ),
        );
      }
      final isDeprecated = fields['deprecated'] == true ||
          fields['status']?.toString().toLowerCase() == 'deprecated';
      if (isDeprecated) {
        deprecated++;
        final replacement = fields['supersedes'] ??
            fields['replacement'] ??
            fields['replaced_by'];
        if (replacement == null || replacement.toString().trim().isEmpty) {
          issues.add(
            OkfValidationIssue(
              code: 'OKF-DEPRECATED-NO-REPLACEMENT',
              severity: OkfSeverity.warning,
              relativePath: concept.relativePath,
              message:
                  'Deprecated concept has no DevDesk replacement reference.',
            ),
          );
        }
      }
    }

    for (final issue in snapshot.scanIssues) {
      issues.add(
        OkfValidationIssue(
          code: issue.kind == KnowledgeIssueKind.malformedDocument
              ? 'OKF-YAML-MALFORMED'
              : 'OKF-DOCUMENT-SKIPPED',
          severity: OkfSeverity.error,
          relativePath: _pathFromDocumentId(issue.documentId),
          message: issue.message,
        ),
      );
      documentsWithErrors.add(issue.documentId);
    }
    for (final issue in snapshot.graph.issues) {
      final mapped = switch (issue.kind) {
        KnowledgeIssueKind.brokenLink => const (
            'OKF-LINK-BROKEN',
            OkfSeverity.warning,
          ),
        KnowledgeIssueKind.orphanDocument => const (
            'OKF-CONCEPT-ORPHAN',
            OkfSeverity.recommendation,
          ),
        KnowledgeIssueKind.duplicateStableId => const (
            'OKF-STABLE-ID-DUPLICATE',
            OkfSeverity.error,
          ),
        KnowledgeIssueKind.duplicateTitle => const (
            'OKF-TITLE-DUPLICATE',
            OkfSeverity.information,
          ),
        KnowledgeIssueKind.malformedDocument ||
        KnowledgeIssueKind.skippedDocument =>
          const (
            'OKF-DOCUMENT-INVALID',
            OkfSeverity.error,
          ),
      };
      issues.add(
        OkfValidationIssue(
          code: mapped.$1,
          severity: mapped.$2,
          relativePath: _pathFromDocumentId(issue.documentId),
          message: issue.message,
        ),
      );
      if (mapped.$2 == OkfSeverity.error) {
        documentsWithErrors.add(issue.documentId);
      }
    }
    issues.sort((left, right) {
      final severity = left.severity.index.compareTo(right.severity.index);
      if (severity != 0) return severity;
      return (left.relativePath ?? '').compareTo(right.relativePath ?? '');
    });
    final detected = concepts.isNotEmpty || reserved > 0;
    final conceptIds = concepts.map((concept) => concept.id).toSet();
    final invalidConcepts =
        documentsWithErrors.where(conceptIds.contains).length;
    return OkfHealthReport(
      specificationVersion: specificationVersion,
      detected: detected,
      totalConcepts: concepts.length,
      validConcepts: concepts.length - invalidConcepts,
      reservedFiles: reserved,
      unverifiedConcepts: unverified,
      reviewDueConcepts: reviewDue,
      deprecatedConcepts: deprecated,
      issues: issues,
      generatedAt: checkedAt,
    );
  }

  static void _addError(
    List<OkfValidationIssue> issues,
    Set<String> documentsWithErrors,
    KnowledgeDocument document, {
    required String code,
    required String message,
  }) {
    issues.add(
      OkfValidationIssue(
        code: code,
        severity: OkfSeverity.error,
        relativePath: document.relativePath,
        message: message,
      ),
    );
    documentsWithErrors.add(document.id);
  }

  static bool _isReserved(String path) {
    final name = p.posix.basename(path.replaceAll('\\', '/')).toLowerCase();
    return name == 'index.md' || name == 'log.md';
  }

  static String _pathFromDocumentId(String value) {
    final separator = value.indexOf(':');
    return separator < 0 ? value : value.substring(separator + 1);
  }
}
