import 'dart:io';

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/features/diff_checker/provider/git_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  Future<void> git(List<String> arguments) async {
    final result = await Process.run(
      'git',
      arguments,
      workingDirectory: directory.path,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('devdesk-git-test-');
    await git(['init']);
    await git(['config', 'user.email', 'devdesk@example.invalid']);
    await git(['config', 'user.name', 'DevDesk Test']);
    await File('${directory.path}${Platform.pathSeparator}tracked file.txt')
        .writeAsString('one\n');
    await git(['add', '--', 'tracked file.txt']);
    await git(['commit', '-m', 'initial']);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('inspects, stages and unstages paths containing spaces', () async {
    final file = File(
      '${directory.path}${Platform.pathSeparator}tracked file.txt',
    );
    await file.writeAsString('one\ntwo\n');
    final snapshot = await GitService.inspect(directory.path);
    expect(snapshot.branch, isNotEmpty);
    expect(snapshot.recentCommits.single.subject, 'initial');
    expect(snapshot.changes.single.path, 'tracked file.txt');
    expect(snapshot.changes.single.isStaged, isFalse);

    final staged = await GitService.stage(
      directory.path,
      'tracked file.txt',
      expectedFingerprint: snapshot.fingerprint,
    );
    expect(staged.changes.single.isStaged, isTrue);

    final unstaged = await GitService.unstage(
      directory.path,
      'tracked file.txt',
      expectedFingerprint: staged.fingerprint,
    );
    expect(unstaged.changes.single.isStaged, isFalse);
  });

  test('rejects stale mutations and traversal paths', () async {
    await File('${directory.path}${Platform.pathSeparator}tracked file.txt')
        .writeAsString('changed\n');
    final snapshot = await GitService.inspect(directory.path);
    await File('${directory.path}${Platform.pathSeparator}other.txt')
        .writeAsString('other\n');

    await expectLater(
      GitService.stage(
        directory.path,
        'tracked file.txt',
        expectedFingerprint: snapshot.fingerprint,
      ),
      throwsA(isA<GitFailure>()),
    );
    await expectLater(
      GitService.getFileDiff(directory.path, '../outside.txt'),
      throwsA(isA<GitFailure>()),
    );
  });

  test('discard creates recovery patch and never deletes untracked files',
      () async {
    final tracked = File(
      '${directory.path}${Platform.pathSeparator}tracked file.txt',
    );
    await tracked.writeAsString('discard me\n');
    var snapshot = await GitService.inspect(directory.path);
    final result = await GitService.discardTrackedChange(
      directory.path,
      'tracked file.txt',
      expectedFingerprint: snapshot.fingerprint,
    );
    expect((await tracked.readAsString()).replaceAll('\r\n', '\n'), 'one\n');
    expect(File(result.recoveryPatch).existsSync(), isTrue);
    expect(
        File(result.recoveryPatch).readAsStringSync(), contains('discard me'));

    await File('${directory.path}${Platform.pathSeparator}untracked.txt')
        .writeAsString('keep');
    snapshot = await GitService.inspect(directory.path);
    await expectLater(
      GitService.discardTrackedChange(
        directory.path,
        'untracked.txt',
        expectedFingerprint: snapshot.fingerprint,
      ),
      throwsA(isA<GitFailure>()),
    );
    expect(
      File('${directory.path}${Platform.pathSeparator}untracked.txt')
          .existsSync(),
      isTrue,
    );
  });
}
