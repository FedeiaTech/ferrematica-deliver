import 'package:flutter/material.dart';

/// Image banner shown at the top of the dueño/cadete home shells
/// ([DuenoHomeScreen]/[CadeteHomeScreen]) — the role label sits top-right,
/// the current tab's section name sits bottom-left when provided (plus an
/// optional action — e.g. the map button on the Pedidos tab — pinned to the
/// bottom-right instead). A semi-transparent gradient "aura" sits between
/// the image and the text so both corners stay legible against the image.
///
/// Fixed at [height] — it never shrinks or fades as the tab's content
/// scrolls.
///
/// Expects an image at [_assetPath] — see that constant's doc for the
/// recommended source size. Falls back to a plain color block via
/// `errorBuilder` if the asset is missing, so this never crashes before
/// the real banner image is in place.
class SectionBanner extends StatelessWidget {
  const SectionBanner({
    required this.roleLabel,
    this.sectionTitle,
    this.trailingSectionAction,
    this.onRoleTap,
    super.key,
  });

  final String roleLabel;
  final String? sectionTitle;
  final Widget? trailingSectionAction;

  /// Called when the role label (top-right) is tapped — the home shells use
  /// this to open the account menu (sign out).
  final VoidCallback? onRoleTap;

  static const double height = 200;

  /// Recommended source image: ~1600×680px (~2.35:1 aspect ratio), JPG or
  /// PNG, under ~500KB — wide enough to stay sharp on high-density
  /// displays via `BoxFit.cover`.
  static const String _assetPath = 'assets/images/home_banner.jpg';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Theme.of(context).colorScheme.primaryContainer),
          ),
          // Semi-transparent aura in both label corners, transparent in
          // the middle so the image still reads through.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.black45, Colors.transparent, Colors.black45],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onRoleTap,
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (sectionTitle != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Text(
                        sectionTitle!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  if (trailingSectionAction != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: trailingSectionAction!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
