import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app.dart';
import '../local_storage.dart';

class StorageRecoveryApp extends StatefulWidget {
  final StorageBootstrapResult initialResult;

  const StorageRecoveryApp({
    super.key,
    required this.initialResult,
  });

  @override
  State<StorageRecoveryApp> createState() => _StorageRecoveryAppState();
}

class _StorageRecoveryAppState extends State<StorageRecoveryApp> {
  late StorageBootstrapResult _result = widget.initialResult;
  bool _working = false;

  Future<void> _retry() async {
    setState(() => _working = true);
    await LocalStorage.closeAll();
    final result = await LocalStorage.bootstrap();
    if (!mounted) return;
    if (result.isReady) {
      runApp(const ProviderScope(child: MyApp()));
      return;
    }
    setState(() {
      _result = result;
      _working = false;
    });
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text(
          'This permanently removes DevDesk workspaces, history, notes, settings, and protected secrets from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset local data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await LocalStorage.destructiveReset();
      await _retry();
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Local data could not be reset. Close other DevDesk windows and retry.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevDesk recovery',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.storage_rounded, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        'DevDesk could not open local data safely',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _result.message ??
                            'Close other DevDesk windows, check storage access, and retry.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_working)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('Reset local data'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
