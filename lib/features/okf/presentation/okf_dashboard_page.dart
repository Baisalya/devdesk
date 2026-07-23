import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../knowledge/domain/knowledge_models.dart';
import '../../../core/widgets/app_input_dialog.dart';
import '../../knowledge/provider/knowledge_workspace_provider.dart';
import '../../workspaces/domain/workspace_models.dart';
import '../../workspaces/provider/workspace_provider.dart';
import '../data/okf_workspace_service.dart';
import '../domain/okf_models.dart';
import '../domain/okf_template_service.dart';
import '../domain/okf_validator.dart';

class OkfDashboardPage extends ConsumerStatefulWidget {
  final String workspaceId;

  const OkfDashboardPage({
    super.key,
    required this.workspaceId,
  });

  @override
  ConsumerState<OkfDashboardPage> createState() => _OkfDashboardPageState();
}

class _OkfDashboardPageState extends ConsumerState<OkfDashboardPage> {
  DeveloperWorkspace? _workspace;
  WorkspaceKnowledgeSnapshot? _snapshot;
  OkfHealthReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workspace = await ref
          .read(workspaceRepositoryProvider)
          .getById(widget.workspaceId);
      if (workspace == null) throw StateError('Workspace is not registered.');
      final snapshot =
          await ref.read(knowledgeRepositoryProvider).indexWorkspace(workspace);
      final report = OkfValidator.validate(snapshot);
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _snapshot = snapshot;
        _report = report;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'OKF validation could not be completed. Workspace files were not changed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OKF health'),
        actions: [
          IconButton(
            tooltip: 'Export validation report',
            onPressed: report == null ? null : _exportReport,
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Refresh validation',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingState(label: 'Validating OKF workspace...')
            : _error != null
                ? Padding(
                    padding: AppSpacing.page(context),
                    child: AppErrorState(message: _error!),
                  )
                : report == null
                    ? const AppEmptyState(
                        icon: Icons.health_and_safety_outlined,
                        title: 'No OKF report',
                        message: 'Open a workspace and run validation.',
                      )
                    : _ReportBody(
                        report: report,
                        onGenerateIndexes: _planIndexes,
                        onCreateTemplate: _createTemplate,
                        onAddLog: _addLogEntry,
                      ),
      ),
    );
  }

  Future<void> _planIndexes() async {
    final workspace = _workspace;
    final snapshot = _snapshot;
    if (workspace == null || snapshot == null) return;
    final service = OkfWorkspaceService(ref.read(knowledgeRepositoryProvider));
    final plan = await service.planIndexes(workspace, snapshot);
    if (!mounted) return;
    if (plan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All generated index sections are current.')),
      );
      return;
    }
    final apply = await _previewPlan('Generate OKF indexes', plan);
    if (apply != true) return;
    try {
      await service.applyPlan(workspace, plan);
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'The index plan could not be applied safely. Existing custom content was preserved.';
      });
    }
  }

  Future<void> _addLogEntry() async {
    final workspace = _workspace;
    final snapshot = _snapshot;
    if (workspace == null || snapshot == null) return;
    final message = await showDialog<String>(
      context: context,
      builder: (context) => const AppTextInputDialog(
        title: 'Add OKF log entry',
        labelText: 'Update summary',
        hintText: 'Added customer authentication runbook.',
        maxLines: 3,
        actionLabel: 'Preview',
      ),
    );
    if (message == null || message.trim().isEmpty) return;
    final service = OkfWorkspaceService(ref.read(knowledgeRepositoryProvider));
    final plan = await service.planLogEntry(
      workspace,
      snapshot,
      action: 'Update',
      message: message,
    );
    if (!mounted || await _previewPlan('Update OKF log', plan) != true) return;
    await service.applyPlan(workspace, plan);
    await _refresh();
  }

  Future<void> _createTemplate() async {
    final workspace = _workspace;
    if (workspace == null) return;
    var type = OkfTemplateType.concept;
    final title = TextEditingController();
    final path = TextEditingController();
    final stableId = TextEditingController();
    final result = await showDialog<(OkfTemplateType, String, String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create OKF concept'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<OkfTemplateType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: [
                      for (final value in OkfTemplateType.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: path,
                    decoration: const InputDecoration(
                      labelText: 'Relative Markdown path',
                      hintText: 'concepts/customer-api.md',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: stableId,
                    decoration: const InputDecoration(
                      labelText: 'Stable ID (DevDesk extension, optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                (type, title.text, path.text, stableId.text),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    path.dispose();
    stableId.dispose();
    if (result == null ||
        result.$2.trim().isEmpty ||
        result.$3.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(knowledgeRepositoryProvider).createDocument(
            workspace,
            result.$3.trim(),
            OkfTemplateService.create(
              result.$1,
              title: result.$2.trim(),
              stableId: result.$4.trim(),
            ),
          );
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'The concept could not be created. No existing file was replaced.';
      });
    }
  }

  Future<bool?> _previewPlan(String title, OkfGenerationPlan plan) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Only the files listed below will change. Custom index prose outside DevDesk markers is preserved.',
              ),
              const SizedBox(height: AppSpacing.md),
              for (final write in plan.writes)
                ListTile(
                  leading:
                      Icon(write.create ? Icons.note_add : Icons.edit_note),
                  title: Text(write.relativePath),
                  subtitle: Text(write.reason),
                ),
              for (final skipped in plan.skipped)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(skipped),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply plan'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport() async {
    final report = _report;
    if (report == null) return;
    await ExternalFileService.saveTextAs(
      suggestedName: 'devdesk-okf-health-report.json',
      content: const JsonEncoder.withIndent('  ').convert(report.toMap()),
      allowedExtensions: const ['json'],
      dialogTitle: 'Export OKF health report',
    );
  }
}

