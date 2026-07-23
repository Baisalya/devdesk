import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/failure.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../domain/workspace_file_system.dart';
import '../domain/workspace_models.dart';

class LocalWorkspaceFileSystem implements WorkspaceFileSystem {
  const LocalWorkspaceFileSystem();

  @override
  Future<WorkspaceRootRef?> pickRoot() async {
    if (kIsWeb) {
      throw PlatformCapabilityFailure(
        'Folder workspaces are not available in this build.',
        code: 'DD-WORKSPACE-PICK-UNSUPPORTED',
      );
    }
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select workspace folder',
      lockParentWindow: true,
    );
    if (selected == null) return null;
    return rootFromLocalPath(selected);
  }

  @override
  Future<WorkspaceRootRef> rootFromLocalPath(String path) async {
    if (kIsWeb) {
      throw PlatformCapabilityFailure(
        'Local folder paths are not available in this build.',
        code: 'DD-WORKSPACE-PATH-UNSUPPORTED',
      );
    }
    final trimmed = path.trim();
    if (trimmed.isEmpty || !p.isAbsolute(trimmed)) {
      throw ValidationFailure(
        'Select an absolute workspace folder.',
        code: 'DD-WORKSPACE-PATH',
      );
    }
    final normalized = p.normalize(p.absolute(trimmed));
    final type = await FileSystemEntity.type(normalized, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw FileAccessFailure(
        'Symbolic-link workspace roots are disabled for safety.',
        code: 'DD-WORKSPACE-ROOT-LINK',
      );
    }
    if (type != FileSystemEntityType.directory) {
      throw FileAccessFailure(
        'The selected workspace folder is unavailable.',
        code: 'DD-WORKSPACE-ROOT-MISSING',
        retryable: true,
      );
    }
    final platform = defaultTargetPlatform == TargetPlatform.windows
        ? WorkspacePlatform.windows
        : defaultTargetPlatform == TargetPlatform.android
            ? WorkspacePlatform.android
            : WorkspacePlatform.unknown;
    final capabilities = <WorkspaceCapability>{
      WorkspaceCapability.read,
      WorkspaceCapability.enumerate,
    };
    if (await _canCreateTemporaryFile(normalized)) {
      capabilities.add(WorkspaceCapability.write);
      if (platform == WorkspacePlatform.windows) {
        capabilities.add(WorkspaceCapability.atomicWrite);
      }
    }
    if (platform == WorkspacePlatform.windows) {
      capabilities.add(WorkspaceCapability.watch);
      capabilities.add(WorkspaceCapability.gitCli);
    }
    return WorkspaceRootRef(
      kind: WorkspaceRootKind.localPath,
      platform: platform,
      value: normalized,
      displayPath: normalized,
      capabilities: capabilities,
    );
  }

  @override
  Future<WorkspaceHealthSummary> inspect(WorkspaceRootRef root) async {
    final now = DateTime.now().toUtc();
    if (root.kind != WorkspaceRootKind.localPath) {
      return WorkspaceHealthSummary(
        status: WorkspaceHealthStatus.attention,
        rootAvailable: false,
        canRead: root.supports(WorkspaceCapability.read),
        canWrite: root.supports(WorkspaceCapability.write),
        notices: const [
          'This document-tree grant requires its platform adapter.',
        ],
        checkedAt: now,
      );
    }
    final type = await FileSystemEntity.type(root.value, followLinks: false);
    if (type != FileSystemEntityType.directory) {
      return WorkspaceHealthSummary(
        status: WorkspaceHealthStatus.unavailable,
        rootAvailable: false,
        canRead: false,
        canWrite: false,
        notices: const [
          'The folder is missing, inaccessible, or no longer a directory.',
        ],
        checkedAt: now,
      );
    }
    final canWrite = await _canCreateTemporaryFile(root.value);
    final notices = <String>[];
    if (!canWrite) {
      notices.add('The folder is read-only. Editing actions will be disabled.');
    }
    return WorkspaceHealthSummary(
      status: canWrite
          ? WorkspaceHealthStatus.healthy
          : WorkspaceHealthStatus.attention,
      rootAvailable: true,
      canRead: true,
      canWrite: canWrite,
      notices: notices,
      checkedAt: now,
    );
  }

  @override
  String normalizeRelativePath(String relativePath) {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty || p.isAbsolute(trimmed)) {
      if (trimmed.isEmpty) return '';
      throw ValidationFailure(
        'Workspace paths must be relative to the selected folder.',
        code: 'DD-WORKSPACE-RELATIVE-PATH',
      );
    }
    final normalized = p.normalize(trimmed);
    final segments = p.split(normalized);
    if (normalized == '..' || segments.any((segment) => segment == '..')) {
      throw ValidationFailure(
        'The workspace path would leave the selected folder.',
        code: 'DD-WORKSPACE-PATH-TRAVERSAL',
      );
    }
    return normalized == '.' ? '' : normalized;
  }

  @override
  Future<List<WorkspaceFileEntry>> list(
    WorkspaceRootRef root, {
    String relativeDirectory = '',
    int maxEntries = 10000,
  }) async {
    _requireLocalCapability(root, WorkspaceCapability.enumerate);
    if (maxEntries < 1 || maxEntries > 100000) {
      throw ValidationFailure(
        'Workspace entry limit must be between 1 and 100000.',
        code: 'DD-WORKSPACE-ENTRY-LIMIT',
      );
    }
    final target = _resolve(root, relativeDirectory);
    await _ensureNoLinkTraversal(root, target);
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type != FileSystemEntityType.directory) {
      throw FileAccessFailure(
        'The workspace folder is unavailable.',
        code: 'DD-WORKSPACE-LIST-DIRECTORY',
        retryable: true,
      );
    }
    final entries = <WorkspaceFileEntry>[];
    await for (final entity in Directory(target).list(followLinks: false)) {
      if (entries.length >= maxEntries) {
        throw FileAccessFailure(
          'The folder contains more than $maxEntries entries. Narrow the folder or increase the approved limit.',
          code: 'DD-WORKSPACE-ENTRY-LIMIT',
        );
      }
      final entityType = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );
      final stat = await entity.stat();
      entries.add(
        WorkspaceFileEntry(
          relativePath: p.relative(entity.path, from: root.value),
          isDirectory: entityType == FileSystemEntityType.directory,
          isLink: entityType == FileSystemEntityType.link,
          sizeBytes: entityType == FileSystemEntityType.file ? stat.size : 0,
          modifiedAt: stat.modified.toUtc(),
        ),
      );
    }
    entries.sort((left, right) {
      if (left.isDirectory != right.isDirectory) {
        return left.isDirectory ? -1 : 1;
      }
      return left.relativePath.toLowerCase().compareTo(
            right.relativePath.toLowerCase(),
          );
    });
    return entries;
  }

  @override
  Future<Uint8List> readBytes(
    WorkspaceRootRef root,
    String relativePath, {
    int maxBytes = 5 * 1024 * 1024,
  }) async {
    _requireLocalCapability(root, WorkspaceCapability.read);
    if (maxBytes < 1 || maxBytes > 100 * 1024 * 1024) {
      throw ValidationFailure(
        'Workspace file limit must be between 1 byte and 100 MB.',
        code: 'DD-WORKSPACE-FILE-LIMIT',
      );
    }
    final target = _resolve(root, relativePath);
    await _ensureNoLinkTraversal(root, target);
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw FileAccessFailure(
        'Symbolic-link workspace files are not opened automatically.',
        code: 'DD-WORKSPACE-FILE-LINK',
      );
    }
    if (type != FileSystemEntityType.file) {
      throw FileAccessFailure(
        'The workspace file is unavailable.',
        code: 'DD-WORKSPACE-FILE-MISSING',
        retryable: true,
      );
    }
    final file = File(target);
    final length = await file.length();
    if (length > maxBytes) {
      throw FileAccessFailure(
        'The file is larger than the approved ${_formatBytes(maxBytes)} limit.',
        code: 'DD-WORKSPACE-FILE-LIMIT',
      );
    }
    return file.readAsBytes();
  }

  @override
  Future<void> createFile(
    WorkspaceRootRef root,
    String relativePath,
    Uint8List bytes,
  ) async {
    _requireLocalCapability(root, WorkspaceCapability.write);
    ExternalFileDetector.guardFileSize(bytes.length);
    final target = _resolve(root, relativePath);
    final parent = Directory(p.dirname(target));
    await _ensureNoLinkTraversal(root, parent.path);
    final parentType = await FileSystemEntity.type(
      parent.path,
      followLinks: false,
    );
    if (parentType != FileSystemEntityType.directory) {
      throw FileAccessFailure(
        'The destination folder does not exist.',
        code: 'DD-WORKSPACE-CREATE-PARENT',
      );
    }
    final file = File(target);
    var created = false;
    try {
      await file.create(exclusive: true);
      created = true;
      final handle = await file.open(mode: FileMode.writeOnly);
      try {
        await handle.writeFrom(bytes);
        await handle.flush();
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      if (created) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {
          // The path was exclusively created by this operation. Leaving a
          // partial new file is still safer than touching any existing file.
        }
      }
      throw FileAccessFailure(
        'The file already exists or could not be created. No existing file was replaced.',
        code: 'DD-WORKSPACE-CREATE',
      );
    }
  }

  @override
  Future<void> writeTextAtomically(
    WorkspaceRootRef root,
    String relativePath,
    String content, {
    String? expectedFingerprint,
  }) async {
    _requireLocalCapability(root, WorkspaceCapability.atomicWrite);
    final target = _resolve(root, relativePath);
    await _ensureNoLinkTraversal(root, target);
    final bytes = await readBytes(root, relativePath);
    final fingerprint = ExternalFileDetector.fingerprint(bytes);
    if (expectedFingerprint != null && expectedFingerprint != fingerprint) {
      throw FileAccessFailure(
        'The file changed after it was opened. Reload it or save a copy.',
        code: 'DD-WORKSPACE-EXTERNAL-EDIT',
      );
    }
    final decoded = ExternalFileDetector.decodeText(bytes);
    final stat = await File(target).stat();
    final document = ExternalFileDocument(
      name: p.basename(target),
      path: target,
      sizeBytes: bytes.length,
      content: decoded.content,
      kind: ExternalFileDetector.detect(p.basename(target), decoded.content),
      encoding: decoded.encoding,
      lineEnding: decoded.lineEnding,
      originalModifiedAt: stat.modified.toUtc(),
      originalFingerprint: fingerprint,
      canOverwriteOriginal: true,
    );
    await ExternalFileService.overwriteOriginal(document, content);
  }

  @override
  Stream<WorkspaceFileChange> watch(WorkspaceRootRef root) {
    _requireLocalCapability(root, WorkspaceCapability.watch);
    return Directory(root.value).watch(recursive: true).map((event) {
      final kind = switch (event.type) {
        FileSystemEvent.create => WorkspaceFileChangeKind.created,
        FileSystemEvent.modify => WorkspaceFileChangeKind.modified,
        FileSystemEvent.delete => WorkspaceFileChangeKind.deleted,
        FileSystemEvent.move => WorkspaceFileChangeKind.moved,
        _ => WorkspaceFileChangeKind.unknown,
      };
      return WorkspaceFileChange(
        kind: kind,
        relativePath: p.relative(event.path, from: root.value),
        detectedAt: DateTime.now().toUtc(),
      );
    });
  }

  String _resolve(WorkspaceRootRef root, String relativePath) {
    if (root.kind != WorkspaceRootKind.localPath) {
      throw PlatformCapabilityFailure(
        'This workspace root requires its document-tree adapter.',
        code: 'DD-WORKSPACE-ROOT-ADAPTER',
      );
    }
    final relative = normalizeRelativePath(relativePath);
    final target = p.normalize(p.join(root.value, relative));
    if (target != p.normalize(root.value) && !p.isWithin(root.value, target)) {
      throw ValidationFailure(
        'The workspace path would leave the selected folder.',
        code: 'DD-WORKSPACE-PATH-TRAVERSAL',
      );
    }
    return target;
  }

  void _requireLocalCapability(
    WorkspaceRootRef root,
    WorkspaceCapability capability,
  ) {
    if (root.kind != WorkspaceRootKind.localPath ||
        !root.supports(capability)) {
      throw PlatformCapabilityFailure(
        '${capability.name} is not available for this workspace on ${root.platform.name}.',
        code: 'DD-WORKSPACE-CAPABILITY',
      );
    }
  }

  Future<void> _ensureNoLinkTraversal(
    WorkspaceRootRef root,
    String target,
  ) async {
    final relative = p.relative(target, from: root.value);
    var cursor = p.normalize(root.value);
    for (final segment in p.split(relative)) {
      if (segment == '.' || segment.isEmpty) continue;
      cursor = p.join(cursor, segment);
      final type = await FileSystemEntity.type(cursor, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw FileAccessFailure(
          'Symbolic links inside a workspace are not traversed automatically.',
          code: 'DD-WORKSPACE-PATH-LINK',
        );
      }
      if (type == FileSystemEntityType.notFound) return;
    }
  }

  static Future<bool> _canCreateTemporaryFile(String directory) async {
    final file = File(
      p.join(
        directory,
        '.devdesk-access-$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    try {
      await file.create(exclusive: true);
      return true;
    } on FileSystemException {
      return false;
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A zero-byte access probe is harmless; source files are untouched.
      }
    }
  }

  static String _formatBytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
    return '$value byte';
  }
}
