import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/diff_utils.dart';

final diffLeftProvider = StateProvider<String>((ref) => '');
final diffRightProvider = StateProvider<String>((ref) => '');
final diffResultProvider = StateProvider<List<dmp.Diff>>((ref) => []);

void computeDiff(WidgetRef ref) {
  final left = ref.read(diffLeftProvider);
  final right = ref.read(diffRightProvider);
  final diffs = DiffUtils.computeDiff(left, right);
  ref.read(diffResultProvider.notifier).state = diffs;
}
