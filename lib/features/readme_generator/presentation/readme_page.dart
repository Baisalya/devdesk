import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/files/external_file_service.dart';
import '../../markdown/provider/markdown_provider.dart';

/// Page for generating README.md files by filling out a form.
class ReadmeGeneratorPage extends StatefulWidget {
  const ReadmeGeneratorPage({super.key});

  @override
  State<ReadmeGeneratorPage> createState() => _ReadmeGeneratorPageState();
}

class _ReadmeGeneratorPageState extends State<ReadmeGeneratorPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TabController _tabController;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _featuresController = TextEditingController();
  final _installController = TextEditingController();
  final _usageController = TextEditingController();
  final _screenshotsController = TextEditingController();
  final _licenseController = TextEditingController(text: 'MIT');
  final _generatedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generatedController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _featuresController.dispose();
    _installController.dispose();
    _usageController.dispose();
    _screenshotsController.dispose();
    _licenseController.dispose();
    _generatedController.dispose();
    super.dispose();
  }

  String get _generated => _generatedController.text;

  void _generateReadme() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final features = _featuresController.text.trim();
    final install = _installController.text.trim();
    final usage = _usageController.text.trim();
    final screenshots = _screenshotsController.text.trim();
    final license = _licenseController.text.trim();
    final buffer = StringBuffer()
      ..writeln('# $name')
      ..writeln();

    if (description.isNotEmpty) {
      buffer
        ..writeln(description)
        ..writeln();
    }
    if (features.isNotEmpty) {
      buffer
        ..writeln('## Features')
        ..writeln();
      for (final line in features.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) buffer.writeln('- $trimmed');
      }
      buffer.writeln();
    }
    if (install.isNotEmpty) {
      buffer
        ..writeln('## Installation')
        ..writeln()
        ..writeln(install)
        ..writeln();
    }
    if (usage.isNotEmpty) {
      buffer
        ..writeln('## Usage')
        ..writeln()
        ..writeln(usage)
        ..writeln();
    }
    if (screenshots.isNotEmpty) {
      buffer
        ..writeln('## Screenshots')
        ..writeln()
        ..writeln(screenshots)
        ..writeln();
    }
    if (license.isNotEmpty) {
      buffer
        ..writeln('## License')
        ..writeln()
        ..writeln('This project is licensed under the $license license.')
        ..writeln();
    }
    _generatedController.text = buffer.toString();
    _tabController.index = 1;
  }

  Future<void> _copyToClipboard() async {
    if (_generated.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _generated));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('README copied to clipboard')),
    );
  }

  Future<void> _saveAsMarkdown() async {
    if (_generated.isEmpty) return;
    final baseName = _nameController.text.trim().isEmpty
        ? 'README.md'
        : '${_nameController.text.trim()}-README.md';
    try {
      await saveMarkdownFile(baseName, _generated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${normalizeMarkdownFileName(baseName)}')),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.toString())),
      );
    }
  }

  Future<void> _exportReadme() async {
    if (_generated.isEmpty) return;
    final path = await ExternalFileService.saveTextAs(
      suggestedName: 'README.md',
      content: _generated,
      allowedExtensions: const ['md'],
      dialogTitle: 'Export README.md',
    );
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('README exported')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('README Generator'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Form'), Tab(text: 'Output')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(
                    'Project Name',
                    _nameController,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Project name is required';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    'Description',
                    _descriptionController,
                    maxLines: 3,
                  ),
                  _buildField(
                    'Features (one per line)',
                    _featuresController,
                    maxLines: 4,
                  ),
                  _buildField('Installation', _installController, maxLines: 3),
                  _buildField('Usage', _usageController, maxLines: 3),
                  _buildField(
                    'Screenshots (Markdown)',
                    _screenshotsController,
                    maxLines: 3,
                  ),
                  _buildField('License', _licenseController),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generateReadme,
                      child: const Text('Generate README'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _generated.isEmpty
                ? const Center(
                    child: Text('Fill out the form and generate a README.'),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final editor = TextField(
                              controller: _generatedController,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              decoration: const InputDecoration(
                                labelText: 'Editable README.md',
                                border: OutlineInputBorder(),
                              ),
                            );
                            final preview = Markdown(data: _generated);
                            if (constraints.maxWidth >= 840) {
                              return Row(
                                children: [
                                  Expanded(child: editor),
                                  const VerticalDivider(width: 16),
                                  Expanded(child: preview),
                                ],
                              );
                            }
                            return DefaultTabController(
                              length: 2,
                              child: Column(
                                children: [
                                  const TabBar(
                                    tabs: [
                                      Tab(text: 'Edit'),
                                      Tab(text: 'Preview'),
                                    ],
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      children: [editor, preview],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saveAsMarkdown,
                            icon: const Icon(Icons.save_alt),
                            label: const Text('Save as Markdown'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _exportReadme,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Export README.md'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
