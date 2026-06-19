import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/json_utils.dart';

/// Holds the current JSON input entered by the user.
final jsonInputProvider = StateProvider<String>((ref) => '');

/// Holds the result of formatting/minifying or validating JSON. When null,
/// nothing has been computed yet. Contains either a formatted/minified
/// string or an error message.
final jsonOutputProvider = StateProvider<String?>((ref) => null);

/// Parses and pretty‑prints the current JSON input. Updates
/// [jsonOutputProvider] with the result or error.
void formatJson(WidgetRef ref) {
  final input = ref.read(jsonInputProvider).trim();
  try {
    final pretty = JsonUtils.prettyPrint(input);
    ref.read(jsonOutputProvider.notifier).state = pretty;
  } on JsonFailure catch (e) {
    ref.read(jsonOutputProvider.notifier).state = e.message;
  }
}

/// Minifies the current JSON input. Updates [jsonOutputProvider] with the
/// result or error.
void minifyJson(WidgetRef ref) {
  final input = ref.read(jsonInputProvider).trim();
  try {
    final minified = JsonUtils.minify(input);
    ref.read(jsonOutputProvider.notifier).state = minified;
  } on JsonFailure catch (e) {
    ref.read(jsonOutputProvider.notifier).state = e.message;
  }
}
