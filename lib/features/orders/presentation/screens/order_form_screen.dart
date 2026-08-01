import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/order.dart';
import '../providers.dart';

/// Create/edit form for an order. [existingOrder] is `null` when creating.
///
/// Per design's Presentation Scope: `delivery_address` is the only
/// validated field — autofocused, at the top, labelled with a trailing
/// `*`. Everything else lives inside a collapsible "Datos opcionales"
/// section so optionality is communicated structurally, not just by an
/// absent asterisk. Save is enabled as soon as the address is non-empty.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({this.existingOrder, super.key});

  final Order? existingOrder;

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _clientNameController;
  late final TextEditingController _clientPhoneController;
  late final TextEditingController _notesController;
  late final TextEditingController _amountController;
  late PaymentMethod _paymentMethod;
  bool _canSave = false;
  bool _saving = false;

  Order? get _existing => widget.existingOrder;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    _addressController = TextEditingController(
      text: existing?.deliveryAddress ?? '',
    );
    _clientNameController = TextEditingController(
      text: existing?.clientName ?? '',
    );
    _clientPhoneController = TextEditingController(
      text: existing?.clientPhone ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _amountController = TextEditingController(
      text: existing?.amountToCharge?.toString() ?? '',
    );
    _paymentMethod = existing?.paymentMethod ?? PaymentMethod.sinDefinir;
    _canSave = _addressController.text.trim().isNotEmpty;
    _addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    final canSave = _addressController.text.trim().isNotEmpty;
    if (canSave != _canSave) setState(() => _canSave = canSave);
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_canSave) return;
    setState(() => _saving = true);

    final address = _addressController.text.trim();
    final clientName = _emptyToNull(_clientNameController.text);
    final clientPhone = _emptyToNull(_clientPhoneController.text);
    final notes = _emptyToNull(_notesController.text);
    final amount = double.tryParse(_amountController.text.trim());

    final controller = ref.read(ordersControllerProvider.notifier);
    final existing = _existing;
    if (existing == null) {
      await controller.createOrder(
        deliveryAddress: address,
        clientName: clientName,
        clientPhone: clientPhone,
        notes: notes,
        amountToCharge: amount,
        paymentMethod: _paymentMethod,
      );
    } else {
      await controller.updateOrder(
        existing.copyWith(
          deliveryAddress: address,
          clientName: clientName,
          clientPhone: clientPhone,
          notes: notes,
          amountToCharge: amount,
          paymentMethod: _paymentMethod,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar pedido' : 'Nuevo pedido')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _addressController,
              autofocus: !isEditing,
              decoration: const InputDecoration(
                labelText: 'Dirección de entrega *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La dirección de entrega es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Datos opcionales'),
              subtitle: const Text('Podés completarlo después'),
              initiallyExpanded: isEditing,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _clientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del cliente',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _clientPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono del cliente',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Monto a cobrar',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PaymentMethod>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Método de pago',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PaymentMethod.sinDefinir,
                            child: Text('Sin definir'),
                          ),
                          DropdownMenuItem(
                            value: PaymentMethod.efectivo,
                            child: Text('Efectivo'),
                          ),
                          DropdownMenuItem(
                            value: PaymentMethod.transferencia,
                            child: Text('Transferencia'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _paymentMethod = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notas'),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave && !_saving ? _submit : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
