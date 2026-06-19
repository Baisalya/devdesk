import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/snippets/models/snippet.dart';

void main() {
  group('Snippet model', () {
    test('serialization round trip', () {
      final snippet = Snippet(
        id: 1,
        title: 'Test',
        content: 'Content',
        tags: ['tag1', 'tag2'],
        createdAt: DateTime.now(),
      );
      final map = snippet.toMap();
      final restored = Snippet.fromMap(map);
      expect(restored.id, snippet.id);
      expect(restored.title, snippet.title);
      expect(restored.content, snippet.content);
      expect(restored.tags, snippet.tags);
    });
  });
}
