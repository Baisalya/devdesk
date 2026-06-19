import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/features/api_tester/models/api_request.dart';
import 'package:devdesk/features/api_tester/utils/api_collection_utils.dart';

void main() {
  test('API collection export excludes secrets by default', () {
    final exported = ApiCollectionUtils.exportCollection([
      ApiRequest(
        method: 'GET',
        url: 'https://api.example.com/users',
        headers: {
          'Authorization': 'Bearer secret',
          'Accept': 'application/json',
        },
      ),
    ]);

    final request = (exported['requests'] as List).single as Map;
    final headers = request['headers'] as Map;
    expect(headers, isNot(contains('Authorization')));
    expect(headers['Accept'], 'application/json');
  });

  test('API collection import strips or keeps sensitive headers explicitly',
      () {
    final document = {
      'type': 'devdesk_api_collection',
      'requests': [
        {
          'method': 'POST',
          'url': 'https://api.example.com/users',
          'headers': {'Authorization': 'Bearer secret'},
          'queryParams': {},
          'body': '{"name":"DevDesk"}',
        },
      ],
    };

    final preview = ApiCollectionUtils.preview(document);
    expect(preview.requestCount, 1);
    expect(preview.hasSensitiveHeaders, isTrue);

    final stripped = ApiCollectionUtils.importRequests(document);
    expect(stripped.single.headers, isEmpty);

    final withSecrets = ApiCollectionUtils.importRequests(
      document,
      includeSecrets: true,
    );
    expect(withSecrets.single.headers['Authorization'], 'Bearer secret');
  });

  test('API collection invalid schema throws FormatException', () {
    expect(
      () => ApiCollectionUtils.importRequests({'requests': []}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ApiCollectionUtils.importRequests({
        'requests': [
          {'method': 'TRACE', 'url': 'https://example.com'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
