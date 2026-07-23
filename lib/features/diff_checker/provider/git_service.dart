import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/errors/failure.dart';

class GitChangedFile {
  final String path;
  final String? originalPath;
  final String status;
  final bool isStaged;

  const GitChangedFile({
    required this.path,
    required this.status,
    required this.isStaged,
    this.originalPath,
  });
}

class GitCommitSummary {
  final String hash;
  final String subject;
  final String author;
  final DateTime? authoredAt;

  const GitCommitSummary({
    required this.hash,
    required this.subject,
    required this.author,
    required this.authoredAt,
  });
}

class GitRepositorySnapshot {
  final String root;
  final String branch;
  final String? upstream;
  final int ahead;
  final int behind;
  final List<GitChangedFile> changes;
  final List<String> conflicts;
  final List<GitCommitSummary> recentCommits;
  final List<String> remotes;
  final String fingerprint;

  const GitRepositorySnapshot({
    required this.root,
    required this.branch,
    required this.upstream,
    required this.ahead,
    required this.behind,
    required this.changes,
    required this.conflicts,
    required this.recentCommits,
    required this.remotes,
    required this.fingerprint,
  });

  bool get isClean => changes.isEmpty;
}

class GitService {
  static const _timeout = Duration(seconds: 15);
  static const _maxOutputBytes = 4 * 1024 * 1024;

