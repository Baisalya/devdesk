import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/diff_utils.dart';
import '../models/diff_models.dart';

final diffLeftProvider = StateProvider<String>((ref) => '');
final diffRightProvider = StateProvider<String>((ref) => '');
final diffOptionsProvider =
    StateProvider<DiffOptions>((ref) => const DiffOptions());
final diffResultProvider = StateProvider<List<dmp.Diff>>((ref) => []);
final diffSummaryProvider = StateProvider<DiffSummary?>((ref) => null);

final diffSourceLeftProvider =
    StateProvider<DiffSource>((ref) => DiffSource.text);
final diffSourceRightProvider =
    StateProvider<DiffSource>((ref) => DiffSource.text);

void computeDiff(WidgetRef ref) {
  final left = ref.read(diffLeftProvider);
  final right = ref.read(diffRightProvider);
  final options = ref.read(diffOptionsProvider);

  final formattedLeft = DiffUtils.formatIfJson(left, options);
  final formattedRight = DiffUtils.formatIfJson(right, options);

  final diffs =
      DiffUtils.computeDiff(formattedLeft, formattedRight, options: options);
  ref.read(diffResultProvider.notifier).state = diffs;
  ref.read(diffSummaryProvider.notifier).state =
      DiffUtils.calculateSummary(diffs);
}

Future<List<dmp.Diff>> computeDiffInWorker({
  required String left,
  required String right,
  required DiffOptions options,
}) async {
  final serialized =
      await compute<Map<String, dynamic>, List<Map<String, dynamic>>>(
    _computeDiffWorker,
    <String, dynamic>{
      'left': left,
      'right': right,
      'options': options.toMap(),
    },
  );
  return serialized
      .map(
        (item) => dmp.Diff(
          item['operation'] as int,
          item['text'] as String,
        ),
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> _computeDiffWorker(Map<String, dynamic> payload) {
  final left = payload['left'] as String? ?? '';
  final right = payload['right'] as String? ?? '';
  final options = DiffOptions.fromMap(
    Map<String, dynamic>.from(payload['options'] as Map? ?? const {}),
  );
  final formattedLeft = DiffUtils.formatIfJson(left, options);
  final formattedRight = DiffUtils.formatIfJson(right, options);
  final diffs = DiffUtils.computeDiff(
    formattedLeft,
    formattedRight,
    options: options,
  );
  return diffs
      .map(
        (diff) => <String, dynamic>{
          'operation': diff.operation,
          'text': diff.text,
        },
      )
      .toList(growable: false);
}
