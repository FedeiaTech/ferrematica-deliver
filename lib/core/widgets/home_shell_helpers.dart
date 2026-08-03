import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/providers.dart' show authRepositoryProvider;

/// Confirms the user wants to close the app rather than exiting immediately
/// on the first back-press from a root tab (`DuenoHomeScreen`/
/// `CadeteHomeScreen`, wrapped in a `PopScope`).
Future<bool> confirmExit(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Salir de la app'),
      content: const Text('¿Querés salir de Ferrematica Express?'),
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

/// Account menu opened by tapping the role label in `SectionBanner` — for
/// now this only exposes signing out, but it's the natural place to add
/// account-level actions later.
void showAccountMenu(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
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
