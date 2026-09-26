import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/inventory/inventory_models.dart';
import 'package:yuvomigo/features/inventory/inventory_providers.dart';

/// Schermata Inventario: oggetti di casa con ricerca e dettaglio.
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
              onRefresh: () async {
                ref.invalidate(inventoryItemsProvider);
                try {
                  await ref.read(inventoryItemsProvider.future);
                } catch (_) {
                  // L'errore è già nello stato del provider.
                }
              },
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare l\'inventario.',
                      detail: e.toString(),
                      onRetry: () => ref.invalidate(inventoryItemsProvider),
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
                              ? 'Nessun oggetto in inventario.'
                              : 'Nessun oggetto per "$_query".',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: _scrollPhysics,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(item.name),
                        subtitle: Text(_subtitle(item)),
                        onTap: () => _showDetail(item),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
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
              _DetailRow(label: 'Categoria', value: item.categoryName),
              _DetailRow(label: 'Posizione', value: item.locationPath),
              _DetailRow(label: 'Marca', value: item.brand),
              _DetailRow(label: 'Modello', value: item.model),
              _DetailRow(label: 'Seriale', value: item.serialNumber),
              _DetailRow(label: 'Acquistato il', value: item.purchaseDate),
              _DetailRow(
                label: 'Prezzo',
                value: item.purchasePrice == null
                    ? null
                    : NumberFormat.currency(
                        locale: locale,
                        name: item.currency ?? 'EUR',
                        decimalDigits: 2,
                      ).format(item.purchasePrice!),
              ),
              _DetailRow(label: 'Venditore', value: item.vendor),
              _DetailRow(
                label: 'Garanzia',
                value: item.warrantyMonths == null
                    ? null
                    : '${item.warrantyMonths} mesi',
              ),
              _DetailRow(
                label: 'Condizione',
                value: inventoryConditionLabel(item.condition),
              ),
              _DetailRow(
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

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}