class _ReportBody extends StatelessWidget {
  final OkfHealthReport report;
  final VoidCallback onGenerateIndexes;
  final VoidCallback onCreateTemplate;
  final VoidCallback onAddLog;

  const _ReportBody({
    required this.report,
    required this.onGenerateIndexes,
    required this.onCreateTemplate,
    required this.onAddLog,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.page(context),
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _Metric(label: 'Concepts', value: report.totalConcepts),
            _Metric(label: 'Valid', value: report.validConcepts),
            _Metric(label: 'Errors', value: report.count(OkfSeverity.error)),
            _Metric(
                label: 'Warnings', value: report.count(OkfSeverity.warning)),
            _Metric(label: 'Unverified', value: report.unverifiedConcepts),
            _Metric(label: 'Review due', value: report.reviewDueConcepts),
            _Metric(label: 'Deprecated', value: report.deprecatedConcepts),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: onCreateTemplate,
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Create concept'),
            ),
            OutlinedButton.icon(
              onPressed: onGenerateIndexes,
              icon: const Icon(Icons.format_list_bulleted),
              label: const Text('Preview indexes'),
            ),
            OutlinedButton.icon(
              onPressed: onAddLog,
              icon: const Icon(Icons.history_edu),
              label: const Text('Add log entry'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'OKF ${report.specificationVersion} draft findings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (report.issues.isEmpty)
          const AppEmptyState(
            icon: Icons.verified_outlined,
            title: 'No findings',
            message: 'All indexed concept documents meet the validated rules.',
          )
        else
          for (final issue in report.issues)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ListTile(
                leading: Icon(_severityIcon(issue.severity)),
                title: Text('${issue.code} · ${issue.severity.name}'),
                subtitle: Text(
                  '${issue.relativePath == null ? '' : '${issue.relativePath}\n'}${issue.message}${issue.remediation == null ? '' : '\n${issue.remediation}'}',
                ),
              ),
            ),
      ],
    );
  }

  static IconData _severityIcon(OkfSeverity severity) {
    return switch (severity) {
      OkfSeverity.error => Icons.error_outline,
      OkfSeverity.warning => Icons.warning_amber,
      OkfSeverity.recommendation => Icons.tips_and_updates_outlined,
      OkfSeverity.information => Icons.info_outline,
    };
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    );
  }
}
