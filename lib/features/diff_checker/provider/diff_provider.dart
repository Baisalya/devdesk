import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
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
