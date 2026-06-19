import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/files/external_file.dart';

void main() {
  test('detects README and markdown files as markdown', () {
    expect(
      ExternalFileDetector.detect('README.md', '# DevDesk'),
      DevFileKind.markdown,
    );
    expect(
      ExternalFileDetector.detect('README.txt', '# DevDesk'),
      DevFileKind.markdown,
    );
  });

  test('detects JSON, API collections, backups, and text files', () {
    expect(
      ExternalFileDetector.detect('data.json', '{"ok":true}'),
      DevFileKind.json,
    );
    expect(
      ExternalFileDetector.detect(
        'collection.json',
        '{"type":"devdesk_api_collection","requests":[{"method":"GET","url":"https://example.com"}]}',
      ),
      DevFileKind.apiCollection,
    );
    expect(
      ExternalFileDetector.detect(
        'backup.json',
        '{"type":"devdesk_backup","boxes":{"settings":{}}}',
      ),
      DevFileKind.backup,
    );
    expect(
      ExternalFileDetector.detect('main.dart', 'void main() {}'),
      DevFileKind.text,
    );
  });

  test('rejects non UTF-8 text and oversized files', () {
    expect(
      () => ExternalFileDetector.decodeUtf8([0xff, 0xfe, 0xfd]),
      throwsA(isA<ExternalFileException>()),
    );
    expect(
      () => ExternalFileDetector.guardFileSize(
        ExternalFileDetector.maxFileBytes + 1,
      ),
      throwsA(isA<ExternalFileException>()),
    );
  });
}
