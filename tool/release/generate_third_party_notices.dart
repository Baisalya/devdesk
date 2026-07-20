import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final configFile = File('.dart_tool/package_config.json');
  if (!await configFile.exists()) {
    stderr.writeln('Run flutter pub get before generating notices.');
    exitCode = 2;
    return;
  }
  final decoded = jsonDecode(await configFile.readAsString());
  if (decoded is! Map || decoded['packages'] is! List) {
    throw const FormatException('Invalid package_config.json.');
  }
  final output = StringBuffer()
    ..writeln('# Resolved Third-Party Notices')
    ..writeln()
    ..writeln(
        'Generated from the dependency graph resolved for this source revision.')
    ..writeln();
  final missing = <String>[];
  final packages = (decoded['packages'] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList()
    ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));

  for (final package in packages) {
    final name = package['name'] as String?;
    final rootUriValue = package['rootUri'] as String?;
    if (name == null || rootUriValue == null || name == 'devdesk') continue;
    final rootUri = configFile.uri.resolve(rootUriValue);
    if (rootUri.scheme != 'file') {
      missing.add(name);
      continue;
    }
    final root = Directory.fromUri(rootUri);
    File? license;
    for (final candidate in const [
      'LICENSE',
      'LICENSE.md',
      'LICENSE.txt',
      'COPYING',
      'NOTICE'
    ]) {
      final file = File('${root.path}${Platform.pathSeparator}$candidate');
      if (await file.exists()) {
        license = file;
        break;
      }
    }
    if (license == null) {
      missing.add(name);
      continue;
    }
    output
      ..writeln('## $name')
      ..writeln()
      ..writeln('```text')
      ..writeln((await license.readAsString()).trimRight())
      ..writeln('```')
      ..writeln();
  }

  if (missing.isNotEmpty) {
    stderr.writeln('No license file found for: ${missing.join(', ')}');
    exitCode = 3;
    return;
  }
  final target = File('THIRD_PARTY_NOTICES.generated.md');
  await target.writeAsString(output.toString(), flush: true);
  stdout.writeln('Generated ${target.path}.');
}
