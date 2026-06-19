import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/regex_utils.dart';
import '../../../core/errors/failure.dart';

/// Holds the current regex pattern.
final regexPatternProvider = StateProvider<String>((ref) => '');

/// Holds the current sample text.
final regexSampleProvider = StateProvider<String>((ref) => '');

/// Holds the list of matches or an error message. An [AsyncValue] is
/// convenient for representing success/failure states.
final regexResultProvider = StateProvider<AsyncValue<List<Match>>>((ref) {
  return const AsyncValue.data([]);
});

/// Tests the current pattern against the sample text and updates
/// [regexResultProvider]. Supports multi‑line and case sensitive toggles.
void testRegex(WidgetRef ref,
    {bool multiLine = false, bool caseSensitive = true}) {
  final pattern = ref.read(regexPatternProvider);
  final sample = ref.read(regexSampleProvider);
  if (pattern.isEmpty) {
    ref.read(regexResultProvider.notifier).state = const AsyncValue.data([]);
    return;
  }
  try {
    final matches = RegexUtils.testRegex(
      pattern,
      sample,
      multiLine: multiLine,
      caseSensitive: caseSensitive,
    );
    ref.read(regexResultProvider.notifier).state = AsyncValue.data(matches);
  } on RegexFailure catch (e) {
    ref.read(regexResultProvider.notifier).state =
        AsyncValue.error(e.message, StackTrace.current);
  }
}
