import 'package:http/http.dart' as http;

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

  String get zipUrl => 'https://github.com/$owner/$repo/archive/refs/heads/${branch ?? 'main'}.zip';
}

class GitHubService {
  /// Parses a GitHub URL into a [GitHubRepoRef].
  static GitHubRepoRef? parseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host != 'github.com') return null;

      final segments = uri.pathSegments;
      if (segments.length < 2) return null;

      final owner = segments[0];
      final repo = segments[1];
      String? branch;
      String? path;

      if (segments.length >= 4 && (segments[2] == 'tree' || segments[2] == 'blob')) {
        branch = segments[3];
        if (segments.length > 4) {
          path = segments.sublist(4).join('/');
        }
      }

      return GitHubRepoRef(owner: owner, repo: repo, branch: branch, path: path);
    } catch (_) {
      return null;
    }
  }

  /// Fetches the ZIP archive of a public repository.
  static Future<List<int>?> fetchRepoZip(GitHubRepoRef ref, {String? token}) async {
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'token $token';
    }

    final response = await http.get(Uri.parse(ref.zipUrl), headers: headers);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  /// Fetches a single file content from GitHub via Raw URL.
  static Future<String?> fetchFileContent(GitHubRepoRef ref, {String? token}) async {
    if (ref.path == null) return null;
    
    final rawUrl = 'https://raw.githubusercontent.com/${ref.owner}/${ref.repo}/${ref.branch ?? 'main'}/${ref.path}';
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'token $token';
    }

    final response = await http.get(Uri.parse(rawUrl), headers: headers);
    if (response.statusCode == 200) {
      return response.body;
    }
    return null;
  }
}
