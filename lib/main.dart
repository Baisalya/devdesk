import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/local_storage.dart';

/// The entry point of the application.
///
/// We wrap [MyApp] with [ProviderScope] so that Riverpod providers are
/// available throughout the widget tree.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.initialize();
  runApp(const ProviderScope(child: MyApp()));
}
