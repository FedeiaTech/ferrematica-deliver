import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cadete_directory.dart';
import '../providers.dart';

/// Dueño-only form to create a cadete account in-app, replacing the manual
/// Supabase Dashboard provisioning process. Reachable only from
/// `DuenoHomeScreen`'s account menu (`home_shell_helpers.dart`), which is
/// itself gated to a dueño session by `app_router.dart`'s redirect — see
/// that guard's doc comment for the defense-in-depth rationale. The Edge
/// Function re-verifies the caller is a dueño server-side regardless (see
/// `supabase/functions/create-cadete/index.ts`), so this screen being
/// reachable is not itself a security boundary.
///
/// Follows `OrderFormScreen`'s form conventions: a [GlobalKey<FormState>],
/// a `_saving` flag disabling the submit button while in flight, and
/// snackbar feedback on both success and failure.
class CreateCadeteScreen extends ConsumerStatefulWidget {
  const CreateCadeteScreen({super.key});

  @override
  ConsumerState<CreateCadeteScreen> createState() => _CreateCadeteScreenState();
}

class _CreateCadeteScreenState extends ConsumerState<CreateCadeteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _nroController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _nroController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Fills the password field with a random 12-character secure password
  /// (letters, digits, and a couple of symbols) the dueño can hand to the
  /// cadete directly — there is no invite-email flow, so someone has to
  /// type or read this out loud/copy it somewhere.
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

    final nroText = _nroController.text.trim();
    final controller = ref.read(createCadeteControllerProvider.notifier);
    await controller.create(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nombre: _nombreController.text.trim(),
      nro: nroText.isEmpty ? null : int.tryParse(nroText),
    );
    if (!mounted) return;

    final state = ref.read(createCadeteControllerProvider);
    if (state.hasError) {
      final error = state.error;
      final message = error is CadeteDirectoryException
          ? error.message
          : 'No se pudo crear el cadete. Intentá de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cadete creado correctamente')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(createCadeteControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo cadete')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                helperText: 'Lo definís vos — se usa para identificarlo en estadísticas.',
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
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'El email es obligatorio';
                if (!trimmed.contains('@') || !trimmed.contains('.')) {
                  return 'Ingresá un email válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña *',
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _generatePassword,
              icon: const Icon(Icons.password_outlined),
              label: const Text('Generar contraseña'),
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
                  : const Text('Crear cadete'),
            ),
          ],
        ),
      ),
    );
  }
}
