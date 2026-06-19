import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/timestamp_utils.dart';

final timestampInputProvider = StateProvider<String>((ref) => '');
final timestampResultProvider = StateProvider<String?>((ref) => null);
final dateTimeProvider = StateProvider<DateTime?>((ref) => null);

void convertFromTimestamp(WidgetRef ref) {
  final input = ref.read(timestampInputProvider).trim();
  try {
    final date = TimestampUtils.fromUnix(input);
    final local = date.toLocal();
    final utc = date.toUtc();
    final result = 'Local: $local\nUTC: $utc';
    ref.read(timestampResultProvider.notifier).state = result;
  } on TimestampFailure catch (e) {
    ref.read(timestampResultProvider.notifier).state = e.message;
  }
}

void convertToTimestamp(WidgetRef ref) {
  final date = ref.read(dateTimeProvider);
  if (date == null) {
    ref.read(timestampResultProvider.notifier).state =
        'Select a date/time first.';
    return;
  }
  final seconds = TimestampUtils.toUnix(date);
  final millis = TimestampUtils.toUnixMillis(date);
  final result = 'Unix seconds: $seconds\nUnix milliseconds: $millis';
  ref.read(timestampResultProvider.notifier).state = result;
}
