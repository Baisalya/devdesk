import 'package:flutter/foundation.dart';

enum OkfSeverity { error, warning, recommendation, information }

enum OkfTemplateType {
  concept,
  apiEndpoint,
  apiCollection,
  dataModel,
  architectureDecision,
  runbook,
  policy,
  troubleshooting,
  prompt,
  aiEvaluation,
  releaseNote,
  changelogEntry,
  projectDocumentation,
}

@immutable
class OkfValidationIssue {
  final String code;
  final OkfSeverity severity;
  final String message;
  final String? relativePath;
  final String? remediation;

  const OkfValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.relativePath,
    this.remediation,
  });
}

@immutable
class OkfHealthReport {
  final String specificationVersion;
  final bool detected;
  final int totalConcepts;
  final int validConcepts;
  final int reservedFiles;
  final int unverifiedConcepts;
  final int reviewDueConcepts;
  final int deprecatedConcepts;
  final List<OkfValidationIssue> issues;
  final DateTime generatedAt;

  const OkfHealthReport({
    required this.specificationVersion,
    required this.detected,
    required this.totalConcepts,
    required this.validConcepts,
    required this.reservedFiles,
    required this.unverifiedConcepts,
    required this.reviewDueConcepts,
    required this.deprecatedConcepts,
    required this.issues,
    required this.generatedAt,
  });

  int count(OkfSeverity severity) {
    return issues.where((issue) => issue.severity == severity).length;
  }

  bool get conformant => detected && count(OkfSeverity.error) == 0;

  Map<String, dynamic> toMap() {
    return {
      'specificationVersion': specificationVersion,
      'detected': detected,
      'conformant': conformant,
      'totalConcepts': totalConcepts,
      'validConcepts': validConcepts,
      'reservedFiles': reservedFiles,
      'unverifiedConcepts': unverifiedConcepts,
      'reviewDueConcepts': reviewDueConcepts,
      'deprecatedConcepts': deprecatedConcepts,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'issues': [
        for (final issue in issues)
          {
            'code': issue.code,
            'severity': issue.severity.name,
            'message': issue.message,
            'relativePath': issue.relativePath,
            'remediation': issue.remediation,
          },
      ],
    };
  }
}

@immutable
class OkfPlannedWrite {
  final String relativePath;
  final String content;
  final bool create;
  final String? expectedFingerprint;
  final String reason;

  const OkfPlannedWrite({
    required this.relativePath,
    required this.content,
    required this.create,
    required this.reason,
    this.expectedFingerprint,
  });
}

@immutable
class OkfGenerationPlan {
  final List<OkfPlannedWrite> writes;
  final List<String> skipped;

  const OkfGenerationPlan({
    required this.writes,
    this.skipped = const [],
  });

  bool get isEmpty => writes.isEmpty;
}
