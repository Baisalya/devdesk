import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unix Timestamp'),
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                hintText: 'Enter Unix seconds or milliseconds',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => convertFromTimestamp(ref),
                  child: const Text('To Date'),
                ),
                ElevatedButton(
                  onPressed: () => _pickDateTime(context),
                  child: const Text('Pick Date & Time'),
                ),
                ElevatedButton(
                  onPressed: () => convertToTimestamp(ref),
                  child: const Text('To Unix'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dateTime != null) Text('Selected: $dateTime'),
            if (result != null) ...[
              const SizedBox(height: 8),
              SelectableText(result),
            ],
          ],
        ),
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
