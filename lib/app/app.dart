import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'command_registry.dart';
import 'router.dart';
import 'theme/app_theme_factory.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_preferences.dart';
import '../features/privacy/presentation/privacy_acceptance_gate.dart';
import '../features/privacy/provider/privacy_acceptance_provider.dart';

/// The root widget of the application.
///
/// [MyApp] configures theming and routing from the persisted appearance
/// preferences.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(themePreferencesProvider);
    final privacyAccepted = ref.watch(privacyAcceptanceProvider).isAccepted;
    final standardLight = AppThemeFactory.build(
      palette: preferences.palette,
      brightness: Brightness.light,
      contrastMode: AppContrastMode.standard,
      densityMode: preferences.densityMode,
    );
    final standardDark = AppThemeFactory.build(
      palette: preferences.palette,
      brightness: Brightness.dark,
      contrastMode: AppContrastMode.standard,
      densityMode: preferences.densityMode,
    );
    final highContrastLight = AppThemeFactory.build(
      palette: preferences.palette,
      brightness: Brightness.light,
      contrastMode: AppContrastMode.high,
      densityMode: preferences.densityMode,
    );
    final highContrastDark = AppThemeFactory.build(
      palette: preferences.palette,
      brightness: Brightness.dark,
      contrastMode: AppContrastMode.high,
      densityMode: preferences.densityMode,
    );
    final forceHighContrast = preferences.contrastMode == AppContrastMode.high;
    final forceStandardContrast =
        preferences.contrastMode == AppContrastMode.standard;

    return MaterialApp(
      navigatorKey: devDeskNavigatorKey,
      title: 'DevDesk',
      debugShowCheckedModeBanner: false,
      theme: forceHighContrast ? highContrastLight : standardLight,
      darkTheme: forceHighContrast ? highContrastDark : standardDark,
      highContrastTheme:
          forceStandardContrast ? standardLight : highContrastLight,
      highContrastDarkTheme:
          forceStandardContrast ? standardDark : highContrastDark,
      themeMode: preferences.brightnessMode,
      shortcuts: kIsWeb || !privacyAccepted ? null : devDeskShortcuts,
      actions: kIsWeb || !privacyAccepted ? null : devDeskActions,
      onGenerateRoute: (settings) => generateRoute(settings),
      initialRoute: '/dashboard',
      builder: (context, child) => PrivacyAcceptanceGate(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
