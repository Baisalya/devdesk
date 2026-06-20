import 'package:flutter_test/flutter_test.dart';
import 'package:devdesk/features/diff_checker/provider/github_service.dart';

void main() {
  group('GitHubService URL Parsing Tests', () {
    test('Parses basic repo URL', () {
      final ref = GitHubService.parseUrl('https://github.com/flutter/flutter');
      expect(ref?.owner, 'flutter');
      expect(ref?.repo, 'flutter');
      expect(ref?.branch, isNull);
    });

    test('Parses branch tree URL', () {
      final ref = GitHubService.parseUrl('https://github.com/flutter/flutter/tree/master');
      expect(ref?.owner, 'flutter');
      expect(ref?.repo, 'flutter');
      expect(ref?.branch, 'master');
    });

    test('Parses blob file URL', () {
      final ref = GitHubService.parseUrl('https://github.com/flutter/flutter/blob/master/README.md');
      expect(ref?.owner, 'flutter');
      expect(ref?.repo, 'flutter');
      expect(ref?.branch, 'master');
      expect(ref?.path, 'README.md');
    });

    test('Returns null for invalid URLs', () {
      expect(GitHubService.parseUrl('https://google.com'), isNull);
      expect(GitHubService.parseUrl('not a url'), isNull);
    });
  });
}
