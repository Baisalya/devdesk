import 'package:flutter/foundation.dart';

enum WorkspacePlatform { windows, android, unknown }

enum WorkspaceRootKind { localPath, documentTree }

enum WorkspaceKind { git, documentation, okf, api, mixed }

enum WorkspaceCapability {
  read,
  write,
  enumerate,
  atomicWrite,
  watch,
  deleteFiles,
  gitCli,
}

enum WorkspaceHealthStatus { healthy, attention, unavailable }

@immutable
class WorkspaceRootRef {
  final WorkspaceRootKind kind;
  final WorkspacePlatform platform;

  /// Opaque platform value. It is a path only when [kind] is
  /// [WorkspaceRootKind.localPath].
  final String value;
  final String displayPath;
  final Set<WorkspaceCapability> capabilities;

  const WorkspaceRootRef({
    required this.kind,
    required this.platform,
    required this.value,
    required this.displayPath,
    this.capabilities = const {},
  });

  bool supports(WorkspaceCapability capability) {
    return capabilities.contains(capability);
  }

  Map<String, dynamic> toMap() {
    return {
      'kind': kind.name,
      'platform': platform.name,
      'value': value,
      'displayPath': displayPath,
      'capabilities': capabilities.map((item) => item.name).toList(),
    };
  }

  factory WorkspaceRootRef.fromMap(Map<dynamic, dynamic> map) {
    return WorkspaceRootRef(
      kind: _enumByName(
        WorkspaceRootKind.values,
        map['kind'],
        WorkspaceRootKind.localPath,
      ),
      platform: _enumByName(
        WorkspacePlatform.values,
        map['platform'],
        WorkspacePlatform.unknown,
      ),
      value: map['value']?.toString() ?? '',
      displayPath: map['displayPath']?.toString() ?? '',
      capabilities: {
        for (final raw in (map['capabilities'] as Iterable?) ?? const [])
          if (_enumByNameOrNull(WorkspaceCapability.values, raw)
              case final value?)
            value,
      },
    );
  }
}

@immutable
class WorkspaceSettings {
  final bool indexHiddenFiles;
  final bool followSymbolicLinks;
  final bool enableFileWatching;
  final List<String> excludedNames;

  const WorkspaceSettings({
    this.indexHiddenFiles = false,
    this.followSymbolicLinks = false,
    this.enableFileWatching = true,
    this.excludedNames = const [
      '.git',
      '.dart_tool',
      'build',
      'node_modules',
    ],
  });

  Map<String, dynamic> toMap() {
    return {
      'indexHiddenFiles': indexHiddenFiles,
      'followSymbolicLinks': followSymbolicLinks,
      'enableFileWatching': enableFileWatching,
      'excludedNames': excludedNames,
    };
  }

  factory WorkspaceSettings.fromMap(Map<dynamic, dynamic> map) {
    return WorkspaceSettings(
      indexHiddenFiles: map['indexHiddenFiles'] == true,
      followSymbolicLinks: map['followSymbolicLinks'] == true,
      enableFileWatching: map['enableFileWatching'] != false,
      excludedNames: (map['excludedNames'] as Iterable?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const ['.git', '.dart_tool', 'build', 'node_modules'],
    );
  }
}

@immutable
class DeveloperWorkspace {
  static const schemaVersion = 1;

  final String id;
  final String name;
  final String description;
  final String iconId;
  final WorkspaceRootRef root;
  final Set<WorkspaceKind> kinds;
  final DateTime createdAt;
  final DateTime lastOpenedAt;
  final bool pinned;
  final WorkspaceSettings settings;
  final int markdownFileCount;
  final int apiCollectionCount;
  final bool hasGitRepository;
  final bool isOkfCompatible;

  const DeveloperWorkspace({
    required this.id,
    required this.name,
    required this.root,
    required this.createdAt,
    required this.lastOpenedAt,
    this.description = '',
    this.iconId = 'terminal',
    this.kinds = const {WorkspaceKind.mixed},
    this.pinned = false,
    this.settings = const WorkspaceSettings(),
    this.markdownFileCount = 0,
    this.apiCollectionCount = 0,
    this.hasGitRepository = false,
    this.isOkfCompatible = false,
  });

