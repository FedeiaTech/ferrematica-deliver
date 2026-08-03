import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/order.dart';
import '../providers.dart';

/// Create/edit form for an order. [existingOrder] is `null` when creating.
///
/// [prefillFrom] supports "Reintentar entrega" (order_detail_screen.dart,
/// only shown on a `cancelado` order with a `deliveryProblem`): pre-fills
/// the fields from the failed order without editing it — submitting still
/// creates a brand-new order via [OrdersController.createOrder], so the
/// original stays untouched as a permanent record of what went wrong.
/// Ignored when [existingOrder] is set (a real edit always wins).
///
/// Per design's Presentation Scope: `delivery_address` is the only
/// validated field — autofocused, at the top, labelled with a trailing
/// `*`. Everything else lives inside a collapsible "Datos opcionales"
/// section so optionality is communicated structurally, not just by an
/// absent asterisk. Save is enabled as soon as the address is non-empty.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({this.existingOrder, this.prefillFrom, super.key});

  final Order? existingOrder;
  final Order? prefillFrom;

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
  late final String _cityAtFormOpen;
  bool _canSave = false;
  bool _saving = false;

  Order? get _existing => widget.existingOrder;

  /// The order to read prefilled values from — the real one being edited,
  /// or (only when not editing) the failed order a "Reintentar entrega"
  /// retry is based on.
  Order? get _source => widget.existingOrder ?? widget.prefillFrom;

  @override
  void initState() {
    super.initState();
    final source = _source;
    // Captured so `_submit` can tell whether the dueño changed the city
    // selector during this edit — an unchanged address with a changed city
    // still needs a fresh geocode (see OrdersController.updateOrder's
    // `forceRegeocode`).
    _cityAtFormOpen = ref.read(selectedGeocodingCityProvider);
    _addressController = TextEditingController(
      text: source?.deliveryAddress ?? '',
    );
    _clientNameController = TextEditingController(
      text: source?.clientName ?? '',
    );
    _clientPhoneController = TextEditingController(
      text: source?.clientPhone ?? '',
    );
    // A retry carries the original problem forward as a starting note —
    // editable/removable, not a permanent link — so the dueño sees why
    // this new order exists without having to go back to the old one.
    final retryNote = _existing == null && widget.prefillFrom?.deliveryProblem != null
        ? 'Reintento por: ${widget.prefillFrom!.deliveryProblem}'
        : null;
    _notesController = TextEditingController(
      text: retryNote ?? source?.notes ?? '',
    );
    _amountController = TextEditingController(
      text: source?.amountToCharge?.toString() ?? '',
    );
    _paymentMethod = source?.paymentMethod ?? PaymentMethod.efectivo;
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

    final cityHint = ref.read(selectedGeocodingCityProvider);
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
        cityHint: cityHint,
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
        cityHint: cityHint,
        forceRegeocode: cityHint != _cityAtFormOpen,
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
    final isRetry = !isEditing && widget.prefillFrom != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Editar pedido'
              : isRetry
              ? 'Reintentar entrega'
              : 'Nuevo pedido',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _addressController,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
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
            const SizedBox(height: 12),
            const _CitySelector(),
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
                        textCapitalization: TextCapitalization.words,
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
                        textCapitalization: TextCapitalization.sentences,
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

/// Sentinel dropdown value for "Agregar ciudad…" — never a real city, so it
/// can't collide with a dueño-entered name (Nominatim doesn't reject
/// duplicate/odd city strings, so this only needs to be unlikely, not
/// validated against the existing list).
const String _addCityValue = '__add_city__';

/// City picker shown below the address field — the selected city is
/// appended to the address before it's sent to [GeocodingClient.geocode]
/// (see [OrdersController]), disambiguating a street name that exists in
/// more than one town (e.g. "Candioti" in both Santo Tomé and elsewhere).
/// Backed by shared providers ([geocodingCitiesProvider],
/// [selectedGeocodingCityProvider]) so an added city and the current
/// selection persist across the app for the rest of the session, not just
/// this form instance.
class _CitySelector extends ConsumerWidget {
  const _CitySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(geocodingCitiesProvider);
    final selected = ref.watch(selectedGeocodingCityProvider);

    return DropdownButtonFormField<String>(
      value: selected,
      decoration: const InputDecoration(
        labelText: 'Ciudad (ayuda a ubicar la dirección)',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final city in cities) DropdownMenuItem(value: city, child: Text(city)),
        const DropdownMenuItem(
          value: _addCityValue,
          child: Text('+ Agregar ciudad…'),
        ),
      ],
      onChanged: (value) async {
        if (value == null) return;
        if (value != _addCityValue) {
          ref.read(selectedGeocodingCityProvider.notifier).state = value;
          return;
        }
        final added = await _promptNewCity(context);
        if (added == null || added.trim().isEmpty) return;
        final trimmed = added.trim();
        final updated = [...cities, trimmed];
        ref.read(geocodingCitiesProvider.notifier).state = updated;
        ref.read(selectedGeocodingCityProvider.notifier).state = trimmed;
      },
    );
  }

  Future<String?> _promptNewCity(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar ciudad'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej: Recreo, Santa Fe',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}
