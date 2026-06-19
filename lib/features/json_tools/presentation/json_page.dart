import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/utils/json_utils.dart';
import '../provider/json_provider.dart';

/// Page for viewing, validating and formatting JSON.
class JsonPage extends ConsumerStatefulWidget {
  final ExternalFileDocument? initialDocument;

  const JsonPage({super.key, this.initialDocument});

  @override
  ConsumerState<JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends ConsumerState<JsonPage> {
  late final TextEditingController _inputController;
  ExternalFileDocument? _externalDocument;

  @override
  void initState() {
    super.initState();
    _externalDocument = widget.initialDocument;
    final String initialText =
        widget.initialDocument?.content ?? ref.read(jsonInputProvider);
    _inputController = TextEditingController(text: initialText);
    _inputController.addListener(() {
      ref.read(jsonInputProvider.notifier).state = _inputController.text;
    });
    if (widget.initialDocument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(jsonInputProvider.notifier).state = initialText;
        formatJson(ref);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _clear() {
    _inputController.clear();
    ref.read(jsonOutputProvider.notifier).state = null;
    setState(() {
      _externalDocument = null;
    });
  }

  Future<void> _saveJson({required bool minified}) async {
    try {
      final input = _inputController.text;
      final content =
          minified ? JsonUtils.minify(input) : JsonUtils.prettyPrint(input);
      final path = await ExternalFileService.saveTextAs(
        suggestedName: _externalDocument?.name ?? 'formatted.json',
        content: content,
        allowedExtensions: const ['json'],
        dialogTitle: minified ? 'Save minified JSON' : 'Save formatted JSON',
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(minified ? 'Minified JSON saved' : 'Formatted JSON saved'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final output = ref.watch(jsonOutputProvider);
    dynamic treeData;
    if (output != null && !output.startsWith('Invalid')) {
      try {
        treeData = JsonUtils.parseJson(output);
      } catch (_) {
        treeData = null;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(_externalDocument?.name ?? 'JSON Tools')),
      body: Column(
        children: [
          if (_externalDocument != null)
            _JsonSourceBanner(document: _externalDocument!),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () => formatJson(ref),
                  child: const Text('Format'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => minifyJson(ref),
                  child: const Text('Minify'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: output != null
                      ? () async {
                          await Clipboard.setData(
                            ClipboardData(text: output),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _saveJson(minified: false),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save formatted'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _saveJson(minified: true),
                  icon: const Icon(Icons.compress),
                  label: const Text('Save minified'),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final input = _InputEditor(controller: _inputController);
                final outputView =
                    _OutputView(output: output, treeData: treeData);
                return isWide
                    ? Row(
                        children: [
                          Expanded(child: input),
                          Expanded(child: outputView),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: input),
                          Expanded(child: outputView),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonSourceBanner extends StatelessWidget {
  final ExternalFileDocument document;

  const _JsonSourceBanner({required this.document});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.data_object, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'External JSON: ${document.sourceLabel}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputEditor extends StatelessWidget {
  final TextEditingController controller;

  const _InputEditor({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: controller,
        expands: true,
        minLines: null,
        maxLines: null,
        decoration: const InputDecoration(
          hintText: 'Paste JSON here...',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}

class _OutputView extends StatelessWidget {
  final String? output;
  final dynamic treeData;

  const _OutputView({required this.output, required this.treeData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: output == null
          ? const Center(child: Text('Output will appear here'))
          : output!.startsWith('Invalid')
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    output!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [Tab(text: 'Text'), Tab(text: 'Tree')],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(8),
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: SelectableText(output!),
                              ),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(8),
                              child: treeData == null
                                  ? const Text('Invalid JSON')
                                  : JsonTreeView(data: treeData),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// A widget that recursively displays a JSON object as expandable tiles. It
/// supports Maps and Lists. Primitive values are shown as text.
class JsonTreeView extends StatelessWidget {
  final dynamic data;
  final String? keyName;

  const JsonTreeView({super.key, required this.data, this.keyName});

  @override
  Widget build(BuildContext context) {
    if (data is Map) {
      final map = data as Map;
      if (map.isEmpty) return _buildLeaf(keyName ?? '{}', '{}');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: map.entries.map((entry) {
          return _buildNode(entry.key.toString(), entry.value);
        }).toList(),
      );
    }
    if (data is List) {
      final list = data as List;
      if (list.isEmpty) return _buildLeaf(keyName ?? '[]', '[]');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < list.length; i++) _buildNode('[$i]', list[i]),
        ],
      );
    }
    return _buildLeaf(keyName ?? 'value', data);
  }

  Widget _buildNode(String key, dynamic value) {
    if (value is Map || value is List) {
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(key),
        children: [JsonTreeView(data: value)],
      );
    }
    return _buildLeaf(key, value);
  }

  Widget _buildLeaf(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$key: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }
}
