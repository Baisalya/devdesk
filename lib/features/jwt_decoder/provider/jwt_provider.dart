import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/jwt_utils.dart';
import '../../../core/errors/failure.dart';

/// Holds the current JWT input from the user.
final jwtInputProvider = StateProvider<String>((ref) => '');

/// Holds the decoded JWT result as a map with 'header', 'payload' and
/// 'expiry' keys, or an error message. Uses `AsyncValue` to indicate
/// loading/error states.
final jwtDecodedProvider =
    StateProvider<AsyncValue<Map<String, dynamic>>>((ref) {
  return const AsyncValue.data(<String, dynamic>{});
});

/// Decodes the JWT in [jwtInputProvider] and updates [jwtDecodedProvider].
void decodeJwt(WidgetRef ref) {
  final token = ref.read(jwtInputProvider).trim();
  if (token.isEmpty) {
    ref.read(jwtDecodedProvider.notifier).state =
        const AsyncValue.data(<String, dynamic>{});
    return;
  }
  try {
    final result = JwtUtils.decode(token);
    ref.read(jwtDecodedProvider.notifier).state = AsyncValue.data(result);
  } on JwtFailure catch (e) {
    ref.read(jwtDecodedProvider.notifier).state =
        AsyncValue.error(e.message, StackTrace.current);
  }
}
