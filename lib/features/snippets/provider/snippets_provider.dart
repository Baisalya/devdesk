import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../models/snippet.dart';

class SnippetsNotifier extends StateNotifier<AsyncValue<List<Snippet>>> {
  SnippetsNotifier() : super(const AsyncValue.loading()) {
    _loadSnippets();
  }

  Future<void> _loadSnippets() async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.snippetsBox);
    final list = box.values
        .map((e) => Snippet.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    state = AsyncValue.data(list);
  }

  Future<void> addSnippet(Snippet snippet) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.snippetsBox);
    await box.put(snippet.id, snippet.toMap());
    await _loadSnippets();
  }

  Future<void> updateSnippet(Snippet snippet) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.snippetsBox);
    await box.put(snippet.id, snippet.toMap());
    await _loadSnippets();
  }

  Future<void> deleteSnippet(int id) async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.snippetsBox);
    await box.delete(id);
    await _loadSnippets();
  }

  /// Generates a unique incremental ID based on the highest existing ID in the box.
  Future<int> nextId() async {
    final box = await LocalStorage.openBox<Map>(LocalStorage.snippetsBox);
    if (box.isEmpty) return 1;
    final ids = box.keys.cast<int>().toList();
    return (ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b)) + 1;
  }
}

final snippetsProvider =
    StateNotifierProvider<SnippetsNotifier, AsyncValue<List<Snippet>>>(
  (ref) => SnippetsNotifier(),
);

/// Provider to hold the current search term for filtering snippets.
final snippetsSearchProvider = StateProvider<String>((ref) => '');
