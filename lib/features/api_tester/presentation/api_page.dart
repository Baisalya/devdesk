import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/files/external_file.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../models/api_history_entry.dart';
import '../models/api_request.dart';
import '../../diff_checker/presentation/diff_page.dart';
import '../../diff_checker/provider/diff_provider.dart';
import '../../diff_checker/models/diff_models.dart';
import '../models/api_response.dart';
import '../provider/api_provider.dart';
import '../utils/api_collection_utils.dart';
import '../utils/api_code_snippets.dart';

/// A mini Postman-like API tester.
class ApiPage extends ConsumerStatefulWidget {
  final ExternalFileDocument? initialDocument;

  const ApiPage({super.key, this.initialDocument});

  @override
  ConsumerState<ApiPage> createState() => _ApiPageState();
}

class _ApiPageState extends ConsumerState<ApiPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(urlProvider));
    _bodyController = TextEditingController(text: ref.read(bodyProvider));
    _urlController.addListener(() {
      ref.read(urlProvider.notifier).state = _urlController.text;
    });
    _bodyController.addListener(() {
      ref.read(bodyProvider.notifier).state = _bodyController.text;
    });
    if (widget.initialDocument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _importCollectionFromText(
          widget.initialDocument!.content,
          widget.initialDocument!.name,
        );
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(urlProvider, (_, next) {
      _setControllerText(_urlController, next);
    });
    ref.listen<String>(bodyProvider, (_, next) {
      _setControllerText(_bodyController, next);
    });

    final method = ref.watch(methodProvider);
    final response = ref.watch(apiResponseProvider);
    final lastRequest = ref.watch(lastApiRequestProvider);
    final loading = ref.watch(apiLoadingProvider);
    final error = ref.watch(apiErrorProvider);
    final saveSensitiveHeaders = ref.watch(saveSensitiveHeadersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Tester'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import collection',
            onPressed: _importCollectionFromPicker,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export collection',
            onPressed: _exportCollection,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => _showHistory(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final requestPanel = _RequestPanel(
            method: method,
            urlController: _urlController,
            bodyController: _bodyController,
            loading: loading,
            error: error,
            saveSensitiveHeaders: saveSensitiveHeaders,
            onMethodChanged: (value) {
              ref.read(methodProvider.notifier).state = value;
            },
            onSend: _send,
            onSetSaveSensitiveHeaders: _setSaveSensitiveHeaders,
          );
          final responsePanel = _ResponseSection(
            response: response,
            request: lastRequest,
            loading: loading,
            error: error,
          );

          return Padding(
            padding: AppSpacing.page(context),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 9, child: requestPanel),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 11, child: responsePanel),
                    ],
                  )
                : SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      children: [
                        SizedBox(height: 680, child: requestPanel),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(height: 620, child: responsePanel),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _setSaveSensitiveHeaders(bool value) async {
    if (value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Save sensitive headers?'),
            content: const Text(
              'Authorization, bearer tokens, API keys and similar headers may '
              'contain secrets. Save them only on a device you trust.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save headers'),
              ),
            ],
          );
        },
      );
      if (confirm != true) return;
    }
    await ref.read(saveSensitiveHeadersProvider.notifier).setValue(value);
  }

  Future<void> _send() async {
    final hadSensitiveHeaders =
        ref.read(headersProvider.notifier).toMap().keys.any(
              ApiRequest.isSensitiveHeader,
            );
    final saveSensitive = ref.read(saveSensitiveHeadersProvider);
    try {
      await sendRequest(ref);
      ref.read(apiErrorProvider.notifier).state = null;
      if (hadSensitiveHeaders && !saveSensitive && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sensitive headers were not saved to history.'),
          ),
        );
      }
    } on Failure catch (e) {
      ref.read(apiErrorProvider.notifier).state = e.message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      final message = e.toString();
      ref.read(apiErrorProvider.notifier).state = message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _importCollectionFromPicker() async {
    try {
      final document = await ExternalFileService.pickDeveloperFile();
      if (document == null) return;
      if (document.kind != DevFileKind.apiCollection &&
          document.kind != DevFileKind.json) {
        _showSnack('Select a DevDesk API collection JSON file.');
        return;
      }
      await _importCollectionFromText(document.content, document.name);
    } on ExternalFileException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to import collection: $e');
    }
  }

  Future<void> _importCollectionFromText(
      String content, String sourceName) async {
    try {
      final document = ApiCollectionUtils.decodeCollectionText(content);
      final preview = ApiCollectionUtils.preview(document);
      final includeSecrets =
          await _chooseCollectionImportMode(sourceName, preview);
      if (includeSecrets == null) return;
      final requests = ApiCollectionUtils.importRequests(
        document,
        includeSecrets: includeSecrets,
      );
      for (final request in requests) {
        await saveRequestToHistory(
          request,
          saveSensitiveHeaders: includeSecrets,
        );
      }
      ref.invalidate(apiHistoryProvider);
      if (requests.isNotEmpty) {
        _loadRequest(requests.first);
      }
      _showSnack('Imported ${requests.length} API request(s).');
    } on FormatException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to import collection: $e');
    }
  }

  Future<bool?> _chooseCollectionImportMode(
    String sourceName,
    ApiCollectionPreview preview,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final content = preview.hasSensitiveHeaders
            ? 'Import ${preview.requestCount} request(s) from "$sourceName"? Sensitive headers were found.'
            : 'Import ${preview.requestCount} request(s) from "$sourceName"?';
        return AlertDialog(
          title: const Text('Import API collection'),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (preview.hasSensitiveHeaders)
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Import without secrets'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(
                preview.hasSensitiveHeaders ? true : false,
              ),
              child: Text(
                preview.hasSensitiveHeaders ? 'Import with secrets' : 'Import',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportCollection() async {
    final history = await ref.read(apiHistoryProvider.future);
    if (!mounted) return;
    if (history.isEmpty) {
      _showSnack('No API history to export.');
      return;
    }
    final includeSecrets = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export API collection'),
          content: const Text(
            'Exports saved requests. Sensitive headers are excluded by default.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Exclude secrets'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Include secrets'),
            ),
          ],
        );
      },
    );
    if (includeSecrets == null) return;
    final document = ApiCollectionUtils.exportCollection(
      history.map((entry) => entry.request),
      includeSecrets: includeSecrets,
    );
    final path = await ExternalFileService.saveTextAs(
      suggestedName: 'devdesk-api-collection.json',
      content: const JsonEncoder.withIndent('  ').convert(document),
      allowedExtensions: const ['json'],
      dialogTitle: 'Export API collection',
    );
    if (path != null) {
      _showSnack('API collection exported.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _loadRequest(ApiRequest request) {
    loadRequestIntoProviders(ref, request);
    _setControllerText(_urlController, request.url);
    _setControllerText(_bodyController, request.body ?? '');
  }

  void _showHistory(BuildContext context) {
    final historyView = Consumer(
      builder: (context, ref, _) {
        final history = ref.watch(apiHistoryProvider);
        return history.when(
          loading: () => const AppLoadingState(label: 'Loading history...'),
          error: (err, stack) => AppErrorState(message: err.toString()),
          data: (items) => _HistorySheet(
            items: items,
            onDuplicate: (request) {
              _loadRequest(request);
              Navigator.of(context).pop();
            },
            onDelete: (key) async {
              await deleteApiHistoryEntry(key);
              ref.invalidate(apiHistoryProvider);
            },
            onClear: () => _confirmClearHistory(context, ref),
          ),
        );
      },
    );
    if (MediaQuery.sizeOf(context).width >= AppBreakpoints.medium) {
      showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            child: SizedBox(
              width: 760,
              height: 560,
              child: historyView,
            ),
          );
        },
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: historyView,
        );
      },
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear history?'),
          content: const Text('This deletes all saved API requests.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await clearApiHistory();
      ref.invalidate(apiHistoryProvider);
    }
  }
}

