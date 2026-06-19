import 'package:flutter/material.dart';

import '../core/files/external_file.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/external_files/presentation/text_file_page.dart';
import '../features/markdown/presentation/markdown_page.dart';
import '../features/readme_generator/presentation/readme_page.dart';
import '../features/json_tools/presentation/json_page.dart';
import '../features/api_tester/presentation/api_page.dart';
import '../features/jwt_decoder/presentation/jwt_page.dart';
import '../features/regex_tester/presentation/regex_page.dart';
import '../features/base64_tool/presentation/base64_page.dart';
import '../features/url_tool/presentation/url_page.dart';
import '../features/timestamp_tool/presentation/timestamp_page.dart';
import '../features/uuid_tool/presentation/uuid_page.dart';
import '../features/diff_checker/presentation/diff_page.dart';
import '../features/snippets/presentation/snippets_page.dart';
import '../features/settings/presentation/settings_page.dart';

/// Generates routes for the application.
Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/dashboard':
      return MaterialPageRoute(builder: (_) => const DashboardPage());
    case '/markdown':
      return MaterialPageRoute(
        builder: (_) => MarkdownPage(
          initialDocument: _externalFileArgument(settings.arguments),
        ),
      );
    case '/readme':
      return MaterialPageRoute(builder: (_) => const ReadmeGeneratorPage());
    case '/json':
      return MaterialPageRoute(
        builder: (_) => JsonPage(
          initialDocument: _externalFileArgument(settings.arguments),
        ),
      );
    case '/api':
      return MaterialPageRoute(
        builder: (_) => ApiPage(
          initialDocument: _externalFileArgument(settings.arguments),
        ),
      );
    case '/jwt':
      return MaterialPageRoute(builder: (_) => const JwtPage());
    case '/regex':
      return MaterialPageRoute(builder: (_) => const RegexPage());
    case '/base64':
      return MaterialPageRoute(builder: (_) => const Base64Page());
    case '/url':
      return MaterialPageRoute(builder: (_) => const UrlPage());
    case '/timestamp':
      return MaterialPageRoute(builder: (_) => const TimestampPage());
    case '/uuid':
      return MaterialPageRoute(builder: (_) => const UuidPage());
    case '/diff':
      return MaterialPageRoute(builder: (_) => const DiffPage());
    case '/snippets':
      return MaterialPageRoute(builder: (_) => const SnippetsPage());
    case '/settings':
      return MaterialPageRoute(
        builder: (_) => SettingsPage(
          initialDocument: _externalFileArgument(settings.arguments),
        ),
      );
    case '/external-text':
      final document = _externalFileArgument(settings.arguments);
      if (document == null) {
        return _notFoundRoute('No external file was provided.');
      }
      return MaterialPageRoute(
        builder: (_) => TextFilePage(document: document),
      );
    default:
      // Unknown route fallback
      return _notFoundRoute('Page ${settings.name} not found.');
  }
}

ExternalFileDocument? _externalFileArgument(Object? arguments) {
  return arguments is ExternalFileDocument ? arguments : null;
}

Route<dynamic> _notFoundRoute(String message) {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(child: Text(message)),
    ),
  );
}
