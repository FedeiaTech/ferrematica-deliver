import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/providers.dart' show authRepositoryProvider;
import '../../features/auth/domain/app_session.dart' show UserRole;
import '../theme/background_color_picker.dart';

/// Confirms the user wants to close the app rather than exiting immediately
/// on the first back-press from a root tab (`DuenoHomeScreen`/
/// `CadeteHomeScreen`, wrapped in a `PopScope`).
Future<bool> confirmExit(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Salir de la app'),
      content: const Text('¿Querés salir de Ferremática Express?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Salir'),
        ),
      ],
    ),
  );
  return shouldExit ?? false;
}

/// Account menu opened by tapping the role label in `SectionBanner`. Shared
/// by both `DuenoHomeScreen` and `CadeteHomeScreen`, so [role] gates the
/// dueño-only "Nuevo cadete" entry — a cadete session never sees it, even
/// though the route itself is already redirect-gated (`app_router.dart`)
/// as defense in depth.
void showAccountMenu(BuildContext outerContext, WidgetRef ref, {required UserRole role}) {
  showModalBottomSheet<void>(
    context: outerContext,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          if (role == UserRole.dueno)
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: const Text('Nuevo cadete'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/orders/cadetes/new');
              },
            ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Color de fondo'),
            onTap: () {
              Navigator.of(context).pop();
              // Opens a *new* bottom sheet right after popping this one —
              // reuses `outerContext` (the still-mounted screen below),
              // not the shadowed `context` above, which belongs to the
              // sheet that's mid-dismissal by the time this runs.
              showBackgroundColorPicker(outerContext, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              Navigator.of(context).pop();
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    ),
  );
}