class _RequestPanel extends StatelessWidget {
  final String method;
  final TextEditingController urlController;
  final TextEditingController bodyController;
  final bool loading;
  final String? error;
  final bool saveSensitiveHeaders;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onSend;
  final ValueChanged<bool> onSetSaveSensitiveHeaders;

  const _RequestPanel({
    required this.method,
    required this.urlController,
    required this.bodyController,
    required this.loading,
    required this.error,
    required this.saveSensitiveHeaders,
    required this.onMethodChanged,
    required this.onSend,
    required this.onSetSaveSensitiveHeaders,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Request',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    AppBadge(
                      label: method,
                      icon: Icons.bolt,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _MethodUrlRow(
                  method: method,
                  urlController: urlController,
                  onMethodChanged: onMethodChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : onSend,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(loading ? 'Sending...' : 'Send'),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppErrorState(message: error!, title: 'Request failed'),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Params'),
                      Tab(text: 'Headers'),
                      Tab(text: 'Body'),
                      Tab(text: 'Auth / Environments'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: _KeyValueSection(
                            title: 'Query Parameters',
                            notifierProvider: queryParamsProvider,
                            presets: const {},
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: _KeyValueSection(
                            title: 'Headers',
                            notifierProvider: headersProvider,
                            presets: const {
                              'Content-Type JSON': MapEntry(
                                'Content-Type',
                                'application/json',
                              ),
                              'Bearer Token': MapEntry(
                                'Authorization',
                                'Bearer ',
                              ),
                              'Basic Auth': MapEntry(
                                'Authorization',
                                'Basic ',
                              ),
                            },
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: method == 'GET'
                              ? const AppEmptyState(
                                  icon: Icons.http,
                                  title: 'GET request body disabled',
                                  message:
                                      'Switch to POST, PUT, PATCH, or DELETE to send a body.',
                                )
                              : _BodyEditor(controller: bodyController),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppCard(
                                filled: false,
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Save auth/sensitive headers in history',
                                  ),
                                  subtitle: const Text(
                                    'Off by default. Authorization, token, API key and secret headers are stripped from saved history.',
                                  ),
                                  value: saveSensitiveHeaders,
                                  onChanged: onSetSaveSensitiveHeaders,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const _EnvironmentSection(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodUrlRow extends StatelessWidget {
  final String method;
  final TextEditingController urlController;
  final ValueChanged<String> onMethodChanged;

  const _MethodUrlRow({
    required this.method,
    required this.urlController,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dropdown = DropdownButtonFormField<String>(
          key: ValueKey('method-$method'),
          initialValue: method,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Method',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (value != null) onMethodChanged(value);
          },
          items: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
              .map((method) => DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  ))
              .toList(),
        );
        final urlField = TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://api.example.com/users',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        );
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              dropdown,
              const SizedBox(height: 8),
              urlField,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 180, child: dropdown),
            const SizedBox(width: 8),
            Expanded(child: urlField),
          ],
        );
      },
    );
  }
}

class _EnvironmentSection extends ConsumerWidget {
  const _EnvironmentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(apiEnvironmentsProvider);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Environments'),
      subtitle: Text('Selected: ${state.selectedName}'),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('environment-${state.selectedName}'),
          initialValue: state.selectedName,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Active environment',
            border: OutlineInputBorder(),
          ),
          items: state.environments.keys
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(apiEnvironmentsProvider.notifier).select(value);
            }
          },
        ),
        const SizedBox(height: 8),
        for (final env in state.environments.values) ...[
          TextFormField(
            key: ValueKey('env-${env.name}-${env.baseUrl}'),
            initialValue: env.baseUrl,
            decoration: InputDecoration(
              labelText: '${env.name} base URL',
              hintText: 'https://api.example.com',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            onChanged: (value) {
              ref
                  .read(apiEnvironmentsProvider.notifier)
                  .updateBaseUrl(env.name, value);
            },
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: state.selected.baseUrl.isEmpty
                ? null
                : () {
                    ref.read(urlProvider.notifier).state = '{{baseUrl}}';
                  },
            icon: const Icon(Icons.input),
            label: const Text('Insert {{baseUrl}}'),
          ),
        ),
      ],
    );
  }
}

