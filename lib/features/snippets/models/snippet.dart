/// Model representing a developer note or code snippet.
class Snippet {
  final int id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;

  Snippet({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Snippet copyWith({
    int? id,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return Snippet(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Snippet.fromMap(Map<String, dynamic> map) {
    return Snippet(
      id: map['id'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      tags: List<String>.from(map['tags'] as List),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
