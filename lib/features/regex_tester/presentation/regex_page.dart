import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_tool_app_bar.dart';
import '../provider/regex_provider.dart';

/// Page for testing regular expressions against sample text.
class RegexPage extends ConsumerStatefulWidget {
  const RegexPage({super.key});

  @override
  ConsumerState<RegexPage> createState() => _RegexPageState();
}

class _RegexPageState extends ConsumerState<RegexPage> {
  late final TextEditingController _patternController;
  late final TextEditingController _sampleController;
  bool _multiLine = false;
  bool _caseSensitive = true;

  @override
  void initState() {
    super.initState();
    _patternController = TextEditingController(
      text: ref.read(regexPatternProvider),
    );
    _sampleController = TextEditingController(
      text: ref.read(regexSampleProvider),
    );
    _patternController.addListener(() {
      ref.read(regexPatternProvider.notifier).state = _patternController.text;
    });
    _sampleController.addListener(() {
      ref.read(regexSampleProvider.notifier).state = _sampleController.text;
    });
  }

  @override
  void dispose() {
    _patternController.dispose();
    _sampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(regexResultProvider);
    final matches = result.valueOrNull ?? [];
    return Scaffold(
      appBar: const AppToolAppBar(route: '/regex'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final controls = _ControlsPanel(
            patternController: _patternController,
            multiLine: _multiLine,
            caseSensitive: _caseSensitive,
            onMultiLineChanged: (value) {
              setState(() => _multiLine = value);
            },
            onCaseSensitiveChanged: (value) {
              setState(() => _caseSensitive = value);
            },
            onTest: () => testRegex(
              ref,
              multiLine: _multiLine,
              caseSensitive: _caseSensitive,
            ),
          );
          final sample = _SamplePanel(controller: _sampleController);
          final results = _RegexResultPanel(
            result: result,
            matches: matches,
            pattern: _patternController.text,
            sample: _sampleController.text,
          );
          return Padding(
            padding: AppSpacing.page(context),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 360, child: controls),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          children: [
                            SizedBox(height: 240, child: sample),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(child: results),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      controls,
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(height: 220, child: sample),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(height: 360, child: results),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final TextEditingController patternController;
  final bool multiLine;
  final bool caseSensitive;
  final ValueChanged<bool> onMultiLineChanged;
  final ValueChanged<bool> onCaseSensitiveChanged;
  final VoidCallback onTest;

  const _ControlsPanel({
    required this.patternController,
    required this.multiLine,
    required this.caseSensitive,
    required this.onMultiLineChanged,
    required this.onCaseSensitiveChanged,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pattern', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: patternController,
            decoration: const InputDecoration(
              labelText: 'Regex Pattern',
              prefixIcon: Icon(Icons.code),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Multiline'),
            value: multiLine,
            onChanged: onMultiLineChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Case sensitive'),
            value: caseSensitive,
            onChanged: onCaseSensitiveChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onTest,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Test'),
          ),
        ],
      ),
    );
  }
}

class _SamplePanel extends StatelessWidget {
  final TextEditingController controller;

  const _SamplePanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sample text', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Sample Text',
                alignLabelWithHint: true,
              ),
              expands: true,
              minLines: null,
              maxLines: null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegexResultPanel extends StatelessWidget {
  final AsyncValue<List<Match>> result;
  final List<Match> matches;
  final String pattern;
  final String sample;

  const _RegexResultPanel({
    required this.result,
    required this.matches,
    required this.pattern,
    required this.sample,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (result.isLoading) {
      child = const AppLoadingState(label: 'Testing pattern...');
    } else if (result.hasError) {
      child = Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppErrorState(
          title: 'Invalid regex',
          message: result.error.toString(),
        ),
      );
    } else if (sample.isEmpty) {
      child = const AppEmptyState(
        icon: Icons.find_in_page,
        title: 'Add sample text',
        message: 'Matches will be highlighted here.',
      );
    } else {
      child = SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _HighlightedRegexText(
          pattern: pattern,
          text: sample,
          matches: matches,
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Results',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                AppBadge(
                  label: 'Matches: ${matches.length}',
                  icon: Icons.filter_center_focus,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _HighlightedRegexText extends StatelessWidget {
  final String pattern;
  final String text;
  final List<Match> matches;

  const _HighlightedRegexText({
    required this.pattern,
    required this.text,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    if (pattern.isEmpty || text.isEmpty || matches.isEmpty) {
      return SelectableText(text);
    }
    final spans = <TextSpan>[];
    var index = 0;
    for (final match in matches) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return SelectableText.rich(
      TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
