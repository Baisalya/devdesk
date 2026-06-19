import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/base64_utils.dart';

/// Holds the input for the Base64 tool.
final base64InputProvider = StateProvider<String>((ref) => '');

/// Holds the output of the Base64 tool or an error message. Null means no
/// output yet.
final base64OutputProvider = StateProvider<String?>((ref) => null);

/// Encodes the current input to Base64.
void encodeBase64(WidgetRef ref) {
  final input = ref.read(base64InputProvider);
  final encoded = Base64Utils.encode(input);
  ref.read(base64OutputProvider.notifier).state = encoded;
}

/// Decodes the current input from Base64 to a string. Updates the output with
/// the decoded text or an error message.
void decodeBase64(WidgetRef ref) {
  final input = ref.read(base64InputProvider);
  try {
    final decoded = Base64Utils.decode(input);
    ref.read(base64OutputProvider.notifier).state = decoded;
  } on Base64Failure catch (e) {
    ref.read(base64OutputProvider.notifier).state = e.message;
  }
}
