import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/files/external_file_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
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
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final form = _ReadmeForm(
            formKey: _formKey,
            nameController: _nameController,
            descriptionController: _descriptionController,
            featuresController: _featuresController,
            installController: _installController,
            usageController: _usageController,
            screenshotsController: _screenshotsController,
            licenseController: _licenseController,
            onGenerate: _generateReadme,
          );
          final output = _ReadmeOutput(
            generated: _generated,
            generatedController: _generatedController,
            onCopy: _copyToClipboard,
            onSave: _saveAsMarkdown,
            onExport: _exportReadme,
          );
          if (isWide) {
            return Padding(
              padding: AppSpacing.page(context),
              child: Row(
                children: [
                  SizedBox(width: 440, child: form),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: output),
                ],
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [Tab(text: 'Form'), Tab(text: 'Output')],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Padding(padding: AppSpacing.page(context), child: form),
                    Padding(padding: AppSpacing.page(context), child: output),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadmeForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController featuresController;
  final TextEditingController installController;
  final TextEditingController usageController;
  final TextEditingController screenshotsController;
  final TextEditingController licenseController;
  final VoidCallback onGenerate;

  const _ReadmeForm({
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.featuresController,
    required this.installController,
    required this.usageController,
    required this.screenshotsController,
    required this.licenseController,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader(
                title: 'Project basics',
                subtitle: 'Name and one-line purpose of the project.',
              ),
              const SizedBox(height: AppSpacing.md),
              _buildField(
                'Project Name',
                nameController,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Project name is required';
                  }
                  return null;
                },
              ),
              _buildField(
                'Description',
                descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              const AppSectionHeader(
                title: 'Features',
                subtitle: 'One item per line; these become Markdown bullets.',
              ),
              const SizedBox(height: AppSpacing.md),
              _buildField(
                'Features (one per line)',
                featuresController,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              const AppSectionHeader(
                title: 'Installation and usage',
                subtitle: 'Keep commands and examples concise.',
              ),
              const SizedBox(height: AppSpacing.md),
              _buildField('Installation', installController, maxLines: 3),
              _buildField('Usage', usageController, maxLines: 3),
              const SizedBox(height: AppSpacing.md),
              const AppSectionHeader(
                title: 'Screenshots and license',
                subtitle: 'Optional Markdown image links and license name.',
              ),
              const SizedBox(height: AppSpacing.md),
              _buildField(
                'Screenshots (Markdown)',
                screenshotsController,
                maxLines: 3,
              ),
              _buildField('License', licenseController),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.description),
                label: const Text('Generate README'),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ReadmeOutput extends StatelessWidget {
  final String generated;
  final TextEditingController generatedController;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onExport;

  const _ReadmeOutput({
    required this.generated,
    required this.generatedController,
    required this.onCopy,
    required this.onSave,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  'Output',
                  style: Theme.of(context).textTheme.titleMedium,
                );
                final actions = Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.icon(
                      onPressed: generated.isEmpty ? null : onCopy,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed: generated.isEmpty ? null : onSave,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save as Markdown'),
                    ),
                    OutlinedButton.icon(
                      onPressed: generated.isEmpty ? null : onExport,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Export README.md'),
                    ),
                  ],
                );
                if (constraints.maxWidth < 700) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: AppSpacing.xs),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    actions,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: generated.isEmpty
                ? const AppEmptyState(
                    icon: Icons.article,
                    title: 'Fill out the form and generate a README',
                    message:
                        'The editable Markdown and live preview will appear here.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final editor = TextField(
                        controller: generatedController,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        style: AppTypography.mono(context),
                        decoration: InputDecoration(
                          labelText: 'Editable README.md',
                          alignLabelWithHint: true,
                          fillColor: AppColors.codeBackground(context),
                        ),
                      );
                      final preview = Markdown(
                        data: generated,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                      );
                      if (constraints.maxWidth >= 840) {
                        return Row(
                          children: [
                            Expanded(child: editor),
                            const VerticalDivider(width: 1),
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
                              child: TabBarView(children: [editor, preview]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
