import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/platform/window_close_guard.dart';
import 'core/storage/local_storage.dart';
import 'core/storage/presentation/storage_recovery_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowCloseGuard.initialize();
  final storage = await LocalStorage.bootstrap();
  runApp(
    ProviderScope(
      child: storage.isReady
          ? const MyApp()
          : StorageRecoveryApp(initialResult: storage),
    ),
  );
}
