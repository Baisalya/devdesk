import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/uuid_utils.dart';

/// Number of UUIDs to generate.
final uuidCountProvider = StateProvider<int>((ref) => 1);

/// Generated UUIDs (list of strings).
final uuidListProvider = StateProvider<List<String>>((ref) => []);

void generateUuids(WidgetRef ref) {
  final count = ref.read(uuidCountProvider);
  if (count < 1 || count > 1000) {
    ref.read(uuidListProvider.notifier).state = [];
    return;
  }
  final uuids = UuidUtils.generateMany(count);
  ref.read(uuidListProvider.notifier).state = uuids;
}
