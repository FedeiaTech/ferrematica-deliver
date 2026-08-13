import 'package:flutter/material.dart';

/// App-wide Material 3 theme, seeded from a single brand color. Feature
/// changes should reach for `Theme.of(context)` rather than hardcoding
/// colors, so this stays the single place brand identity lives.
final class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Color(0xFF0B5FFF);

  /// [background] overrides the scaffold background color — see
  /// `BrandBackground`/`backgroundColorProvider`. `null` (the default)
  /// leaves Material 3's seeded surface color untouched.
  ///
  /// Material 3 blends `colorScheme.surfaceTint` (derived from the blue
  /// [_seedColor]) into elevated surfaces ("tonal elevation") — with a
  /// custom [background] that reads as a muddy blue-brown wash instead of
  /// the clean color picked in `BackgroundColorController`. Zeroing
  /// `surfaceTint` (only when [background] is actually set — the default
  /// "Sistema" look keeps normal M3 tonal elevation) kills that blend, and
  /// `canvasColor` covers the few widgets that key off it instead of
  /// `scaffoldBackgroundColor`.
  static ThemeData light([Color? background]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: background == null
          ? colorScheme
          : colorScheme.copyWith(surfaceTint: Colors.transparent),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      // Otherwise the bottom NavigationBar defaults to M3's own elevated
      // surface color, which clashes with a custom background instead of
      // matching it.
      navigationBarTheme: background == null
          ? null
          : NavigationBarThemeData(backgroundColor: background),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}
