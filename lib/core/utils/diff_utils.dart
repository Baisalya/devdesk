import 'dart:convert';
import 'package:diff_match_patch/diff_match_patch.dart' as dmp;
import '../../features/diff_checker/models/diff_models.dart';
import 'json_utils.dart';

/// Utilities for comparing two pieces of text and producing a diff.
class DiffUtils {
  static const int maxTextBytes = 2 * 1024 * 1024;

  /// Computes a diff between [oldText] and [newText]. Returns a list of
  /// [dmp.Diff] objects indicating additions, deletions and equalities.
  static List<dmp.Diff> computeDiff(
    String oldText,
    String newText, {
    DiffOptions options = const DiffOptions(),
  }) {
    _guardInputs(oldText, newText);
    String left = _prepareText(oldText, options);
    String right = _prepareText(newText, options);

    final differ = dmp.DiffMatchPatch();
    final diffs = differ.diff(left, right);
    differ.diffCleanupSemantic(diffs);
    return diffs;
  }

  /// Normalizes and prepares text based on [DiffOptions].
  static String _prepareText(String text, DiffOptions options) {
    String result = text;

    if (options.normalizeLineEndings) {
      result = result.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    }

    if (options.trimLineEndings) {
      result = result.split('\n').map((line) => line.trimRight()).join('\n');
    }

    if (options.ignoreWhitespace) {
      result = result.replaceAll(RegExp(r'\s+'), '');
    }

    if (options.ignoreCase) {
      result = result.toLowerCase();
    }

    if (options.ignoreEmptyLines) {
      result =
          result.split('\n').where((line) => line.trim().isNotEmpty).join('\n');
    }

    return result;
  }

  /// Attempts to format JSON text before diffing if [options.jsonKeyOrderIgnore] is true.
  static String formatIfJson(String text, DiffOptions options) {
    if (!options.jsonKeyOrderIgnore) return text;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map || decoded is List) {
        // Normalizing key order by re-encoding with sorted keys if it was a Map
        // Note: standard jsonEncode doesn't sort keys, but we can do it manually for Maps.
        final sortedData = _sortJsonMap(decoded);
        return JsonUtils.prettyPrint(sortedData);
      }
    } catch (_) {}
    return text;
  }

  static dynamic _sortJsonMap(dynamic data) {
    if (data is Map) {
      final sortedMap = <String, dynamic>{};
      final keys = data.keys.map((e) => e.toString()).toList()..sort();
      for (final key in keys) {
        sortedMap[key] = _sortJsonMap(data[key]);
      }
      return sortedMap;
    } else if (data is List) {
      return data.map((e) => _sortJsonMap(e)).toList();
    }
    return data;
  }

  /// Generates a Unified Diff format patch string.
  static String generatePatch(String oldText, String newText) {
    _guardInputs(oldText, newText);
    final differ = dmp.DiffMatchPatch();
    final patches = differ.patch(oldText, newText);
    return dmp.patchToText(patches);
  }

  static void _guardInputs(String oldText, String newText) {
    if (utf8.encode(oldText).length > maxTextBytes ||
        utf8.encode(newText).length > maxTextBytes) {
      throw ArgumentError(
        'Each diff input must be 2 MB or smaller for reliable interactive use.',
      );
    }
  }

  /// Calculates a summary from a list of diffs.
  static DiffSummary calculateSummary(List<dmp.Diff> diffs) {
    int added = 0;
    int removed = 0;
    int unchanged = 0;
    int changedBlocks = 0;

    bool inChange = false;

    for (final diff in diffs) {
      if (diff.operation == dmp.DIFF_INSERT) {
        added += diff.text.length;
        if (!inChange) {
          changedBlocks++;
          inChange = true;
        }
      } else if (diff.operation == dmp.DIFF_DELETE) {
        removed += diff.text.length;
        if (!inChange) {
          changedBlocks++;
          inChange = true;
        }
      } else {
        unchanged += diff.text.length;
        inChange = false;
      }
    }

    return DiffSummary(
      added: added,
      removed: removed,
      unchanged: unchanged,
      changedBlocks: changedBlocks,
    );
  }
}
