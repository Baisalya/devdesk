import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_storage.dart';
import 'command_registry.dart';
import 'router.dart';
import 'theme/dark_theme.dart';
import 'theme/light_theme.dart';

/// The root widget of the application.
///
/// [MyApp] configures theming and routing. It also listens to the
/// `themeModeProvider` to toggle between light and dark modes.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      navigatorKey: devDeskNavigatorKey,
      title: 'DevDesk',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      shortcuts: kIsWeb ? null : devDeskShortcuts,
      actions: kIsWeb ? null : devDeskActions,
      onGenerateRoute: (settings) => generateRoute(settings),
      initialRoute: '/dashboard',
    );
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _storageKey = 'theme_mode';

  Future<void> _load() async {
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    final stored = box.get(_storageKey) as String?;
    state = _fromStorageValue(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final box = await LocalStorage.openBox<dynamic>(LocalStorage.settingsBox);
    await box.put(_storageKey, mode.name);
  }

  static ThemeMode _fromStorageValue(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

/// Provider storing the current [ThemeMode]. Defaults to system mode.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
