import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/pantry/pantry_models.dart';
import 'package:yuvomigo/features/pantry/pantry_providers.dart';

/// Schermata Dispensa: scorte con quantità, scadenze e scorte minime.
final class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantry = ref.watch(pantryProvider);
    ref.listen<Object?>(pantryActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Dispensa')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pantryProvider.notifier).refresh(),
        child: pantry.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              ErrorRetryTile(
                message: 'Impossibile caricare la dispensa.',
                detail: e.toString(),
                onRetry: () => ref.read(pantryProvider.notifier).load(),
              ),
            ],
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return ListView(
                physics: _scrollPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Dispensa vuota.\nUsa "Aggiungi" per registrare un articolo.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: _scrollPhysics,
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: data.items.length,
              itemBuilder: (context, index) {
                final item = data.items[index];
                return ListTile(
                  leading: const Icon(Icons.kitchen_outlined),
                  title: Text(item.name),
                  subtitle: Text(_subtitle(context, item)),
                  onTap: () => _PantryEditorDialog.show(
                    context,
                    item: item,
                    locations: data.locations,
                    categories: data.categories,
                  ),
                  trailing: IconButton(
                    tooltip: 'Elimina',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(pantryProvider.notifier).remove(item.id),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final data = pantry.value;
          return FloatingActionButton(
            onPressed: () => _PantryEditorDialog.show(
              context,
              locations: data?.locations ?? const [],
              categories: data?.categories ?? const [],
            ),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  String _subtitle(BuildContext context, PantryItem item) {
    final parts = <String>[
      '${pantryQuantityLabel(item.quantity)} ${pantryUnitLabel(item.unit)}',
    ];
    if (item.locationName?.isNotEmpty == true) parts.add(item.locationName!);
    if (item.category.isNotEmpty) parts.add(item.category);
    if (item.isLowStock) parts.add('scorta minima');
    if (item.expiresOn?.isNotEmpty == true) {
      final expiry = DateTime.tryParse(item.expiresOn!);
      if (expiry != null) {
        final today = DateTime.now();
        final days = expiry
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
        if (days < 0) {
          parts.add('scaduto');
        } else if (days == 0) {
          parts.add('scade oggi');
        } else if (days <= 7) {
          parts.add('scade tra $days g');
        } else {
          parts.add('scade ${DateFormat('d MMM').format(expiry)}');
        }
      }
    }
    return parts.join(' · ');
  }
}

/// Dialog per creare/modificare un articolo della dispensa.
final class _PantryEditorDialog extends ConsumerStatefulWidget {
  const _PantryEditorDialog({
    required this.locations,
    required this.categories,
    this.item,
  });

  final List<PantryLocation> locations;
  final List<String> categories;
  final PantryItem? item;

  static Future<void> show(
    BuildContext context, {
    required List<PantryLocation> locations,
    required List<String> categories,
    PantryItem? item,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _PantryEditorDialog(
        locations: locations,
        categories: categories,
        item: item,
      ),
    );
  }

  @override
  ConsumerState<_PantryEditorDialog> createState() =>
      _PantryEditorDialogState();
}

final class _PantryEditorDialogState
    extends ConsumerState<_PantryEditorDialog> {
  static const _units = [
    'pcs',
    'g',
    'kg',
    'ml',
    'l',
    'pkg',
    'can',
    'bottle',
    'jar',
    'bag',
  ];

  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _minQuantity = TextEditingController();
  String _unit = 'pcs';
  int? _locationId;
  String? _category;
  DateTime? _expiresOn;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    _name.text = item.name;
    _quantity.text = pantryQuantityLabel(item.quantity);
    _minQuantity.text = item.minQuantity == null
        ? ''
        : pantryQuantityLabel(item.minQuantity!);
    _unit = item.unit;
    _locationId = item.locationId;
    _category = item.category.isEmpty ? null : item.category;
    _expiresOn = DateTime.tryParse(item.expiresOn ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _minQuantity.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresOn ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() => _expiresOn = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final notifier = ref.read(pantryProvider.notifier);
    final item = widget.item;
    final success = item == null
        ? await notifier.add(
            name: name,
            quantity: double.tryParse(_quantity.text.replaceAll(',', '.')),
            unit: _unit,
            locationId: _locationId,
            category: _category,
            expiresOn: _expiresOn == null ? null : _dateKey(_expiresOn!),
            minQuantity: double.tryParse(
              _minQuantity.text.replaceAll(',', '.'),
            ),
          )
        : await notifier.update(
            item.id,
            name: name,
            quantity: double.tryParse(_quantity.text.replaceAll(',', '.')),
            unit: _unit,
            locationId: _locationId,
            category: _category,
            expiresOn: _expiresOn == null ? null : _dateKey(_expiresOn!),
            minQuantity: double.tryParse(
              _minQuantity.text.replaceAll(',', '.'),
            ),
          );
    if (!mounted) return;
    if (!success) {
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Nuovo articolo' : 'Modifica articolo'),
      content: SingleChildScrollView(
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantità'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unità'),
                    items: [
                      for (final unit in _units)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(pantryUnitLabel(unit)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _unit = value ?? 'pcs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.locations.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: _locationId,
                decoration: const InputDecoration(labelText: 'Posizione'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Nessuno'),
                  ),
                  for (final location in widget.locations)
                    DropdownMenuItem<int?>(
                      value: location.id,
                      child: Text(location.name),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _locationId = value),
              ),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nessuna'),
                  ),
                  for (final category in widget.categories)
                    DropdownMenuItem<String?>(
                      value: category,
                      child: Text(category),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _category = value),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickExpiry,
                    icon: const Icon(Icons.event),
                    label: Text(
                      _expiresOn == null
                          ? 'Scadenza'
                          : DateFormat('d MMM yyyy').format(_expiresOn!),
                    ),
                  ),
                ),
                if (_expiresOn != null)
                  IconButton(
                    tooltip: 'Rimuovi scadenza',
                    icon: const Icon(Icons.clear),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _expiresOn = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minQuantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Scorta minima (opzionale)',
              ),
            ),
          ],
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
              : Text(widget.item == null ? 'Aggiungi' : 'Salva'),
        ),
      ],
    );
  }
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
