import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/ventas_remote.dart' show VentaYaVinculadaException;
import '../../domain/order.dart';
import '../providers.dart';
import '../widgets/venta_picker_sheet.dart';

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
  late final TextEditingController _envioController;
  late PaymentMethod _paymentMethod;
  late final String _cityAtFormOpen;
  bool _canSave = false;
  bool _saving = false;

  /// Line items — a manually-added/edit-carried-over line (`sourceVentaId
  /// == null`) stays fully editable; a line prefilled by [_pickVenta]
  /// mirrors an actual completed POS sale, so it renders locked in
  /// `_OrderItemRow` and can only be removed as a whole venta (see
  /// [_removeVenta]), never quantity-adjusted.
  List<OrderItem> _items = <OrderItem>[];

  /// Server-generated `ventas.id`s of every venta picked via [_pickVenta],
  /// in pick order. Only used to claim the links on submit (design
  /// decision D4) — never written at selection time. Several ventas can be
  /// bundled into one pedido; picking a new one appends to this list and to
  /// [_items] instead of replacing the previous pick.
  final List<String> _selectedVentaIds = <String>[];

  /// `venta.fecha`/`venta.total` for every id in [_selectedVentaIds],
  /// keyed by venta id — purely transient display/bookkeeping state, not
  /// persisted on [OrderItem]. `_OrderItemRow` reads [_ventaFechas] to show
  /// when a locked line's venta happened; [_removeVenta] reads
  /// [_ventaTotales] to subtract it back out of the amount field.
  final Map<String, DateTime> _ventaFechas = <String, DateTime>{};
  final Map<String, double> _ventaTotales = <String, double>{};

  /// `venta.ventaLocalId` for every id in [_selectedVentaIds] — display-only,
  /// same bookkeeping shape as [_ventaFechas]/[_ventaTotales]. Used to label
  /// each venta's framed block ("Factura Nº ...") the same way
  /// `order_detail_screen.dart`'s `_LinkedVentaTile` does post-creation.
  final Map<String, int> _ventaLocalIds = <String, int>{};

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
    _envioController = TextEditingController(
      text: source?.valorEnvio?.toString() ?? '',
    );
    _paymentMethod = source?.paymentMethod ?? PaymentMethod.efectivo;
    _items = List<OrderItem>.from(source?.items ?? const <OrderItem>[]);
    _canSave = _addressController.text.trim().isNotEmpty;
    _addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    final canSave = _addressController.text.trim().isNotEmpty;
    if (canSave != _canSave) setState(() => _canSave = canSave);
  }

  /// Opens the "desde venta" picker (excluding ventas already added to this
  /// form) and, on selection, APPENDS to [_items] (`productLabel`/
  /// `quantityForOrder` — see `VentaDetalleDisponible`'s D6 handling of
  /// fractional quantities), tagged with `sourceVentaId` so they render
  /// locked, and adds the venta's total on top of whatever `amountToCharge`
  /// already had — several sales can be bundled into one delivery. Per
  /// spec, the client/destinatario field is deliberately left untouched —
  /// the venta carries no such data.
  Future<void> _pickVenta() async {
    final venta = await showVentaPickerSheet(
      context,
      excludedVentaIds: _selectedVentaIds.toSet(),
    );
    if (venta == null || !mounted) return;
    setState(() {
      _selectedVentaIds.add(venta.id);
      _ventaFechas[venta.id] = venta.fecha;
      _ventaTotales[venta.id] = venta.total;
      _ventaLocalIds[venta.id] = venta.ventaLocalId;
      _items.addAll(
        venta.detalles.map(
          (detalle) => OrderItem(
            productName: detalle.productLabel,
            quantity: detalle.quantityForOrder,
            sourceVentaId: venta.id,
          ),
        ),
      );
      final previousAmount = double.tryParse(_amountController.text.trim()) ?? 0;
      _amountController.text = (previousAmount + venta.total).toString();
    });
  }

  void _changeItemQuantity(int index, int delta) {
    setState(() {
      final item = _items[index];
      if (item.sourceVentaId != null) return;
      final quantity = item.quantity + delta;
      if (quantity < 1) return;
      _items[index] = item.copyWith(quantity: quantity);
    });
  }

  void _removeItem(int index) {
    if (_items[index].sourceVentaId != null) return;
    setState(() => _items.removeAt(index));
  }

  /// Un-picks an entire venta from the pedido: every [OrderItem] sharing
  /// [ventaId], the id itself from [_selectedVentaIds] (so it becomes
  /// pickable again in [showVentaPickerSheet]), and its [_ventaFechas]/
  /// [_ventaTotales] bookkeeping — subtracting its total back out of
  /// [_amountController], mirroring [_pickVenta]'s addition. A venta is one
  /// atomic POS sale: there's no such thing as removing one of its product
  /// lines while keeping the rest, so the trash icon on a locked row always
  /// un-picks the whole venta, never a single line (unlike a manually-added
  /// item's [_removeItem], which stays single-line).
  void _removeVenta(String ventaId) {
    setState(() {
      _items.removeWhere((item) => item.sourceVentaId == ventaId);
      _selectedVentaIds.remove(ventaId);
      _ventaFechas.remove(ventaId);
      _ventaLocalIds.remove(ventaId);
      final total = _ventaTotales.remove(ventaId);
      if (total != null) {
        final currentAmount = double.tryParse(_amountController.text.trim()) ?? 0;
        final updated = currentAmount - total;
        _amountController.text = updated <= 0 ? '' : updated.toString();
      }
    });
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _envioController.dispose();
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
    final envio = double.tryParse(_envioController.text.trim());

    final cityHint = ref.read(selectedGeocodingCityProvider);
    final controller = ref.read(ordersControllerProvider.notifier);
    final existing = _existing;
    try {
      if (existing == null) {
        await controller.createOrder(
          deliveryAddress: address,
          clientName: clientName,
          clientPhone: clientPhone,
          notes: notes,
          amountToCharge: amount,
          valorEnvio: envio,
          paymentMethod: _paymentMethod,
          items: _items,
          cityHint: cityHint,
          fromVentaIds: _selectedVentaIds,
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
            items: _items,
            valorEnvio: envio,
            clearValorEnvio: envio == null,
          ),
          cityHint: cityHint,
          forceRegeocode: cityHint != _cityAtFormOpen,
        );
      }
    } on VentaYaVinculadaException catch (error) {
      // Race lost against another device (design decision D4): the claim
      // was rejected, so NOTHING was saved locally — `createOrder` throws
      // before the first `_repository.save`. A claim earlier in this same
      // batch may have already gone through and stays claimed (D8 — links
      // are never deleted), so there's no partial state to reconcile here:
      // clear every venta-sourced pick/item and let the dueño re-pick from
      // scratch instead of retrying blind against the same failed set.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _selectedVentaIds.clear();
        _ventaFechas.clear();
        _ventaTotales.clear();
        _ventaLocalIds.clear();
        _items.removeWhere((item) => item.sourceVentaId != null);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  /// Groups [_items] into consecutive runs sharing the same
  /// `sourceVentaId` — each run becomes one [_ItemGroup] so the build
  /// method can render one framed block per venta (a manually-added run,
  /// `ventaId == null`, is never grouped visually; each of its items stays
  /// its own row). Preserves each item's original index into [_items] so
  /// increment/decrement/remove callbacks still target the right element.
  List<_ItemGroup> _groupedItems() {
    final groups = <_ItemGroup>[];
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      final last = groups.isEmpty ? null : groups.last;
      if (last != null && last.ventaId == item.sourceVentaId) {
        last.items.add((index: index, item: item));
      } else {
        groups.add(
          _ItemGroup(ventaId: item.sourceVentaId, items: [(index: index, item: item)]),
        );
      }
    }
    return groups;
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// DA4: once a delivery has been marked delivered with a partial payment
  /// (`pendingBalance` recorded), the dueño must not be able to shrink
  /// `amountToCharge` below the still-owed balance from this form — that
  /// would silently make the order look fully paid (or overpaid) without an
  /// actual payment happening. Only applies while editing an order that
  /// already carries a [Order.pendingBalance]; a brand-new order or one
  /// with no recorded partial payment can have its amount edited freely.
  String? _validateAmount(String? value) {
    final pendingBalance = _existing?.pendingBalance;
    if (pendingBalance == null) return null;
    final amount = double.tryParse((value ?? '').trim());
    // Strictly greater, not >= — [Order]'s DA3 invariant requires
    // `pendingBalance < amountToCharge` (a partial payment implies
    // something is still owed); an edit that brings amountToCharge down to
    // exactly the pending balance would leave nothing owed without an
    // actual payment happening, which is just as wrong as going below it.
    if (amount == null || amount <= pendingBalance) {
      return 'El monto no puede ser menor o igual al saldo pendiente de \$$pendingBalance';
    }
    return null;
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
            // "Desde venta" prefill is only offered for a brand-new order —
            // not while editing, where the venta link (if any) was already
            // claimed at creation time and can't be swapped out here.
            if (!isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickVenta,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('Usar venta del POS'),
              ),
            ],
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Productos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              // Venta-sourced lines are grouped into one softly-framed block
              // per factura, with a single delete icon for the whole venta
              // (a venta is one atomic POS sale — there's no partial removal,
              // see `_removeVenta`'s doc comment). Manually-added lines
              // (`sourceVentaId == null`) stay as individual editable rows,
              // rendered in the order they were added relative to the
              // venta groups they're interleaved with.
              for (final group in _groupedItems())
                if (group.ventaId != null)
                  _VentaItemsBlock(
                    ventaLocalId: _ventaLocalIds[group.ventaId],
                    ventaFecha: _ventaFechas[group.ventaId],
                    items: group.items,
                    onRemove: () => _removeVenta(group.ventaId!),
                  )
                else
                  for (final indexedItem in group.items)
                    _OrderItemRow(
                      key: ValueKey('order-item-${indexedItem.index}'),
                      item: indexedItem.item,
                      ventaFecha: null,
                      onIncrement: () => _changeItemQuantity(indexedItem.index, 1),
                      onDecrement: () => _changeItemQuantity(indexedItem.index, -1),
                      onRemove: () => _removeItem(indexedItem.index),
                    ),
            ],
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
                        validator: _validateAmount,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _envioController,
                        decoration: const InputDecoration(
                          labelText: 'Valor de envío',
                          hintText: '-',
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

/// A run of [_items] sharing the same `sourceVentaId` (`null` for a run of
/// manually-added lines) — see `_OrderFormScreenState._groupedItems`.
class _ItemGroup {
  _ItemGroup({required this.ventaId, required this.items});

  final String? ventaId;
  final List<({int index, OrderItem item})> items;
}

/// One venta's product lines, framed together in a single soft card with
/// one delete icon for the whole factura — mirrors the visual language
/// `order_detail_screen.dart`'s `_LinkedVentaTile` already uses for a
/// linked venta (a `Card` with rounded corners, a light tint instead of a
/// heavy border). Unlike that read-only post-creation view, this one is
/// still editable pre-submit: the single [onRemove] un-picks the entire
/// venta (see `_OrderFormScreenState._removeVenta`), never a single line.
class _VentaItemsBlock extends StatelessWidget {
  const _VentaItemsBlock({
    required this.ventaLocalId,
    required this.ventaFecha,
    required this.items,
    required this.onRemove,
  });

  final int? ventaLocalId;
  final DateTime? ventaFecha;
  final List<({int index, OrderItem item})> items;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ventaLocalId != null
                        ? 'Factura Nº $ventaLocalId'
                        : 'Venta del POS',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (ventaFecha != null)
                  Text(
                    _OrderItemRow._formatFechaHora(ventaFecha!),
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Quitar esta venta del pedido',
                  onPressed: onRemove,
                ),
              ],
            ),
            for (final indexedItem in items)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(indexedItem.item.productName),
              ),
          ],
        ),
      ),
    );
  }
}

/// One line item. A manually-typed line (or one carried over from an edit)
/// stays fully editable: quantity via +/- (never a free-text field, so an
/// invalid empty/zero value can't reach [OrdersController.createOrder]) and
/// removable via [onRemove]. A line with `item.sourceVentaId != null`
/// mirrors an actual completed POS sale (`_pickVenta`) — its quantity is an
/// implicit, non-editable value (there's nothing to show or lock: it's
/// simply not a control), so instead of a quantity/lock display it shows
/// when that venta happened ([ventaFecha]) and a single delete icon that
/// (via [onRemove], wired by the caller to `_OrderFormScreenState.
/// _removeVenta`) un-picks the whole venta, not just this line.
class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    required this.ventaFecha,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    super.key,
  });

  final OrderItem item;
  final DateTime? ventaFecha;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final locked = item.sourceVentaId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(item.productName)),
          if (locked) ...[
            if (ventaFecha != null) ...[
              Text(
                _formatFechaHora(ventaFecha!),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Quitar esta venta del pedido',
              onPressed: onRemove,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: item.quantity > 1 ? onDecrement : null,
            ),
            Text('${item.quantity}'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onIncrement,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }

  static String _formatFechaHora(DateTime fecha) {
    final local = fecha.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
