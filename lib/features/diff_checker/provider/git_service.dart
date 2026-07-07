import 'dart:io';

class GitChangedFile {
  final String path;
  final String status; // 'M', 'A', 'D', '??', etc.
  final bool isStaged;

  const GitChangedFile({
    required this.path,
    required this.status,
    required this.isStaged,
  });
}

class GitService {
  /// Checks if Git is installed and available in PATH.
  static Future<bool> isGitInstalled() async {
    try {
      final result = await Process.run('git', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns the root path of the Git repository if [dir] is inside one.
  static Future<String?> getRepoRoot(String dir) async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--show-toplevel'],
        workingDirectory: dir,
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }

  /// Gets the list of changed files using `git status --short`.
  static Future<List<GitChangedFile>> getStatus(String workingDir) async {
    final result = await Process.run(
      'git',
      ['status', '--short'],
      workingDirectory: workingDir,
    );
    if (result.exitCode != 0) return [];

    final lines = (result.stdout as String).split('\n');
    final changes = <GitChangedFile>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      // Format: XY path
      // X: status in index (staged)
      // Y: status in working tree (unstaged)
      final x = line.substring(0, 1);
      final y = line.substring(1, 2);
      final path = line.substring(3).trim();

      if (x != ' ' && x != '?') {
        changes.add(GitChangedFile(path: path, status: x, isStaged: true));
      }
      if (y != ' ' && y != '?') {
        changes.add(GitChangedFile(path: path, status: y, isStaged: false));
      }
      if (x == '?' && y == '?') {
        changes.add(GitChangedFile(path: path, status: '??', isStaged: false));
      }
    }
    return changes;
  }

  /// Gets the diff for a specific file.
  static Future<String> getFileDiff(String workingDir, String path,
      {bool staged = false}) async {
    final args = ['diff'];
    if (staged) args.add('--cached');
    args.add('--');
    args.add(path);

    final result = await Process.run(
      'git',
      args,
      workingDirectory: workingDir,
    );
    return result.stdout as String;
  }

  /// Gets the content of a file at HEAD.
  static Future<String> getFileAtHead(String workingDir, String path) async {
    final result = await Process.run(
      'git',
      ['show', 'HEAD:$path'],
      workingDirectory: workingDir,
    );
    if (result.exitCode == 0) {
      return result.stdout as String;
    }
    return '';
  }
}
