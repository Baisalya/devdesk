import 'package:flutter/material.dart';

enum AppPalette {
  devdeskOcean(
    id: 'devdesk_ocean',
    label: 'DevDesk Ocean',
    description: 'Focused blue with cyan and violet energy.',
    seed: Color(0xFF2563EB),
    secondaryPreview: Color(0xFF0891B2),
    tertiaryPreview: Color(0xFF7C3AED),
    lightSurface: Color(0xFFF7F9FF),
    darkSurface: Color(0xFF0B1220),
  ),
  terminalMatrix(
    id: 'terminal_matrix',
    label: 'Terminal Matrix',
    description: 'Terminal green over mint and graphite surfaces.',
    seed: Color(0xFF16A34A),
    secondaryPreview: Color(0xFF0D9488),
    tertiaryPreview: Color(0xFF84CC16),
    lightSurface: Color(0xFFF5FBF7),
    darkSurface: Color(0xFF0A1510),
  ),
  neonViolet(
    id: 'neon_violet',
    label: 'Neon Violet',
    description: 'Violet workspace with magenta and cyan accents.',
    seed: Color(0xFF7C3AED),
    secondaryPreview: Color(0xFFDB2777),
    tertiaryPreview: Color(0xFF06B6D4),
    lightSurface: Color(0xFFFAF7FF),
    darkSurface: Color(0xFF140D20),
  ),
  emberConsole(
    id: 'ember_console',
    label: 'Ember Console',
    description: 'Warm orange with amber and red highlights.',
    seed: Color(0xFFEA580C),
    secondaryPreview: Color(0xFFD97706),
    tertiaryPreview: Color(0xFFDC2626),
    lightSurface: Color(0xFFFFF8F3),
    darkSurface: Color(0xFF1B100B),
  ),
  circuitTeal(
    id: 'circuit_teal',
    label: 'Circuit Teal',
    description: 'Balanced teal with sky and indigo accents.',
    seed: Color(0xFF0F766E),
    secondaryPreview: Color(0xFF0284C7),
    tertiaryPreview: Color(0xFF4F46E5),
    lightSurface: Color(0xFFF3FAFA),
    darkSurface: Color(0xFF081615),
  ),
  graphiteMono(
    id: 'graphite_mono',
    label: 'Graphite Mono',
    description: 'Clean black, white, and graphite for low-distraction work.',
    seed: Color(0xFF475569),
    secondaryPreview: Color(0xFF71717A),
    tertiaryPreview: Color(0xFF334155),
    lightSurface: Color(0xFFFAFAFA),
    darkSurface: Color(0xFF0C0C0D),
  );

  final String id;
  final String label;
  final String description;
  final Color seed;
  final Color secondaryPreview;
  final Color tertiaryPreview;
  final Color lightSurface;
  final Color darkSurface;

  const AppPalette({
    required this.id,
    required this.label,
    required this.description,
    required this.seed,
    required this.secondaryPreview,
    required this.tertiaryPreview,
    required this.lightSurface,
    required this.darkSurface,
  });

  Color surface(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurface : lightSurface;
  }

  static AppPalette fromId(String? id) {
    return AppPalette.values.firstWhere(
      (palette) => palette.id == id,
      orElse: () => AppPalette.devdeskOcean,
    );
  }
}
