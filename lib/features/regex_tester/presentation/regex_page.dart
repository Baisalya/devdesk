import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('Regex Tester')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _patternController,
              decoration: const InputDecoration(
                labelText: 'Regex Pattern',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sampleController,
              decoration: const InputDecoration(
                labelText: 'Sample Text',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _multiLine,
                      onChanged: (value) {
                        setState(() => _multiLine = value ?? false);
                      },
                    ),
                    const Text('Multiline'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _caseSensitive,
                      onChanged: (value) {
                        setState(() => _caseSensitive = value ?? true);
                      },
                    ),
                    const Text('Case sensitive'),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => testRegex(
                    ref,
                    multiLine: _multiLine,
                    caseSensitive: _caseSensitive,
                  ),
                  child: const Text('Test'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result.isLoading)
              const CircularProgressIndicator()
            else if (result.hasError)
              Text(
                result.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else ...[
              Text('Matches: ${matches.length}'),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildHighlightedText(
                    _patternController.text,
                    _sampleController.text,
                    matches,
                    context,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String pattern,
    String text,
    List<Match> matches,
    BuildContext context,
  ) {
    if (pattern.isEmpty || text.isEmpty || matches.isEmpty) {
      return Text(text);
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
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          ),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
