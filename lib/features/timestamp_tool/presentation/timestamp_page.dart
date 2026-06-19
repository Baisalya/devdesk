import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_result_panel.dart';
import '../provider/timestamp_provider.dart';

/// Page for converting Unix timestamps to dates and vice versa.
class TimestampPage extends ConsumerStatefulWidget {
  const TimestampPage({super.key});

  @override
  ConsumerState<TimestampPage> createState() => _TimestampPageState();
}

class _TimestampPageState extends ConsumerState<TimestampPage> {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController =
        TextEditingController(text: ref.read(timestampInputProvider));
    _inputController.addListener(() {
      ref.read(timestampInputProvider.notifier).state = _inputController.text;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(timestampResultProvider);
    final dateTime = ref.watch(dateTimeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Timestamp Converter')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final input = _TimestampInputCard(
            controller: _inputController,
            selectedDateTime: dateTime,
            onToDate: () => convertFromTimestamp(ref),
            onPickDateTime: () => _pickDateTime(context),
            onToUnix: () => convertToTimestamp(ref),
          );
          final output = AppResultPanel(
            title: 'UTC / Local output',
            text: result,
            emptyTitle: 'No conversion yet',
            emptyMessage:
                'Enter a Unix timestamp or pick a date to see converted values.',
            monospace: false,
          );
          return Padding(
            padding: AppSpacing.page(context),
            child: isWide
                ? Row(
                    children: [
                      SizedBox(width: 420, child: input),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: output),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: input),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(child: output),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final current = ref.read(dateTimeProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    final combined = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    ref.read(dateTimeProvider.notifier).state = combined;
  }
}

class _TimestampInputCard extends StatelessWidget {
  final TextEditingController controller;
  final DateTime? selectedDateTime;
  final VoidCallback onToDate;
  final VoidCallback onPickDateTime;
  final VoidCallback onToUnix;

  const _TimestampInputCard({
    required this.controller,
    required this.selectedDateTime,
    required this.onToDate,
    required this.onPickDateTime,
    required this.onToUnix,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Timestamp input',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter Unix seconds or milliseconds',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: const [
                AppBadge(label: 'seconds', icon: Icons.timer),
                AppBadge(label: 'milliseconds', icon: Icons.timer_outlined),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Date picker', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              filled: false,
              child: Text(
                selectedDateTime == null
                    ? 'No date selected yet.'
                    : 'Selected: $selectedDateTime',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.icon(
                  onPressed: onToDate,
                  icon: const Icon(Icons.event),
                  label: const Text('To Date'),
                ),
                OutlinedButton.icon(
                  onPressed: onPickDateTime,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Pick Date & Time'),
                ),
                OutlinedButton.icon(
                  onPressed: onToUnix,
                  icon: const Icon(Icons.tag),
                  label: const Text('To Unix'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