  static Future<bool> isGitInstalled() async {
    try {
      return (await _run(null, const ['--version'])).exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getRepoRoot(String dir) async {
    try {
      final result = await _run(
        dir,
        const ['rev-parse', '--show-toplevel'],
      );
      if (result.exitCode != 0) return null;
      final candidate = result.stdout.trim();
      if (candidate.isEmpty) return null;
      return Directory(candidate).resolveSymbolicLinks();
    } catch (_) {
      return null;
    }
  }

  static Future<GitRepositorySnapshot> inspect(String workingDir) async {
    final root = await getRepoRoot(workingDir);
    if (root == null) {
      throw GitFailure(
        'The selected folder is not inside a Git repository.',
        code: 'DD-GIT-NOT-REPOSITORY',
      );
    }
    final status = await _run(
      root,
      const [
        'status',
        '--porcelain=v1',
        '-z',
        '--branch',
        '--untracked-files=all'
      ],
    );
    _requireSuccess(status, 'Unable to inspect the repository.');
    final parsed = _parseStatus(status.stdout);
    final log = await _run(
      root,
      const [
        'log',
        '-n',
        '20',
        '--date=iso-strict',
        '--pretty=format:%H%x1f%an%x1f%aI%x1f%s%x00',
      ],
    );
    final remote = await _run(root, const ['remote', '-v']);
    return GitRepositorySnapshot(
      root: root,
      branch: parsed.branch,
      upstream: parsed.upstream,
      ahead: parsed.ahead,
      behind: parsed.behind,
      changes: parsed.changes,
      conflicts: parsed.changes
          .where((change) => _conflictStatuses.contains(change.status))
          .map((change) => change.path)
          .toSet()
          .toList(),
      recentCommits: log.exitCode == 0 ? _parseLog(log.stdout) : const [],
      remotes: remote.exitCode == 0
          ? remote.stdout
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
          : const [],
      fingerprint: base64Url.encode(utf8.encode(status.stdout)),
    );
  }

  static Future<List<GitChangedFile>> getStatus(String workingDir) async {
    return (await inspect(workingDir)).changes;
  }

  static Future<String> getFileDiff(
    String workingDir,
    String path, {
    bool staged = false,
  }) async {
    final root = await _rootAndValidatePath(workingDir, path);
    final result = await _run(root, [
      'diff',
      if (staged) '--cached',
      '--',
      _normalizeRelative(path),
    ]);
    _requireSuccess(result, 'Unable to load the selected diff.');
    return result.stdout;
  }

  static Future<String> getFileAtHead(String workingDir, String path) async {
    final root = await _rootAndValidatePath(workingDir, path);
    final result = await _run(
      root,
      ['show', 'HEAD:${_normalizeRelative(path)}'],
    );
    return result.exitCode == 0 ? result.stdout : '';
  }

  static Future<GitRepositorySnapshot> stage(
    String workingDir,
    String path, {
    required String expectedFingerprint,
  }) async {
    final root = await _rootAndValidatePath(workingDir, path);
    await _assertFresh(root, expectedFingerprint);
    final result = await _run(root, ['add', '--', _normalizeRelative(path)]);
    _requireSuccess(result, 'Unable to stage the selected file.');
    return inspect(root);
  }

  static Future<GitRepositorySnapshot> unstage(
    String workingDir,
    String path, {
    required String expectedFingerprint,
  }) async {
    final root = await _rootAndValidatePath(workingDir, path);
    await _assertFresh(root, expectedFingerprint);
    final result = await _run(
      root,
      ['restore', '--staged', '--', _normalizeRelative(path)],
    );
    _requireSuccess(result, 'Unable to unstage the selected file.');
    return inspect(root);
  }

  /// Discards a tracked working-tree change after writing a recovery patch.
  /// Untracked files are deliberately never deleted by this operation.
  static Future<({GitRepositorySnapshot snapshot, String recoveryPatch})>
      discardTrackedChange(
    String workingDir,
    String path, {
    required String expectedFingerprint,
  }) async {
    final root = await _rootAndValidatePath(workingDir, path);
    await _assertFresh(root, expectedFingerprint);
    final relative = _normalizeRelative(path);
    final before = await inspect(root);
    final matches = before.changes.where((change) => change.path == relative);
    if (matches.isEmpty || matches.every((change) => change.status == '??')) {
      throw GitFailure(
        'Untracked files are not deleted by DevDesk.',
        code: 'DD-GIT-UNTRACKED-DISCARD',
      );
    }
    final diff = await _run(root, ['diff', '--binary', '--', relative]);
    _requireSuccess(diff, 'Unable to prepare a recovery patch.');
    if (diff.stdout.isEmpty) {
      throw GitFailure(
        'No recoverable working-tree diff was found.',
        code: 'DD-GIT-NO-RECOVERY',
      );
    }
    final recoveryDirectory = await Directory.systemTemp.createTemp(
      'devdesk-git-recovery-',
    );
    final patchFile = File(p.join(recoveryDirectory.path, 'change.patch'));
    await patchFile.writeAsString(diff.stdout, flush: true);
    final restore = await _run(root, ['restore', '--worktree', '--', relative]);
    _requireSuccess(restore, 'Unable to discard the selected change.');
    return (snapshot: await inspect(root), recoveryPatch: patchFile.path);
  }

  static Future<void> _assertFresh(String root, String fingerprint) async {
    if ((await inspect(root)).fingerprint != fingerprint) {
      throw GitFailure(
        'Repository state changed. Refresh before applying this action.',
        code: 'DD-GIT-STALE-SNAPSHOT',
      );
    }
  }

  static Future<String> _rootAndValidatePath(
    String workingDir,
    String path,
  ) async {
    final root = await getRepoRoot(workingDir);
    if (root == null) {
      throw GitFailure(
        'The selected folder is not inside a Git repository.',
        code: 'DD-GIT-NOT-REPOSITORY',
      );
    }
    final relative = _normalizeRelative(path);
    final resolved = p.normalize(p.join(root, relative));
    if (!p.isWithin(root, resolved) && !p.equals(root, resolved)) {
      throw GitFailure(
        'The selected path is outside the repository.',
        code: 'DD-GIT-PATH',
      );
    }
    return root;
  }

  static String _normalizeRelative(String path) {
    final normalized = p.normalize(path);
    if (path.trim().isEmpty || p.isAbsolute(normalized)) {
      throw GitFailure('Select a repository file.', code: 'DD-GIT-PATH');
    }
    final pieces = p.split(normalized);
    if (pieces.contains('..')) {
      throw GitFailure(
        'The selected path is outside the repository.',
        code: 'DD-GIT-PATH',
      );
    }
    return p.posix.joinAll(pieces);
  }

  static Future<_GitResult> _run(
    String? workingDirectory,
    List<String> arguments,
  ) async {
    final process = await Process.start(
      'git',
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );
    final stdoutFuture = _readBounded(process.stdout);
    final stderrFuture = _readBounded(process.stderr);
    try {
      final exitCode = await process.exitCode.timeout(_timeout);
      return _GitResult(
        exitCode,
        await stdoutFuture,
        await stderrFuture,
      );
    } on TimeoutException {
      process.kill();
      throw GitFailure(
        'Git did not finish within ${_timeout.inSeconds} seconds.',
        code: 'DD-GIT-TIMEOUT',
      );
    }
  }

  static Future<String> _readBounded(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > _maxOutputBytes) {
        throw GitFailure(
          'Git output exceeded the safe 4 MB limit.',
          code: 'DD-GIT-OUTPUT-LIMIT',
        );
      }
      builder.add(chunk);
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  static void _requireSuccess(_GitResult result, String message) {
    if (result.exitCode != 0) {
      throw GitFailure(message, code: 'DD-GIT-COMMAND');
    }
  }

  static _ParsedStatus _parseStatus(String output) {
    final records = output.split('\u0000');
    var branch = 'HEAD';
    String? upstream;
    var ahead = 0;
    var behind = 0;
    final changes = <GitChangedFile>[];
    var index = 0;
    if (records.isNotEmpty && records.first.startsWith('## ')) {
      final header = records.first.substring(3);
      final match = RegExp(
        r'^(.*?)(?:\.\.\.([^ \[]+))?(?: \[(.*?)\])?$',
      ).firstMatch(header);
      branch = match?.group(1)?.trim() ?? header;
      upstream = match?.group(2)?.trim();
      final tracking = match?.group(3) ?? '';
      ahead = int.tryParse(
            RegExp(r'ahead (\d+)').firstMatch(tracking)?.group(1) ?? '',
          ) ??
          0;
      behind = int.tryParse(
            RegExp(r'behind (\d+)').firstMatch(tracking)?.group(1) ?? '',
          ) ??
          0;
      index = 1;
    }
    while (index < records.length) {
      final record = records[index];
      if (record.length < 4) {
        index++;
        continue;
      }
      final x = record[0];
      final y = record[1];
      final path = record.substring(3);
      String? originalPath;
      if ((x == 'R' || x == 'C') && index + 1 < records.length) {
        originalPath = records[++index];
      }
      if (x != ' ' && x != '?') {
        changes.add(
          GitChangedFile(
            path: path,
            originalPath: originalPath,
            status: x,
            isStaged: true,
          ),
        );
      }
      if (y != ' ' && y != '?') {
        changes.add(
          GitChangedFile(
            path: path,
            originalPath: originalPath,
            status: y,
            isStaged: false,
          ),
        );
      }
      if (x == '?' && y == '?') {
        changes.add(
          GitChangedFile(path: path, status: '??', isStaged: false),
        );
      }
      index++;
    }
    return _ParsedStatus(branch, upstream, ahead, behind, changes);
  }

  static List<GitCommitSummary> _parseLog(String output) {
    return output
        .split('\u0000')
        .where((record) => record.trim().isNotEmpty)
        .map((record) {
      final fields = record.split('\u001f');
      return GitCommitSummary(
        hash: fields.isNotEmpty ? fields[0] : '',
        author: fields.length > 1 ? fields[1] : '',
        authoredAt: fields.length > 2 ? DateTime.tryParse(fields[2]) : null,
        subject: fields.length > 3 ? fields.sublist(3).join(' ') : '',
      );
    }).toList();
  }

  static const _conflictStatuses = {'U', 'AA', 'DD', 'AU', 'UA', 'DU', 'UD'};
}

class _GitResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _GitResult(this.exitCode, this.stdout, this.stderr);
}

class _ParsedStatus {
  final String branch;
  final String? upstream;
  final int ahead;
  final int behind;
  final List<GitChangedFile> changes;

  const _ParsedStatus(
    this.branch,
    this.upstream,
    this.ahead,
    this.behind,
    this.changes,
  );
}
