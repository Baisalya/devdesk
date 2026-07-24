import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api_tester/provider/api_workspace_provider.dart';
import '../../../core/widgets/app_tool_app_bar.dart';
import '../data/local_openapi_service.dart';
import '../domain/openapi_models.dart';

class OpenApiPage extends ConsumerStatefulWidget {
  const OpenApiPage({super.key});

  @override
  ConsumerState<OpenApiPage> createState() => _OpenApiPageState();
}

class _OpenApiPageState extends ConsumerState<OpenApiPage> {
  static const _example = '''openapi: 3.0.3
info:
  title: Sample API
  version: 1.0.0
servers:
  - url: https://api.example.com
paths:
  /health:
    get:
      operationId: getHealth
      summary: Check service health
      responses:
        '200':
          description: Healthy
''';

  final _controller = TextEditingController(text: _example);
  final _service = const LocalOpenApiService();
  OpenApiDocument? _document;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    try {
      final parsed = _service.parse(_controller.text);
      setState(() {
        _document = parsed;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _document = null;
        _error = error.toString();
      });
    }
  }

  Future<void> _importCollection() async {
    final document = _document;
    if (document == null) return;
    await ref
        .read(apiWorkspaceProvider.notifier)
        .importCollection(_service.generateCollection(document));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${document.title} imported into API Workspaces.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return Scaffold(
      appBar: AppToolAppBar(
        route: '/openapi',
        actions: [
          TextButton.icon(
            onPressed: document == null ? null : _importCollection,
            icon: const Icon(Icons.api),
            label: const Text('Create collection'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final editor = _Editor(
            controller: _controller,
            error: _error,
            onParse: _parse,
          );
          final review = _Review(document: document);
          if (constraints.maxWidth < 760) {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [SizedBox(height: 430, child: editor), review],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: editor,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: review,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final VoidCallback onParse;

  const _Editor({
    required this.controller,
    required this.error,
    required this.onParse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste OpenAPI 3.x JSON or YAML',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onParse,
          icon: const Icon(Icons.fact_check),
          label: const Text('Validate and inspect'),
        ),
      ],
    );
  }
}

class _Review extends StatelessWidget {
  final OpenApiDocument? document;

  const _Review({required this.document});

  @override
  Widget build(BuildContext context) {
    final value = document;
    if (value == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Validate a specification to inspect operations and schemas.',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(value.title, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          'OpenAPI ${value.version} • ${value.operations.length} operations • '
          '${value.schemas.length} schemas',
        ),
        const SizedBox(height: 16),
        Text('Operations', style: Theme.of(context).textTheme.titleMedium),
        for (final operation in value.operations)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(operation.method[0])),
            title: Text('${operation.method} ${operation.path}'),
            subtitle: Text(
              '${operation.summary}\n${operation.sourcePointer}',
            ),
            isThreeLine: true,
          ),
        if (value.schemas.isNotEmpty) ...[
          const Divider(),
          Text('Schemas', style: Theme.of(context).textTheme.titleMedium),
          for (final schema in value.schemas.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(schema.name),
              subtitle: Text(
                '${schema.type} • ${schema.propertyTypes.length} properties',
              ),
            ),
        ],
      ],
    );
  }
}
