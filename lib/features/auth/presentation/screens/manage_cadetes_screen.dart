import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/cadete_directory.dart';
import '../providers.dart';

/// Dueño-only roster screen — the "R"/"U"/"D" (logical) of cadete CRUD,
/// complementing `CreateCadeteScreen`'s "C". Reachable only from
/// `DuenoHomeScreen`'s account menu (`home_shell_helpers.dart`), gated the
/// same way `create_cadete_screen.dart` is — see that screen's doc comment
/// for the defense-in-depth rationale (this screen's writes are also
/// re-checked server-side by `profiles_update_cadetes_by_dueno`, migration
/// 0021, regardless of whether this screen is reachable).
///
/// Lists EVERY cadete (`allCadetesProvider` — active and inactive alike),
/// ordered by `nro` then name. Tapping a row opens [_EditCadeteSheet] to
/// change nombre/nro; the trailing switch toggles active/inactive
/// (baja/reactivar) with a confirmation dialog before deactivating, since
/// that immediately removes the cadete from the assignment picker.
class ManageCadetesScreen extends ConsumerWidget {
  const ManageCadetesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cadetesAsync = ref.watch(allCadetesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar cadetes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: 'Nuevo cadete',
            onPressed: () => context.push('/orders/cadetes/new'),
          ),
        ],
      ),
      body: cadetesAsync.when(
        data: (cadetes) {
          if (cadetes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay cadetes cargados.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: cadetes.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final cadete = cadetes[index];
              return _CadeteTile(cadete: cadete);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('No se pudo cargar la lista: $error')),
      ),
    );
  }
}

class _CadeteTile extends ConsumerWidget {
  const _CadeteTile({required this.cadete});

  final CadeteProfile cadete;

  Future<void> _confirmAndToggleActive(BuildContext context, WidgetRef ref) async {
    // Only the deactivation direction needs a confirmation — reactivating
    // is harmless (worst case the dueño taps it again), but a baja
    // immediately hides the cadete from the assignment picker, so it's
    // worth a beat before that happens.
    if (cadete.active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Dar de baja al cadete'),
          content: Text(
            '${cadete.displayName} dejará de aparecer para asignar nuevos pedidos. '
            'Podés reactivarlo cuando quieras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Dar de baja'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final controller = ref.read(setCadeteActiveControllerProvider.notifier);
    await controller.setActive(id: cadete.id, active: !cadete.active);
    if (!context.mounted) return;

    final state = ref.read(setCadeteActiveControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final message = error is CadeteDirectoryException
          ? error.message
          : 'No se pudo actualizar el estado del cadete.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toggling = ref.watch(setCadeteActiveControllerProvider).isLoading;

    return Opacity(
      // Greyed out while inactive so the roster reads at a glance which
      // cadetes are currently on duty, without needing to parse the badge
      // text for every row.
      opacity: cadete.active ? 1.0 : 0.5,
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(cadete.displayLabel),
        subtitle: cadete.active ? null : const Text('Inactivo'),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => _EditCadeteSheet(cadete: cadete),
        ),
        trailing: toggling
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: cadete.active,
                onChanged: (_) => _confirmAndToggleActive(context, ref),
              ),
      ),
    );
  }
}

/// Edit form (nombre + nro) opened as a modal bottom sheet, matching
/// `assign_cadete_sheet.dart`'s interaction shape. Editing email is still
/// out of scope (would mean recreating the `auth.users` row) — password
/// reset is offered via a separate "Cambiar contraseña" button that opens
/// [_ChangePasswordDialog], deliberately its own action rather than a field
/// in this form: a password reset is a distinct, higher-consequence
/// operation (invalidates the cadete's current session credential) that
/// shouldn't be bundled into an accidental save of nombre/nro.
class _EditCadeteSheet extends ConsumerStatefulWidget {
  const _EditCadeteSheet({required this.cadete});

  final CadeteProfile cadete;

  @override
  ConsumerState<_EditCadeteSheet> createState() => _EditCadeteSheetState();
}

class _EditCadeteSheetState extends ConsumerState<_EditCadeteSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _nroController;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cadete.displayName);
    _nroController = TextEditingController(text: widget.cadete.nro?.toString() ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _nroController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nroText = _nroController.text.trim();
    final controller = ref.read(updateCadeteControllerProvider.notifier);
    await controller.update(
      id: widget.cadete.id,
      nombre: _nombreController.text.trim(),
      nro: nroText.isEmpty ? null : int.tryParse(nroText),
    );
    if (!mounted) return;

    final state = ref.read(updateCadeteControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final message = error is CadeteDirectoryException
          ? error.message
          : 'No se pudo actualizar el cadete.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cadete actualizado')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(updateCadeteControllerProvider).isLoading;

    return Padding(
      // Keeps the sheet's fields visible above the on-screen keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Editar cadete', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nroController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de cadete (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    if (int.tryParse(trimmed) == null) return 'Ingresá solo números';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) =>
                        _ChangePasswordDialog(cadete: widget.cadete),
                  ),
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('Cambiar contraseña'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: saving ? null : _submit,
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dueño-only password reset, opened from [_EditCadeteSheet]. Mirrors
/// `create_cadete_screen.dart`'s password field: generate/show/copy, same
/// 6-character minimum enforced both here and by the Edge Function
/// server-side (`update-cadete-password/index.ts`).
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.cadete});

  final CadeteProfile cadete;

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%';
    final random = Random.secure();
    final generated = List.generate(
      12,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    setState(() {
      _passwordController.text = generated;
      _obscurePassword = false;
    });
  }

  Future<void> _copyPassword() async {
    await Clipboard.setData(ClipboardData(text: _passwordController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Contraseña copiada')));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(updateCadetePasswordControllerProvider.notifier);
    await controller.updatePassword(id: widget.cadete.id, password: _passwordController.text);
    if (!mounted) return;

    final state = ref.read(updateCadetePasswordControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final message = error is CadeteDirectoryException
          ? error.message
          : 'No se pudo cambiar la contraseña.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(updateCadetePasswordControllerProvider).isLoading;

    return AlertDialog(
      title: Text('Contraseña de ${widget.cadete.displayName}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _passwordController,
          autofocus: true,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña *',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copiar contraseña',
                  onPressed: _passwordController.text.isEmpty ? null : _copyPassword,
                ),
              ],
            ),
          ),
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'Debe tener al menos 6 caracteres';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _generatePassword,
          icon: const Icon(Icons.password_outlined),
          label: const Text('Generar'),
        ),
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _submit,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
