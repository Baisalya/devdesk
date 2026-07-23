import 'package:devdesk/features/search/domain/unified_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const records = [
    SearchRecord(
      id: 'w1',
      kind: SearchEntityKind.workspace,
      title: 'Payments Platform',
      subtitle: 'C:/payments',
      searchableText: 'billing checkout',
      reference: 'workspace:w1',
    ),
    SearchRecord(
      id: 'r1',
      kind: SearchEntityKind.apiRequest,
      title: 'Create payment',
      subtitle: 'POST /payments',
      searchableText: 'checkout transaction',
      reference: 'api-request:r1',
    ),
  ];

  test('ranks title matches and supports type filters', () {
    final index = UnifiedSearchIndex(records);
    expect(index.search('payment').first.record.id, 'w1');
    expect(
      index
          .search(
            'payment',
            kinds: {SearchEntityKind.apiRequest},
          )
          .single
          .record
          .id,
      'r1',
    );
    expect(index.search('checkout').length, 2);
  });

  test('typed references reject unknown schemes and resolve exact targets', () {
    expect(TypedReference.tryParse('https://example.com'), isNull);
    expect(TypedReference.tryParse('api-request:r1')?.target, 'r1');
    expect(TypedReference.tryParse('openapi:petstore#/paths/~1pets')?.fragment,
        '/paths/~1pets');
    final resolver = TypedReferenceResolver(records);
    expect(resolver.resolve('api-request:r1')?.title, 'Create payment');
    expect(resolver.resolve('api-request:missing'), isNull);
  });
}
