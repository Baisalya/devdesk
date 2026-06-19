import 'package:diff_match_patch/diff_match_patch.dart' as dmp;

/// Utilities for comparing two pieces of text and producing a diff.
class DiffUtils {
  /// Computes a diff between [oldText] and [newText]. Returns a list of
  /// [dmp.Diff] objects indicating additions, deletions and equalities.
  static List<dmp.Diff> computeDiff(String oldText, String newText) {
    final differ = dmp.DiffMatchPatch();
    final diffs = differ.diff(oldText, newText);
    differ.diffCleanupSemantic(diffs);
    return diffs;
  }
}
