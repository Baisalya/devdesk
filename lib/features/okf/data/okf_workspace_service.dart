import 'package:path/path.dart' as p;

import '../../knowledge/domain/knowledge_models.dart';
import '../../knowledge/domain/knowledge_repository.dart';
import '../../workspaces/domain/workspace_models.dart';
import '../domain/okf_models.dart';

class OkfWorkspaceService {
  static const _startMarker = '<!-- devdesk:okf-index:start -->';
  static const _endMarker = '<!-- devdesk:okf-index:end -->';

  final KnowledgeRepository knowledgeRepository;

  const OkfWorkspaceService(this.knowledgeRepository);

  Future<OkfGenerationPlan> planIndexes(
    DeveloperWorkspace workspace,
    WorkspaceKnowledgeSnapshot snapshot,
  ) async {
    final documents = snapshot.graph.documents;
    final byPath = {
      for (final document in documents)
        document.relativePath.replaceAll('\\', '/'): document,
    };
    final directories = <String>{''};
    for (final document in documents) {
      if (_isReserved(document.relativePath)) continue;
      var directory = p.posix.dirname(document.relativePath);
      if (directory == '.') directory = '';
      directories.add(directory);
    }
    final writes = <OkfPlannedWrite>[];
    final skipped = <String>[];
    for (final directory in directories.toList()..sort()) {
      final indexPath = directory.isEmpty ? 'index.md' : '$directory/index.md';
      final entries = documents.where((document) {
        if (_isReserved(document.relativePath)) return false;
        final parent = p.posix.dirname(document.relativePath);
        return (parent == '.' ? '' : parent) == directory;
      }).toList(growable: false)
        ..sort((left, right) => left.title.compareTo(right.title));
      if (entries.isEmpty) continue;
      final section = _generatedSection(entries);
      final existing = byPath[indexPath];
      if (existing == null) {
        writes.add(
          OkfPlannedWrite(
            relativePath: indexPath,
            content:
                '# ${directory.isEmpty ? 'Knowledge Bundle' : p.posix.basename(directory)}\n\n$section\n',
            create: true,
            reason: 'Create an optional progressive-disclosure index.',
          ),
        );
        continue;
      }
      final current = await knowledgeRepository.readDocument(
        workspace,
        existing.relativePath,
      );
      final updated = _mergeGeneratedSection(current, section);
      if (updated == current) {
        skipped.add('$indexPath is already current.');
      } else {
        writes.add(
          OkfPlannedWrite(
            relativePath: indexPath,
            content: updated,
            create: false,
            expectedFingerprint: existing.fingerprint,
            reason:
                'Update only the DevDesk-managed index section; preserve custom content.',
          ),
        );
      }
    }
    return OkfGenerationPlan(writes: writes, skipped: skipped);
  }

  Future<OkfGenerationPlan> planLogEntry(
    DeveloperWorkspace workspace,
    WorkspaceKnowledgeSnapshot snapshot, {
    required String action,
    required String message,
    DateTime? date,
  }) async {
    final cleanAction = action.trim().isEmpty ? 'Update' : action.trim();
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return const OkfGenerationPlan(writes: []);
    final day =
        (date ?? DateTime.now()).toUtc().toIso8601String().substring(0, 10);
    final entry = '* **$cleanAction**: $cleanMessage';
    KnowledgeDocument? existing;
    for (final document in snapshot.graph.documents) {
      if (document.relativePath.toLowerCase() == 'log.md') existing = document;
    }
    if (existing == null) {
      return OkfGenerationPlan(
        writes: [
          OkfPlannedWrite(
            relativePath: 'log.md',
            content: '# Directory Update Log\n\n## $day\n$entry\n',
            create: true,
            reason: 'Create the optional OKF update log.',
          ),
        ],
      );
    }
    final current = await knowledgeRepository.readDocument(
      workspace,
      existing.relativePath,
    );
    final heading = '## $day';
    final updated = current.contains(heading)
        ? current.replaceFirst(heading, '$heading\n$entry')
        : '${current.trimRight()}\n\n$heading\n$entry\n';
    return OkfGenerationPlan(
      writes: [
        OkfPlannedWrite(
          relativePath: existing.relativePath,
          content: updated,
          create: false,
          expectedFingerprint: existing.fingerprint,
          reason: 'Add a newest-first dated entry to the optional OKF log.',
        ),
      ],
    );
  }

  Future<void> applyPlan(
    DeveloperWorkspace workspace,
    OkfGenerationPlan plan,
  ) async {
    for (final write in plan.writes) {
      if (write.create) {
        await knowledgeRepository.createDocument(
          workspace,
          write.relativePath,
          write.content,
        );
      } else {
        await knowledgeRepository.saveDocument(
          workspace,
          write.relativePath,
          write.content,
          expectedFingerprint: write.expectedFingerprint!,
        );
      }
    }
  }

  static String _generatedSection(List<KnowledgeDocument> documents) {
    final lines = <String>[_startMarker, '## Concepts', ''];
    for (final document in documents) {
      final target = p.posix.basename(document.relativePath);
      final description = document.description.trim().isEmpty
          ? ''
          : ' - ${document.description.trim()}';
      lines.add('* [${document.title}]($target)$description');
    }
    lines.add(_endMarker);
    return lines.join('\n');
  }

  static String _mergeGeneratedSection(String current, String section) {
    final start = current.indexOf(_startMarker);
    final end = current.indexOf(_endMarker);
    if (start >= 0 && end >= start) {
      final after = end + _endMarker.length;
      return current.replaceRange(start, after, section);
    }
    if (current.trim().isEmpty) return '$section\n';
    return '${current.trimRight()}\n\n$section\n';
  }

  static bool _isReserved(String path) {
    final name = p.posix.basename(path).toLowerCase();
    return name == 'index.md' || name == 'log.md';
  }
}
