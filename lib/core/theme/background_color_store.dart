import 'package:shared_preferences/shared_preferences.dart';

import 'background_color_provider.dart' show BrandBackground;

/// Persists the user's chosen [BrandBackground] across launches, by enum
/// name (not just its ARGB color) — `naranja`'s stripe pattern is part of
/// its identity, not derivable from a bare color value.
class BackgroundColorStore {
  const BackgroundColorStore._();

  static const String _key = 'background_color_option';

  static Future<void> save(BrandBackground option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.name);
  }

  static Future<BrandBackground> read() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    if (name == null) return BrandBackground.sistema;
    return BrandBackground.values.firstWhere(
      (option) => option.name == name,
      orElse: () => BrandBackground.sistema,
    );
  }
}
