import 'package:flutter_test/flutter_test.dart';

import 'package:devdesk/core/errors/failure.dart';
import 'package:devdesk/features/knowledge/domain/frontmatter_document.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_graph_builder.dart';
import 'package:devdesk/features/knowledge/domain/knowledge_models.dart';
import 'package:devdesk/features/knowledge/domain/markdown_link_parser.dart';

void main() {
  group('FrontmatterDocument', () {
    test('parses nested safe YAML values', () {
      final document = FrontmatterDocument.parse('''---
type: API Endpoint
title: Create Customer
tags:
  - customers
  - api
custom:
  owner:
    team: platform
enabled: true
---
# Body
''');

      expect(document.fields['type'], 'API Endpoint');
      expect(document.fields['tags'], ['customers', 'api']);
      expect(
        document.fields['custom'],
        {
          'owner': {'team': 'platform'},
        },
      );
      expect(document.fields['enabled'], isTrue);
      expect(document.body, '# Body\n');
    });

    test('patches selected fields while preserving unknown YAML and comments',
        () {
      final document = FrontmatterDocument.parse('''---
# Producer extension must remain byte-stable.
producer_extension:
  nested: value
title: Old title
tags: [old]
---
Body
''');

      final updated = document.applyFields({
        'title': 'New: title',
        'tags': ['new', 'api'],
        'review_after': '2026-10-22T00:00:00Z',
      });
      final rendered = updated.render();

      expect(
          rendered, contains('# Producer extension must remain byte-stable.'));
      expect(rendered, contains('producer_extension:\n  nested: value'));
      expect(rendered, contains('title: "New: title"'));
      expect(rendered, contains('  - "new"'));
      expect(rendered, contains('review_after: "2026-10-22T00:00:00Z"'));
      expect(FrontmatterDocument.parse(rendered).fields['title'], 'New: title');
    });

    test('reports malformed YAML without exposing a raw parser exception', () {
      expect(
        () => FrontmatterDocument.parse('''---
type: [unterminated
---
body'''),
        throwsA(
          isA<ParsingFailure>().having(
            (failure) => failure.code,
            'code',
            'DD-FRONTMATTER-YAML',
          ),
        ),
      );
    });

    test(
        'documents without frontmatter remain unchanged until fields are added',
        () {
      final document = FrontmatterDocument.parse('# Plain\n');
      expect(document.render(), '# Plain\n');
      final updated = document.applyFields({'type': 'Concept'});
      expect(
          updated.renderWithFrontmatter(), startsWith('---\ntype: "Concept"'));
      expect(updated.renderWithFrontmatter(), endsWith('# Plain\n'));
    });
  });

  group('MarkdownLinkParser', () {
    test('parses wiki aliases/headings and local markdown links', () {
      final links = MarkdownLinkParser.parse('''
[[API Authentication|Authentication Guide]]
[[customers/create-customer#Examples]]
[Runbook](../runbooks/customer.md)
![Diagram](images/flow.png)
[Web](https://example.test)
''');

      expect(links, hasLength(5));
      expect(links[0].target, 'API Authentication');
      expect(links[0].displayText, 'Authentication Guide');
      expect(links[1].target, 'customers/create-customer');
      expect(links[1].heading, 'Examples');
      expect(links[2].external, isFalse);
      expect(links[3].kind, KnowledgeReferenceKind.image);
      expect(links[4].external, isTrue);
    });

    test('ignores links inside fenced and inline code', () {
      final links = MarkdownLinkParser.parse('''
`[[inline]]`
```markdown
[[fenced]]
[fenced](missing.md)
```
[[real]]
''');

      expect(links.map((link) => link.target), ['real']);
    });
  });

  group('KnowledgeGraphBuilder', () {
    test('resolves wiki and relative links into outgoing and backlinks', () {
      final auth = _document(
        path: 'guides/auth.md',
        title: 'API Authentication',
        body: 'See [[customers/create-customer]].',
      );
      final customer = _document(
        path: 'guides/customers/create-customer.md',
        title: 'Create Customer',
        stableId: 'api.create-customer',
        body: '[Auth](../auth.md)',
      );

      final graph = KnowledgeGraphBuilder.build([auth, customer]);

      expect(graph.outgoing[auth.id], contains(customer.id));
      expect(graph.outgoing[customer.id], contains(auth.id));
      expect(graph.backlinks[auth.id], contains(customer.id));
      expect(
        graph.issues
            .where((issue) => issue.kind == KnowledgeIssueKind.brokenLink),
        isEmpty,
      );
    });

    test('reports duplicates, broken targets and orphans deterministically',
        () {
      final first = _document(
        path: 'one.md',
        title: 'Duplicate',
        stableId: 'same.id',
        body: '[[Missing]]',
      );
      final second = _document(
        path: 'folder/two.md',
        title: 'Duplicate',
        stableId: 'same.id',
      );

      final graph = KnowledgeGraphBuilder.build([first, second]);

      expect(
        graph.issues.where(
          (issue) => issue.kind == KnowledgeIssueKind.duplicateTitle,
        ),
        hasLength(2),
      );
      expect(
        graph.issues.where(
          (issue) => issue.kind == KnowledgeIssueKind.duplicateStableId,
        ),
        hasLength(2),
      );
      expect(
        graph.issues
            .where((issue) => issue.kind == KnowledgeIssueKind.brokenLink),
        hasLength(1),
      );
      expect(
        graph.issues.where(
          (issue) => issue.kind == KnowledgeIssueKind.orphanDocument,
        ),
        hasLength(2),
      );
    });
  });
}

KnowledgeDocument _document({
  required String path,
  required String title,
  String body = '',
  String? stableId,
}) {
  final source = '''---
type: Concept
title: $title
${stableId == null ? '' : 'stable_id: $stableId\n'}---
$body''';
  return KnowledgeDocument(
    workspaceId: 'workspace-1',
    relativePath: path,
    title: title,
    type: 'Concept',
    stableId: stableId,
    description: '',
    tags: const [],
    frontmatter: FrontmatterDocument.parse(source),
    outgoingReferences: MarkdownLinkParser.parse(body),
    fingerprint: path,
    modifiedAt: DateTime.utc(2026, 7, 22),
    sizeBytes: source.length,
  );
}
