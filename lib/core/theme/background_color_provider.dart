import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_color_store.dart';

/// Light background options offered from the account menu (see
/// `home_shell_helpers.dart`), derived from the Ferremática Express logo
/// (cream ring, red badge, steel-blue ring). [sistema] has a `null`
/// [color] — falls back to [AppTheme]'s default seeded surface color
/// rather than an explicit override.
///
/// All-solid palette — a previous pass added diagonal-striped variants
/// (`rojoRayado`/`aceroRayado`/`naranja`) but full-screen `CustomPaint`
/// stripes cost a real repaint on every frame and read as visual noise in
/// practice, so they were dropped. Each `*Oscuro`/[naranja] entry below is
/// the darker color from that dropped stripe combo, softened by blending
/// toward white so it stays readable as a full solid background instead of
/// the raw, more intense stripe hue.
enum BrandBackground {
  sistema(null, 'Sistema'),
  // Noticeably more saturated than the very first pass (which was so pale
  // it read as plain white in the picker's small swatches) while staying
  // light enough for dark text to read comfortably on top.
  crema(Color(0xFFEDDFB8), 'Crema'),
  rojoClaro(Color(0xFFF6C6C1), 'Rojo claro'),
  rojoOscuro(Color(0xFFE3746C), 'Rojo oscuro'),
  aceroClaro(Color(0xFFC9D9E2), 'Acero claro'),
  aceroOscuro(Color(0xFF6E92AA), 'Acero oscuro'),
  naranja(Color(0xFFF5AE6E), 'Naranja');

  const BrandBackground(this.color, this.label);

  final Color? color;
  final String label;
}

/// Holds the current background selection and persists every change via
/// [BackgroundColorStore]. Starts at [BrandBackground.sistema] and loads
/// the saved value asynchronously — a one-frame flash of the default
/// before a saved custom option applies is an acceptable trade-off for a
/// cosmetic setting, given the alternative is threading this through
/// `AppBootstrap.init()` for something this low-stakes.
class BackgroundColorController extends Notifier<BrandBackground> {
  @override
  BrandBackground build() {
    _load();
    return BrandBackground.sistema;
  }

  Future<void> _load() async {
    state = await BackgroundColorStore.read();
  }

  Future<void> select(BrandBackground option) async {
    state = option;
    await BackgroundColorStore.save(option);
  }
}

final NotifierProvider<BackgroundColorController, BrandBackground> backgroundColorProvider =
    NotifierProvider<BackgroundColorController, BrandBackground>(BackgroundColorController.new);
