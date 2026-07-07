import 'package:uuid/uuid.dart';

/// Represents a single markdown note in the vault.
class VaultNote {
  final String id;
  final String title;
  final String content;
  final String folderPath; // e.g., "work/projects" or "" for root
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final List<String> links; // Wiki links [[Note Name]]
  final List<String> backlinks; // IDs of notes linking to this one
  final bool isFavorite;
  final bool isPinned;
  final Map<String, dynamic> metadata; // YAML frontmatter
  final List<NoteVersion> versionHistory;
  final String? externalPath;
  final String? draftContent;
  final DateTime? lastOpenedAt;

  VaultNote({
    String? id,
    required this.title,
    required this.content,
    this.folderPath = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.tags = const [],
    this.links = const [],
    this.backlinks = const [],
    this.isFavorite = false,
    this.isPinned = false,
    this.metadata = const {},
    this.versionHistory = const [],
    this.externalPath,
    this.draftContent,
    this.lastOpenedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  VaultNote copyWith({
    String? title,
    String? content,
    String? folderPath,
    DateTime? updatedAt,
    List<String>? tags,
    List<String>? links,
    List<String>? backlinks,
    bool? isFavorite,
    bool? isPinned,
    Map<String, dynamic>? metadata,
    List<NoteVersion>? versionHistory,
    String? externalPath,
    String? draftContent,
    DateTime? lastOpenedAt,
    bool clearExternalPath = false,
    bool clearDraftContent = false,
  }) {
    return VaultNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderPath: folderPath ?? this.folderPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      links: links ?? this.links,
      backlinks: backlinks ?? this.backlinks,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      metadata: metadata ?? this.metadata,
      versionHistory: versionHistory ?? this.versionHistory,
      externalPath:
          clearExternalPath ? null : externalPath ?? this.externalPath,
      draftContent:
          clearDraftContent ? null : draftContent ?? this.draftContent,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folderPath': folderPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'links': links,
      'backlinks': backlinks,
      'isFavorite': isFavorite,
      'isPinned': isPinned,
      'metadata': metadata,
      'versionHistory': versionHistory.map((v) => v.toMap()).toList(),
      'externalPath': externalPath,
      'draftContent': draftContent,
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    };
  }

  factory VaultNote.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return VaultNote(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? 'Untitled Note',
      content: map['content']?.toString() ?? '',
      folderPath: map['folderPath'] ?? '',
      createdAt: _dateFromMap(map['createdAt']) ?? now,
      updatedAt: _dateFromMap(map['updatedAt']) ?? now,
      tags: List<String>.from(map['tags'] ?? []),
      links: List<String>.from(map['links'] ?? []),
      backlinks: List<String>.from(map['backlinks'] ?? []),
      isFavorite: map['isFavorite'] ?? false,
      isPinned: map['isPinned'] ?? false,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      versionHistory: (map['versionHistory'] as List? ?? [])
          .map((v) => NoteVersion.fromMap(Map<String, dynamic>.from(v)))
          .toList(),
      externalPath: map['externalPath']?.toString(),
      draftContent: map['draftContent']?.toString(),
      lastOpenedAt: _dateFromMap(map['lastOpenedAt']),
    );
  }

  String get fullPath => folderPath.isEmpty ? title : '$folderPath/$title';

  String get fileName {
    final trimmed = title.trim().isEmpty ? 'Untitled Note' : title.trim();
    final lower = trimmed.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.markdown')
        ? trimmed
        : '$trimmed.md';
  }
}

class NoteVersion {
  final DateTime timestamp;
  final String content;

  NoteVersion({
    required this.timestamp,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'content': content,
    };
  }

  factory NoteVersion.fromMap(Map<String, dynamic> map) {
    return NoteVersion(
      timestamp: _dateFromMap(map['timestamp']) ?? DateTime.now(),
      content: map['content']?.toString() ?? '',
    );
  }
}

DateTime? _dateFromMap(dynamic value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}
