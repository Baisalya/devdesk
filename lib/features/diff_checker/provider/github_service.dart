import 'package:http/http.dart' as http;

import '../../../core/archive/archive_policy.dart';
import '../../../core/errors/failure.dart';
import '../../../core/network/bounded_http.dart';

class GitHubRepoRef {
  final String owner;
  final String repo;
  final String? branch;
  final String? path;

  const GitHubRepoRef({
    required this.owner,
    required this.repo,
    this.branch,
    this.path,
  });

  String get zipUrl =>
      'https://github.com/$owner/$repo/archive/refs/heads/${branch ?? 'main'}.zip';
}

class GitHubService {
  static const Duration _totalTimeout = Duration(seconds: 30);

  /// Parses only canonical HTTPS GitHub repository URLs.
  static GitHubRepoRef? parseUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.scheme != 'https' || uri.host.toLowerCase() != 'github.com') {
        return null;
      }
      if (uri.userInfo.isNotEmpty || uri.port != 443 && uri.hasPort) {
        return null;
      }

      final segments =
          uri.pathSegments.where((part) => part.isNotEmpty).toList();
      if (segments.length < 2) return null;

      final owner = segments[0];
      final repo = segments[1].endsWith('.git')
          ? segments[1].substring(0, segments[1].length - 4)
          : segments[1];
      if (owner.isEmpty || repo.isEmpty) return null;

      String? branch;
      String? path;
      if (segments.length >= 4 &&
          (segments[2] == 'tree' || segments[2] == 'blob')) {
        branch = segments[3];
        if (segments.length > 4) path = segments.sublist(4).join('/');
      }
      return GitHubRepoRef(
        owner: owner,
        repo: repo,
        branch: branch,
        path: path,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches a bounded ZIP archive of a public repository. Callers must still
  /// pass the returned bytes through [ArchivePolicy.inspect] before decoding.
  static Future<List<int>?> fetchRepoZip(
    GitHubRepoRef ref, {
    String? token,
    http.Client? client,
  }) async {
    final ownedClient = client == null;
    final actualClient = client ?? http.Client();
    try {
      final response = await _send(
        actualClient,
        Uri.parse(ref.zipUrl),
        token: token,
        maxBytes: ArchivePolicy.defaultMaxArchiveBytes,
      );
      if (response.streamedResponse.statusCode != 200) return null;
      ArchivePolicy.inspect(response.bytes);
      return response.bytes;
    } finally {
      if (ownedClient) actualClient.close();
    }
  }

  /// Fetches one public GitHub file with strict deadlines and a 5 MB ceiling.
  static Future<String?> fetchFileContent(
    GitHubRepoRef ref, {
    String? token,
    http.Client? client,
  }) async {
    if (ref.path == null || ref.path!.isEmpty) return null;
    final rawUrl = Uri.https(
      'raw.githubusercontent.com',
      '/${ref.owner}/${ref.repo}/${ref.branch ?? 'main'}/${ref.path}',
    );
    final ownedClient = client == null;
    final actualClient = client ?? http.Client();
    try {
      final response = await _send(
        actualClient,
        rawUrl,
        token: token,
        maxBytes: 5 * 1024 * 1024,
      );
      if (response.streamedResponse.statusCode != 200) return null;
      if (response.isBinary) {
        throw ApiFailure(
            'The selected GitHub file is binary and cannot be diffed as text.');
      }
      return response.body;
    } finally {
      if (ownedClient) actualClient.close();
    }
  }

  static Future<BoundedHttpResponse> _send(
    http.Client client,
    Uri uri, {
    required String? token,
    required int maxBytes,
  }) {
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'application/vnd.github+json';
    if (token != null && token.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return BoundedHttpReader.send(
      client: client,
      request: request,
      totalTimeout: _totalTimeout,
      maxResponseBytes: maxBytes,
    );
  }
}