class _KeyValueSection extends ConsumerStatefulWidget {
  final String title;
  final StateNotifierProvider<KeyValueNotifier, List<MapEntry<String, String>>>
      notifierProvider;
  final Map<String, MapEntry<String, String>> presets;

  const _KeyValueSection({
    required this.title,
    required this.notifierProvider,
    required this.presets,
  });

  @override
  ConsumerState<_KeyValueSection> createState() => _KeyValueSectionState();
}

class _KeyValueSectionState extends ConsumerState<_KeyValueSection> {
  final _keyControllers = <TextEditingController>[];
  final _valueControllers = <TextEditingController>[];

  @override
  void dispose() {
    for (final controller in [..._keyControllers, ..._valueControllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairs = ref.watch(widget.notifierProvider);
    _syncControllers(pairs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (widget.presets.isNotEmpty)
              PopupMenuButton<MapEntry<String, String>>(
                icon: const Icon(Icons.add_box),
                tooltip: 'Add preset',
                onSelected: (entry) {
                  ref.read(widget.notifierProvider.notifier).add(entry);
                },
                itemBuilder: (context) {
                  return widget.presets.entries
                      .map(
                        (entry) => PopupMenuItem(
                          value: entry.value,
                          child: Text(entry.key),
                        ),
                      )
                      .toList();
                },
              ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add new',
              onPressed: () => ref.read(widget.notifierProvider.notifier).add(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (pairs.isEmpty)
          Text(
            'Add a row when this request needs custom values.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        for (var i = 0; i < pairs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyField = TextField(
                  controller: _keyControllers[i],
                  decoration: const InputDecoration(
                    hintText: 'Key',
                    isDense: true,
                  ),
                  onChanged: (value) => ref
                      .read(widget.notifierProvider.notifier)
                      .updateKey(i, value),
                );
                final valueField = TextField(
                  controller: _valueControllers[i],
                  decoration: const InputDecoration(
                    hintText: 'Value',
                    isDense: true,
                  ),
                  onChanged: (value) => ref
                      .read(widget.notifierProvider.notifier)
                      .updateValue(i, value),
                );
                final remove = IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove row',
                  onPressed: () {
                    ref.read(widget.notifierProvider.notifier).removeAt(i);
                  },
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      keyField,
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(child: valueField),
                          remove,
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: keyField),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(flex: 3, child: valueField),
                    remove,
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  void _syncControllers(List<MapEntry<String, String>> pairs) {
    while (_keyControllers.length < pairs.length) {
      _keyControllers.add(TextEditingController());
      _valueControllers.add(TextEditingController());
    }
    while (_keyControllers.length > pairs.length) {
      _keyControllers.removeLast().dispose();
      _valueControllers.removeLast().dispose();
    }
    for (var i = 0; i < pairs.length; i++) {
      _setText(_keyControllers[i], pairs[i].key);
      _setText(_valueControllers[i], pairs[i].value);
    }
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }
}

class _BodyEditor extends ConsumerWidget {
  final TextEditingController controller;

  const _BodyEditor({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Body',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                try {
                  final pretty = formatRequestBody(controller.text);
                  controller.text = pretty;
                  ref.read(bodyProvider.notifier).state = pretty;
                } on Failure catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Format JSON'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          style: AppTypography.mono(context),
          decoration: InputDecoration(
            hintText: '{ "key": "value" }',
            fillColor: AppColors.codeBackground(context),
          ),
          minLines: 5,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
        ),
      ],
    );
  }
}

class _HistorySheet extends StatelessWidget {
  final List<ApiHistoryEntry> items;
  final ValueChanged<ApiRequest> onDuplicate;
  final ValueChanged<dynamic> onDelete;
  final VoidCallback onClear;

  const _HistorySheet({
    required this.items,
    required this.onDuplicate,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('API History'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear history',
            onPressed: onClear,
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No history yet'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    final request = entry.request;
                    return ListTile(
                      title: Text('${request.method} ${request.url}'),
                      subtitle: Text(request.timestamp.toLocal().toString()),
                      onTap: () => onDuplicate(request),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Duplicate request',
                            onPressed: () => onDuplicate(request),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete request',
                            onPressed: () => onDelete(entry.key),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ResponseSection extends ConsumerWidget {
  final ApiResponse? response;
  final ApiRequest? request;
  final bool loading;
  final String? error;

  const _ResponseSection({
    required this.response,
    required this.request,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentResponse = response;
    if (currentResponse == null && loading) {
      return const AppCard(
        child: AppLoadingState(label: 'Sending request...'),
      );
    }
    if (currentResponse == null) {
      return AppCard(
        child: error == null
            ? const AppEmptyState(
                icon: Icons.receipt_long,
                title: 'Response will appear here',
                message:
                    'Send a request to inspect status, headers, body and snippets.',
              )
            : AppErrorState(
                title: 'No response',
                message: error!,
              ),
      );
    }

    final pretty = _prettyBody(currentResponse.body);
    final raw = currentResponse.body;
    final sizeLabel = _formatBytes(utf8.encode(currentResponse.body).length);
    final statusColor = _statusColor(currentResponse.statusCode);
    final statusBackground =
        _statusBackground(context, currentResponse.statusCode);

    return AppCard(
      padding: EdgeInsets.zero,
      child: DefaultTabController(
        length: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(
                        label: 'Status ${currentResponse.statusCode}',
                        icon: Icons.circle,
                        color: statusColor,
                        backgroundColor: statusBackground,
                      ),
                      AppBadge(
                        label: '${currentResponse.duration.inMilliseconds} ms',
                        icon: Icons.timer,
                      ),
                      AppBadge(
                        label: sizeLabel,
                        icon: Icons.storage,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.compare_arrows),
                        tooltip: 'Compare with...',
                        onPressed: () {
                          ref.read(diffRightProvider.notifier).state =
                              currentResponse.body;
                          ref.read(diffSourceRightProvider.notifier).state =
                              DiffSource.api;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DiffPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Pretty'),
                Tab(text: 'Raw'),
                Tab(text: 'Headers'),
                Tab(text: 'Timeline / Info'),
                Tab(text: 'Code Snippets'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ResponseBodyPanel(body: pretty),
                  _ResponseBodyPanel(body: raw),
                  _HeadersPanel(headers: currentResponse.headers),
                  _InfoPanel(response: currentResponse),
                  _CodeSnippetsPanel(request: request),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyBody(String body) {
    try {
      return JsonUtils.prettyPrint(body);
    } catch (_) {
      return body;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Color _statusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return AppColors.success;
    if (statusCode >= 300 && statusCode < 400) return AppColors.info;
    if (statusCode >= 400 && statusCode < 500) return AppColors.warning;
    return AppColors.destructive;
  }

  Color _statusBackground(BuildContext context, int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return AppColors.successContainer(context);
    }
    if (statusCode >= 300 && statusCode < 400) {
      return AppColors.infoContainer(context);
    }
    if (statusCode >= 400 && statusCode < 500) {
      return AppColors.warningContainer(context);
    }
    return Theme.of(context).colorScheme.errorContainer;
  }
}

class _ResponseBodyPanel extends StatelessWidget {
  final String body;

  const _ResponseBodyPanel({required this.body});

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) {
      return const AppEmptyState(
        icon: Icons.subject,
        title: 'Empty response body',
        message: 'The server returned no response content.',
      );
    }
    return Container(
      color: AppColors.codeBackground(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: SelectableText(
            body,
            style: AppTypography.mono(context),
          ),
        ),
      ),
    );
  }
}

class _HeadersPanel extends StatelessWidget {
  final Map<String, String> headers;

  const _HeadersPanel({required this.headers});

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.list_alt,
        title: 'No response headers',
        message: 'Headers will appear here when the server returns them.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: headers.length,
      separatorBuilder: (_, __) => const Divider(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final entry = headers.entries.elementAt(index);
        return SelectableText(
          '${entry.key}: ${entry.value}',
          style: AppTypography.mono(context),
        );
      },
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final ApiResponse response;

  const _InfoPanel({required this.response});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _InfoRow(label: 'Method', value: response.method),
        _InfoRow(label: 'Final URL', value: response.url),
        _InfoRow(label: 'Status', value: response.statusCode.toString()),
        _InfoRow(
          label: 'Response time',
          value: '${response.duration.inMilliseconds} ms',
        ),
        _InfoRow(label: 'Header count', value: '${response.headers.length}'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _CodeSnippetsPanel extends StatelessWidget {
  final ApiRequest? request;

  const _CodeSnippetsPanel({required this.request});

  @override
  Widget build(BuildContext context) {
    final currentRequest = request;
    if (currentRequest == null) {
      return const AppEmptyState(
        icon: Icons.code,
        title: 'No request snippet yet',
        message: 'Send a request to generate cURL, Dart, and fetch examples.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SnippetTile(
          title: 'cURL',
          snippet: ApiCodeSnippets.curl(currentRequest),
        ),
        _SnippetTile(
          title: 'Dart http',
          snippet: ApiCodeSnippets.dartHttp(currentRequest),
        ),
        _SnippetTile(
          title: 'JavaScript fetch',
          snippet: ApiCodeSnippets.javascriptFetch(currentRequest),
        ),
      ],
    );
  }
}

class _SnippetTile extends StatelessWidget {
  final String title;
  final String snippet;

  const _SnippetTile({required this.title, required this.snippet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        filled: false,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy snippet',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: snippet));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$title snippet copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              color: AppColors.codeBackground(context),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  snippet,
                  style: AppTypography.mono(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
