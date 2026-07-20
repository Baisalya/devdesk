import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../../core/archive/archive_policy.dart';

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
  static const int maxEntries = 10000;
  static const int maxComparableFileBytes = 5 * 1024 * 1024;
  static const int maxComparableTotalBytes = 100 * 1024 * 1024;

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
    if (allPaths.length > maxEntries) {
      throw const FileSystemException(
        'Folder comparison contains too many entries.',
      );
    }
    final result = <FolderDiffEntry>[];
    var comparedBytes = 0;

    for (final path in allPaths) {
      final inA = filesA.containsKey(path);
      final inB = filesB.containsKey(path);

      if (inA && !inB) {
        result.add(FolderDiffEntry(
            path: path,
            isDirectory:
                filesA[path]!.statSync().type == FileSystemEntityType.directory,
            status: FileStatus.removed));
      } else if (!inA && inB) {
        result.add(FolderDiffEntry(
            path: path,
            isDirectory:
                filesB[path]!.statSync().type == FileSystemEntityType.directory,
            status: FileStatus.added));
      } else {
        // Both exist, compare content for files
        if (filesA[path]!.statSync().type == FileSystemEntityType.file) {
          final fileA = filesA[path] as File;
          final fileB = filesB[path] as File;
          final sizeA = fileA.lengthSync();
          final sizeB = fileB.lengthSync();
          if (sizeA > maxComparableFileBytes ||
              sizeB > maxComparableFileBytes) {
            throw FileSystemException(
              'A file exceeds the safe folder comparison limit.',
              path,
            );
          }
          comparedBytes += sizeA + sizeB;
          if (comparedBytes > maxComparableTotalBytes) {
            throw const FileSystemException(
              'Folder comparison exceeds the safe total byte limit.',
            );
          }
          final contentA = fileA.readAsBytesSync();
          final contentB = fileB.readAsBytesSync();
          final changed = !_bytesEqual(contentA, contentB);
          result.add(FolderDiffEntry(
              path: path,
              isDirectory: false,
              status: changed ? FileStatus.changed : FileStatus.unchanged));
        } else {
          result.add(FolderDiffEntry(
              path: path, isDirectory: true, status: FileStatus.unchanged));
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
    ArchivePolicy.inspect(zipBytesA);
    ArchivePolicy.inspect(zipBytesB);
    final archiveA = ZipDecoder().decodeBytes(zipBytesA, verify: true);
    final archiveB = ZipDecoder().decodeBytes(zipBytesB, verify: true);

    final filesA = {for (var file in archiveA) file.name: file};
    final filesB = {for (var file in archiveB) file.name: file};

    final allPaths = {...filesA.keys, ...filesB.keys}.toList()..sort();
    if (allPaths.length > maxEntries) {
      throw const ArchivePolicyException(
          'ZIP comparison contains too many entries.');
    }
    final result = <FolderDiffEntry>[];

    for (final path in allPaths) {
      final inA = filesA.containsKey(path);
      final inB = filesB.containsKey(path);

      if (inA && !inB) {
        result.add(FolderDiffEntry(
            path: path,
            isDirectory: !filesA[path]!.isFile,
            status: FileStatus.removed));
      } else if (!inA && inB) {
        result.add(FolderDiffEntry(
            path: path,
            isDirectory: !filesB[path]!.isFile,
            status: FileStatus.added));
      } else {
        final fileA = filesA[path]!;
        final fileB = filesB[path]!;
        if (fileA.isFile && fileB.isFile) {
          final changed = !_bytesEqual(fileA.content, fileB.content);
          result.add(FolderDiffEntry(
              path: path,
              isDirectory: false,
              status: changed ? FileStatus.changed : FileStatus.unchanged));
        } else {
          final bothDirectories = !fileA.isFile && !fileB.isFile;
          result.add(FolderDiffEntry(
              path: path,
              isDirectory: bothDirectories,
              status:
                  bothDirectories ? FileStatus.unchanged : FileStatus.changed));
        }
      }
    }

    return result;
  }

  static Map<String, FileSystemEntity> _listAllFiles(
      Directory dir, Set<String> ignores) {
    final result = <String, FileSystemEntity>{};
    final rootPath = dir.path;

    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      final relativePath = p.relative(entity.path, from: rootPath);
      if (_shouldIgnore(relativePath, ignores)) continue;
      if (result.length >= maxEntries) {
        throw const FileSystemException(
          'Folder comparison contains too many entries.',
        );
      }
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
