import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class FolderDiffEntry {
  final String path;
  final bool isDirectory;
  final FileStatus status;

  const FolderDiffEntry({
    required this.path,
    required this.isDirectory,
    required this.status,
  });
}

enum FileStatus { added, removed, changed, unchanged }

class FolderDiffService {
  static const Set<String> defaultIgnores = {
    '.git',
    'build',
    'node_modules',
    '.dart_tool',
    '.gradle',
    'android/build',
    'ios/Pods',
    'windows/build',
    '.DS_Store',
  };

  /// Compares two local directories (Windows).
  static List<FolderDiffEntry> compareLocalFolders(
    Directory dirA,
    Directory dirB, {
    Set<String> customIgnores = const {},
  }) {
    final ignores = {...defaultIgnores, ...customIgnores};
    final filesA = _listAllFiles(dirA, ignores);
    final filesB = _listAllFiles(dirB, ignores);

    final allPaths = {...filesA.keys, ...filesB.keys}.toList()..sort();
    final result = <FolderDiffEntry>[];

    for (final path in allPaths) {
      final inA = filesA.containsKey(path);
      final inB = filesB.containsKey(path);

      if (inA && !inB) {
        result.add(FolderDiffEntry(path: path, isDirectory: filesA[path]!.statSync().type == FileSystemEntityType.directory, status: FileStatus.removed));
      } else if (!inA && inB) {
        result.add(FolderDiffEntry(path: path, isDirectory: filesB[path]!.statSync().type == FileSystemEntityType.directory, status: FileStatus.added));
      } else {
        // Both exist, compare content for files
        if (filesA[path]!.statSync().type == FileSystemEntityType.file) {
          final contentA = (filesA[path] as File).readAsBytesSync();
          final contentB = (filesB[path] as File).readAsBytesSync();
          final changed = !_bytesEqual(contentA, contentB);
          result.add(FolderDiffEntry(path: path, isDirectory: false, status: changed ? FileStatus.changed : FileStatus.unchanged));
        } else {
          result.add(FolderDiffEntry(path: path, isDirectory: true, status: FileStatus.unchanged));
        }
      }
    }

    return result;
  }

  /// Compares two ZIP files (Android).
  static List<FolderDiffEntry> compareZips(
    List<int> zipBytesA,
    List<int> zipBytesB,
  ) {
    final archiveA = ZipDecoder().decodeBytes(zipBytesA);
    final archiveB = ZipDecoder().decodeBytes(zipBytesB);

    final filesA = {for (var file in archiveA) file.name: file};
    final filesB = {for (var file in archiveB) file.name: file};

    final allPaths = {...filesA.keys, ...filesB.keys}.toList()..sort();
    final result = <FolderDiffEntry>[];

    for (final path in allPaths) {
      final inA = filesA.containsKey(path);
      final inB = filesB.containsKey(path);

      if (inA && !inB) {
        result.add(FolderDiffEntry(path: path, isDirectory: filesA[path]!.content == null, status: FileStatus.removed));
      } else if (!inA && inB) {
        result.add(FolderDiffEntry(path: path, isDirectory: filesB[path]!.content == null, status: FileStatus.added));
      } else {
        final fileA = filesA[path]!;
        final fileB = filesB[path]!;
        if (fileA.content != null && fileB.content != null) {
          final changed = !_bytesEqual(fileA.content as List<int>, fileB.content as List<int>);
          result.add(FolderDiffEntry(path: path, isDirectory: false, status: changed ? FileStatus.changed : FileStatus.unchanged));
        } else {
          result.add(FolderDiffEntry(path: path, isDirectory: true, status: FileStatus.unchanged));
        }
      }
    }

    return result;
  }

  static Map<String, FileSystemEntity> _listAllFiles(Directory dir, Set<String> ignores) {
    final result = <String, FileSystemEntity>{};
    final rootPath = dir.path;

    for (final entity in dir.listSync(recursive: true)) {
      final relativePath = p.relative(entity.path, from: rootPath);
      if (_shouldIgnore(relativePath, ignores)) continue;
      result[relativePath] = entity;
    }
    return result;
  }

  static bool _shouldIgnore(String relativePath, Set<String> ignores) {
    final parts = p.split(relativePath);
    return parts.any((part) => ignores.contains(part));
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
