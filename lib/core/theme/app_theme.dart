import 'package:flutter/material.dart';

/// App-wide Material 3 theme, seeded from a single brand color. Feature
/// changes should reach for `Theme.of(context)` rather than hardcoding
/// colors, so this stays the single place brand identity lives.
final class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Color(0xFF0B5FFF);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}
