import 'package:flutter_test/flutter_test.dart';
import 'package:devdesk/core/utils/diff_utils.dart';
import 'package:devdesk/features/diff_checker/models/diff_models.dart';

void main() {
  group('DiffUtils Engine Tests', () {
    test('Basic text diff works', () {
      final oldText = 'Hello World';
      final newText = 'Hello Flutter';
      final diffs = DiffUtils.computeDiff(oldText, newText);

      expect(diffs.any((d) => d.text == 'World' && d.operation == -1),
          isTrue); // Delete
      expect(diffs.any((d) => d.text == 'Flutter' && d.operation == 1),
          isTrue); // Insert
    });

    test('Ignore whitespace works', () {
      final oldText = 'A B C';
      final newText = 'ABC';
      final options = DiffOptions(ignoreWhitespace: true);
      final diffs = DiffUtils.computeDiff(oldText, newText, options: options);

      expect(diffs.length, 1);
      expect(diffs.first.text, 'ABC');
      expect(diffs.first.operation, 0); // Equal
    });

    test('JSON key order ignore works', () {
      final oldText = '{"a": 1, "b": 2}';
      final newText = '{"b": 2, "a": 1}';
      final options = DiffOptions(jsonKeyOrderIgnore: true);

      final formattedOld = DiffUtils.formatIfJson(oldText, options);
      final formattedNew = DiffUtils.formatIfJson(newText, options);

      final diffs =
          DiffUtils.computeDiff(formattedOld, formattedNew, options: options);

      expect(diffs.every((d) => d.operation == 0), isTrue);
    });

    test('DiffSummary calculation is correct', () {
      final oldText = 'Apple';
      final newText = 'Banana';
      final diffs = DiffUtils.computeDiff(oldText, newText);
      final summary = DiffUtils.calculateSummary(diffs);

      expect(summary.added, greaterThan(0));
      expect(summary.removed, greaterThan(0));
      expect(summary.changedBlocks, greaterThan(0));
    });
  });
}