  DeveloperWorkspace copyWith({
    String? name,
    String? description,
    String? iconId,
    WorkspaceRootRef? root,
    Set<WorkspaceKind>? kinds,
    DateTime? lastOpenedAt,
    bool? pinned,
    WorkspaceSettings? settings,
    int? markdownFileCount,
    int? apiCollectionCount,
    bool? hasGitRepository,
    bool? isOkfCompatible,
  }) {
    return DeveloperWorkspace(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconId: iconId ?? this.iconId,
      root: root ?? this.root,
      kinds: kinds ?? this.kinds,
      createdAt: createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      pinned: pinned ?? this.pinned,
      settings: settings ?? this.settings,
      markdownFileCount: markdownFileCount ?? this.markdownFileCount,
      apiCollectionCount: apiCollectionCount ?? this.apiCollectionCount,
      hasGitRepository: hasGitRepository ?? this.hasGitRepository,
      isOkfCompatible: isOkfCompatible ?? this.isOkfCompatible,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'name': name,
      'description': description,
      'iconId': iconId,
      'root': root.toMap(),
      'kinds': kinds.map((kind) => kind.name).toList(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastOpenedAt': lastOpenedAt.toUtc().toIso8601String(),
      'pinned': pinned,
      'settings': settings.toMap(),
      'markdownFileCount': markdownFileCount,
      'apiCollectionCount': apiCollectionCount,
      'hasGitRepository': hasGitRepository,
      'isOkfCompatible': isOkfCompatible,
    };
  }

  factory DeveloperWorkspace.fromMap(Map<dynamic, dynamic> map) {
    final now = DateTime.now().toUtc();
    final rawRoot = map['root'];
    final rawSettings = map['settings'];
    return DeveloperWorkspace(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Workspace',
      description: map['description']?.toString() ?? '',
      iconId: map['iconId']?.toString() ?? 'terminal',
      root: WorkspaceRootRef.fromMap(
        rawRoot is Map ? rawRoot : const <String, dynamic>{},
      ),
      kinds: {
        for (final raw in (map['kinds'] as Iterable?) ?? const [])
          if (_enumByNameOrNull(WorkspaceKind.values, raw) case final value?)
            value,
      }.isEmpty
          ? const {WorkspaceKind.mixed}
          : {
              for (final raw in (map['kinds'] as Iterable?) ?? const [])
                if (_enumByNameOrNull(WorkspaceKind.values, raw)
                    case final value?)
                  value,
            },
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? now,
      lastOpenedAt:
          DateTime.tryParse(map['lastOpenedAt']?.toString() ?? '') ?? now,
      pinned: map['pinned'] == true,
      settings: WorkspaceSettings.fromMap(
        rawSettings is Map ? rawSettings : const <String, dynamic>{},
      ),
      markdownFileCount: _nonNegativeInt(map['markdownFileCount']),
      apiCollectionCount: _nonNegativeInt(map['apiCollectionCount']),
      hasGitRepository: map['hasGitRepository'] == true,
      isOkfCompatible: map['isOkfCompatible'] == true,
    );
  }
}

@immutable
class WorkspaceHealthSummary {
  final WorkspaceHealthStatus status;
  final bool rootAvailable;
  final bool canRead;
  final bool canWrite;
  final List<String> notices;
  final DateTime checkedAt;

  const WorkspaceHealthSummary({
    required this.status,
    required this.rootAvailable,
    required this.canRead,
    required this.canWrite,
    required this.notices,
    required this.checkedAt,
  });
}

enum WorkspaceFileChangeKind { created, modified, deleted, moved, unknown }

@immutable
class WorkspaceFileEntry {
  final String relativePath;
  final bool isDirectory;
  final bool isLink;
  final int sizeBytes;
  final DateTime modifiedAt;

  const WorkspaceFileEntry({
    required this.relativePath,
    required this.isDirectory,
    required this.isLink,
    required this.sizeBytes,
    required this.modifiedAt,
  });
}

@immutable
class WorkspaceFileChange {
  final WorkspaceFileChangeKind kind;
  final String relativePath;
  final DateTime detectedAt;

  const WorkspaceFileChange({
    required this.kind,
    required this.relativePath,
    required this.detectedAt,
  });
}

T _enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  return _enumByNameOrNull(values, raw) ?? fallback;
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, dynamic raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

int _nonNegativeInt(dynamic value) {
  return value is int && value >= 0 ? value : 0;
}
