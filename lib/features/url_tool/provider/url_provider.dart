import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/url_utils.dart';

final urlInputProvider = StateProvider<String>((ref) => '');
final urlOutputProvider = StateProvider<String?>((ref) => null);

void encodeUrl(WidgetRef ref) {
  final input = ref.read(urlInputProvider);
  try {
    final encoded = UrlUtils.encode(input);
    ref.read(urlOutputProvider.notifier).state = encoded;
  } on UrlFailure catch (e) {
    ref.read(urlOutputProvider.notifier).state = e.message;
  }
}

void decodeUrl(WidgetRef ref) {
  final input = ref.read(urlInputProvider);
  try {
    final decoded = UrlUtils.decode(input);
    ref.read(urlOutputProvider.notifier).state = decoded;
  } on UrlFailure catch (e) {
    ref.read(urlOutputProvider.notifier).state = e.message;
  }
}
