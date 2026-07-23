import 'okf_models.dart';

class OkfTemplateService {
  const OkfTemplateService._();

  static String create(
    OkfTemplateType template, {
    required String title,
    String? stableId,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc().toIso8601String();
    final type = switch (template) {
      OkfTemplateType.concept => 'Concept',
      OkfTemplateType.apiEndpoint => 'API Endpoint',
      OkfTemplateType.apiCollection => 'API Collection',
      OkfTemplateType.dataModel => 'Data Model',
      OkfTemplateType.architectureDecision => 'Architecture Decision Record',
      OkfTemplateType.runbook => 'Runbook',
      OkfTemplateType.policy => 'Policy',
      OkfTemplateType.troubleshooting => 'Troubleshooting Guide',
      OkfTemplateType.prompt => 'Prompt',
      OkfTemplateType.aiEvaluation => 'AI Evaluation',
      OkfTemplateType.releaseNote => 'Release Note',
      OkfTemplateType.changelogEntry => 'Changelog Entry',
      OkfTemplateType.projectDocumentation => 'Project Documentation',
    };
    final body = switch (template) {
      OkfTemplateType.apiEndpoint => '# Request\n\n# Response\n\n# Examples',
      OkfTemplateType.architectureDecision =>
        '# Context\n\n# Decision\n\n# Consequences',
      OkfTemplateType.runbook =>
        '# Trigger\n\n# Preconditions\n\n# Steps\n\n# Recovery',
      OkfTemplateType.policy => '# Policy\n\n# Scope\n\n# Exceptions',
      OkfTemplateType.troubleshooting =>
        '# Symptoms\n\n# Diagnosis\n\n# Resolution',
      OkfTemplateType.prompt => '# Purpose\n\n# Prompt\n\n# Constraints',
      OkfTemplateType.aiEvaluation =>
        '# Objective\n\n# Dataset\n\n# Criteria\n\n# Results',
      OkfTemplateType.releaseNote =>
        '# Highlights\n\n# Changes\n\n# Known issues',
      OkfTemplateType.changelogEntry => '# Changed\n\n# Fixed\n\n# Security',
      _ => '# Overview\n\n# Details\n\n# Examples',
    };
    return '''---
type: "$type"
title: "${_escape(title)}"
description: ""
tags: []
timestamp: "$timestamp"
${stableId == null || stableId.trim().isEmpty ? '' : 'stable_id: "${_escape(stableId.trim())}"\n'}status: active
verified_at: null
review_after: null
deprecated: false
---
$body
''';
  }

  static String _escape(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }
}
