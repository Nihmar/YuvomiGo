import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/core/widgets/detail_row.dart';
import 'package:yuvomigo/core/utils/date_utils.dart';
import 'package:yuvomigo/features/inventory/inventory_models.dart';
import 'package:yuvomigo/features/inventory/inventory_providers.dart';

/// Schermata Inventario: oggetti di casa con ricerca, dettaglio e CRUD.
final class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

final class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InventoryItem> _filter(List<InventoryItem> items) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              (item.brand?.toLowerCase().contains(query) ?? false) ||
              (item.model?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inventoryItemsProvider);
    ref.listen<Object?>(inventoryActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Cerca oggetto',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(inventoryItemsProvider.notifier).refresh(),
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare l\'inventario.',
                      detail: e.toString(),
                      onRetry: () =>
                          ref.read(inventoryItemsProvider.notifier).load(),
                    ),
                  ],
                ),
                data: (all) {
                  final list = _filter(all);
                  if (list.isEmpty) {
                    return ListView(
                      physics: _scrollPhysics,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          all.isEmpty
                              ? 'Nessun oggetto in inventario.\nUsa "Aggiungi" per registrarne uno.'
                              : 'Nessun oggetto per "$_query".',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: _scrollPhysics,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(item.name),
                        subtitle: Text(_subtitle(item)),
                        onTap: () => _showDetail(item),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Azioni oggetto',
                          onSelected: (value) {
                            if (value == 'edit') {
                              _InventoryEditorDialog.show(context, item: item);
                            } else if (value == 'delete') {
                              _confirmDelete(item);
                            }
                          },
                          itemBuilder: (menuContext) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Modifica'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Elimina'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _InventoryEditorDialog.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina oggetto'),
        content: Text('Vuoi eliminare "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(inventoryItemsProvider.notifier).remove(item.id);
  }

  String _subtitle(InventoryItem item) {
    final parts = <String>[];
    final model = [
      item.brand,
      item.model,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    if (model.isNotEmpty) parts.add(model);
    if (item.categoryName?.isNotEmpty == true) {
      parts.add(item.categoryName!);
    }
    if (item.locationPath?.isNotEmpty == true) {
      parts.add(item.locationPath!);
    }
    parts.add(inventoryStatusLabel(item.status));
    return parts.join(' · ');
  }

  void _showDetail(InventoryItem item) {
    final locale = Localizations.localeOf(context).toString();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DetailRow(label: 'Categoria', value: item.categoryName),
              DetailRow(label: 'Posizione', value: item.locationPath),
              DetailRow(label: 'Marca', value: item.brand),
              DetailRow(label: 'Modello', value: item.model),
              DetailRow(label: 'Seriale', value: item.serialNumber),
              DetailRow(label: 'Acquistato il', value: item.purchaseDate),
              DetailRow(
                label: 'Prezzo',
                value: item.purchasePrice == null
                    ? null
                    : NumberFormat.currency(
                        locale: locale,
                        name: item.currency ?? 'EUR',
                        decimalDigits: 2,
                      ).format(item.purchasePrice!),
              ),
              DetailRow(label: 'Venditore', value: item.vendor),
              DetailRow(
                label: 'Garanzia',
                value: item.warrantyMonths == null
                    ? null
                    : '${item.warrantyMonths} mesi',
              ),
              DetailRow(
                label: 'Condizione',
                value: inventoryConditionLabel(item.condition),
              ),
              DetailRow(
                label: 'Stato',
                value: inventoryStatusLabel(item.status),
              ),
              if (item.trackedDates.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Date tracciate',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                for (final date in item.trackedDates)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${date.label}: ${date.date}'),
                  ),
              ],
              if (item.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Note',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(item.notes!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog di creazione/modifica di un oggetto.
final class _InventoryEditorDialog extends ConsumerStatefulWidget {
  const _InventoryEditorDialog({this.item});

  final InventoryItem? item;

  static Future<void> show(BuildContext context, {InventoryItem? item}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _InventoryEditorDialog(item: item),
    );
  }

  @override
  ConsumerState<_InventoryEditorDialog> createState() =>
      _InventoryEditorDialogState();
}

final class _InventoryEditorDialogState
    extends ConsumerState<_InventoryEditorDialog> {
  static const _conditions = ['new', 'good', 'fair', 'poor'];
  static const _statuses = ['active', 'sold', 'disposed', 'lost'];

  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _price = TextEditingController();
  final _vendor = TextEditingController();
  final _warranty = TextEditingController();
  final _notes = TextEditingController();
  String? _category;
  int? _locationId;
  DateTime? _purchaseDate;
  String _condition = 'good';
  String _status = 'active';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    _name.text = item.name;
    _brand.text = item.brand ?? '';
    _model.text = item.model ?? '';
    _serial.text = item.serialNumber ?? '';
    _price.text = item.purchasePrice?.toString() ?? '';
    _vendor.text = item.vendor ?? '';
    _warranty.text = item.warrantyMonths?.toString() ?? '';
    _notes.text = item.notes ?? '';
    _category = item.category.isEmpty ? null : item.category;
    _locationId = item.locationId;
    _purchaseDate = DateTime.tryParse(item.purchaseDate ?? '');
    _condition = item.condition;
    _status = item.status;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    _price.dispose();
    _vendor.dispose();
    _warranty.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPurchaseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final category = _category ?? 'other';
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final notifier = ref.read(inventoryItemsProvider.notifier);
    final item = widget.item;
    final success = item == null
        ? await notifier.add(
            name: name,
            brand: _nullIfEmpty(_brand),
            model: _nullIfEmpty(_model),
            serialNumber: _nullIfEmpty(_serial),
            category: category,
            locationId: _locationId,
            purchaseDate: _purchaseDate == null
                ? null
                : dateKey(_purchaseDate!),
            purchasePrice: _parseDouble(_price),
            vendor: _nullIfEmpty(_vendor),
            warrantyMonths: int.tryParse(_warranty.text.trim()),
            condition: _condition,
            status: _status,
            notes: _nullIfEmpty(_notes),
          )
        : await notifier.update(
            item.id,
            name: name,
            brand: _nullIfEmpty(_brand),
            model: _nullIfEmpty(_model),
            serialNumber: _nullIfEmpty(_serial),
            category: category,
            locationId: _locationId,
            purchaseDate: _purchaseDate == null
                ? null
                : dateKey(_purchaseDate!),
            purchasePrice: _parseDouble(_price),
            vendor: _nullIfEmpty(_vendor),
            warrantyMonths: int.tryParse(_warranty.text.trim()),
            condition: _condition,
            status: _status,
            notes: _nullIfEmpty(_notes),
          );
    if (!mounted) return;
    if (!success) {
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }

  String? _nullIfEmpty(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _parseDouble(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : double.tryParse(value);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final categories =
        ref.watch(inventoryCategoriesProvider).value ??
        const <InventoryCategory>[];
    final locations = flattenInventoryLocations(
      ref.watch(inventoryLocationsProvider).value ??
          const <InventoryLocation>[],
    );
    final selectedCategory = categories.any((c) => c.key == _category)
        ? _category
        : null;

    return AlertDialog(
      title: Text(isEdit ? 'Modifica oggetto' : 'Nuovo oggetto'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Altro'),
                  ),
                  for (final category in categories)
                    DropdownMenuItem<String?>(
                      value: category.key,
                      child: Text(category.name),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 12),
              if (locations.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: locations.any((l) => l.id == _locationId)
                      ? _locationId
                      : null,
                  decoration: const InputDecoration(labelText: 'Posizione'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Nessuna'),
                    ),
                    for (final location in locations)
                      DropdownMenuItem<int?>(
                        value: location.id,
                        child: Text(location.label),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _locationId = value),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brand,
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _model,
                      decoration: const InputDecoration(labelText: 'Modello'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serial,
                decoration: const InputDecoration(
                  labelText: 'Numero seriale (opzionale)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickPurchaseDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _purchaseDate == null
                            ? 'Data acquisto'
                            : DateFormat('d MMM yyyy').format(_purchaseDate!),
                      ),
                    ),
                  ),
                  if (_purchaseDate != null)
                    IconButton(
                      tooltip: 'Rimuovi data',
                      icon: const Icon(Icons.clear),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _purchaseDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Prezzo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _vendor,
                      decoration: const InputDecoration(labelText: 'Venditore'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _warranty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Garanzia (mesi, opzionale)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _condition,
                      decoration: const InputDecoration(
                        labelText: 'Condizione',
                      ),
                      items: [
                        for (final condition in _conditions)
                          DropdownMenuItem(
                            value: condition,
                            child: Text(inventoryConditionLabel(condition)),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _condition = value ?? 'good'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Stato'),
                      items: [
                        for (final status in _statuses)
                          DropdownMenuItem(
                            value: status,
                            child: Text(inventoryStatusLabel(status)),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _status = value ?? 'active'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }
}
