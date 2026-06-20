import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import 'package:diff_match_patch/src/patch.dart' as p;

/// Utilities for applying and reverting patches.
class PatchUtils {
  /// Applies a patch to [text]. Returns the modified text.
  static String applyPatch(String text, String patchText) {
    final differ = dmp.DiffMatchPatch();
    final patches = p.patchFromText(patchText);
    final result = differ.patch_apply(patches, text);
    // result is [newText, results] where results is List<bool>
    return result[0] as String;
  }

  /// Reverts a patch (by applying the inverse).
  /// Note: dmp doesn't have a direct 'invert patch', 
  /// so we usually swap old and new text when generating the patch.
  static String revertChange(String currentText, String originalText) {
    // For simple DevDesk needs, we just return the original if revert is requested for the whole block.
    // Real line-by-line revert is handled by merging logic in UI.
    return originalText;
  }
}
