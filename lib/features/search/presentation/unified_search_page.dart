import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_tool_app_bar.dart';
import '../../api_tester/models/api_workspace_models.dart';
import '../../api_tester/provider/api_workspace_provider.dart';
import '../../workspaces/provider/workspace_provider.dart';
import '../domain/unified_search.dart';

class UnifiedSearchPage extends ConsumerStatefulWidget {
  const UnifiedSearchPage({super.key});

  @override
  ConsumerState<UnifiedSearchPage> createState() => _UnifiedSearchPageState();
}

class _UnifiedSearchPageState extends ConsumerState<UnifiedSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = _records();
    final hits = UnifiedSearchIndex(records).search(_query);
    return Scaffold(
      appBar: const AppToolAppBar(route: '/search'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SearchBar(
                  controller: _controller,
                  autoFocus: true,
                  hintText: 'Search workspaces, collections and requests',
                  leading: const Icon(Icons.search),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: _query.trim().isEmpty
                    ? const Center(
                        child: Text('Type to search local metadata.'))
                    : ListView.builder(
                        itemCount: hits.length,
                        itemBuilder: (context, index) {
                          final hit = hits[index].record;
                          return ListTile(
                            leading: Icon(_icon(hit.kind)),
                            title: Text(hit.title),
                            subtitle: Text(hit.subtitle),
                            trailing: Text(hit.kind.name),
                            onTap: () => _open(hit),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<SearchRecord> _records() {
    final records = <SearchRecord>[];
    for (final workspace in ref.watch(workspaceRegistryProvider).workspaces) {
      records.add(SearchRecord(
        id: workspace.id,
        kind: SearchEntityKind.workspace,
        title: workspace.name,
        subtitle: workspace.root.displayPath,
        searchableText:
            '${workspace.description} ${workspace.kinds.map((e) => e.name).join(' ')}',
        reference: 'workspace:${workspace.id}',
      ));
    }
    for (final workspace in ref.watch(apiWorkspaceProvider).workspaces) {
      for (final collection in workspace.collections) {
        records.add(SearchRecord(
          id: collection.id,
          kind: SearchEntityKind.apiCollection,
          title: collection.name,
          subtitle: workspace.name,
          searchableText: collection.description,
          reference: 'api-collection:${collection.id}',
        ));
        for (final request in <ApiRequestItem>[
          ...collection.requests,
          for (final folder in collection.folders) ...folder.requests,
        ]) {
          records.add(SearchRecord(
            id: request.id,
            kind: SearchEntityKind.apiRequest,
            title: request.name,
            subtitle: '${request.method} ${request.url}',
            searchableText: '${request.description} ${request.tags.join(' ')}',
            reference: 'api-request:${request.id}',
          ));
        }
      }
    }
    return records;
  }

  void _open(SearchRecord record) {
    switch (record.kind) {
      case SearchEntityKind.workspace:
        Navigator.pushNamed(context, '/knowledge', arguments: record.id);
        break;
      case SearchEntityKind.apiCollection:
      case SearchEntityKind.apiRequest:
        Navigator.pushNamed(context, '/api');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(record.reference)),
        );
    }
  }

  static IconData _icon(SearchEntityKind kind) {
    return switch (kind) {
      SearchEntityKind.workspace => Icons.workspaces_outline,
      SearchEntityKind.markdown => Icons.description_outlined,
      SearchEntityKind.apiCollection => Icons.folder_outlined,
      SearchEntityKind.apiRequest => Icons.api,
      SearchEntityKind.openApiOperation => Icons.schema,
      SearchEntityKind.gitFile => Icons.difference,
    };
  }
}
