import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/utils/diff_utils.dart';

void main() {
  test('diff detects added text', () {
    final diffs = DiffUtils.computeDiff('hello', 'hello world');
    expect(diffs.any((diff) => diff.operation == dmp.DIFF_INSERT), isTrue);
  });

  test('diff detects removed text', () {
    final diffs = DiffUtils.computeDiff('hello world', 'hello');
    expect(diffs.any((diff) => diff.operation == dmp.DIFF_DELETE), isTrue);
  });

  test('diff detects same text', () {
    final diffs = DiffUtils.computeDiff('same', 'same');
    expect(diffs.single.operation, dmp.DIFF_EQUAL);
  });

  test('diff handles empty input', () {
    expect(DiffUtils.computeDiff('', ''), isEmpty);
  });
}
