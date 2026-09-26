import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/shopping/shopping_providers.dart';

/// Dettaglio di una lista di spesa: articoli + azioni.
final class ShoppingListDetailScreen extends ConsumerWidget {
  const ShoppingListDetailScreen({super.key, required this.listId});

  final int listId;

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listId = this.listId;
    final items = ref.watch(shoppingItemsProvider(listId));
    // Nome della lista (arriva dalla tab sotto, già caricata): senza rileggere
    // dal server il dettaglio può intitolarsi come la lista.
    final listName = ref.watch(
      shoppingListsProvider.select((value) {
        final lists = value.value;
        if (lists == null) return null;
        for (final list in lists) {
          if (list.id == listId) return list.name;
        }
        return null;
      }),
    );
    ref.listen<Object?>(shoppingActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(listName ?? 'Articoli')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(shoppingItemsProvider(listId).notifier).refresh(),
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              ErrorRetryTile(
                message: 'Impossibile caricare gli articoli.',
                detail: e.toString(),
                onRetry: () =>
                    ref.read(shoppingItemsProvider(listId).notifier).load(),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: _scrollPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Nessun articolo.\nUsa "Aggiungi" per aggiungerne uno.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: _scrollPhysics,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final label = item.quantity == null || item.quantity!.isEmpty
                    ? item.name
                    : '${item.name} (${item.quantity})';
                return ListTile(
                  leading: Checkbox(
                    value: item.isChecked,
                    onChanged: (v) => ref
                        .read(shoppingItemsProvider(listId).notifier)
                        .toggle(item.id, v ?? false),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      decoration: item.isChecked
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.isChecked
                          ? Theme.of(context).textTheme.bodySmall?.color
                          : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Elimina',
                    onPressed: () => ref
                        .read(shoppingItemsProvider(listId).notifier)
                        .remove(item.id),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _promptForItem(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _promptForItem(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuovo articolo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Quantità (opzionale)',
                hintText: 'es. 2, 500g, 1 confezione',
              ),
              onSubmitted: (_) =>
                  _submit(nameController, qtyController, dialogContext, ref),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () =>
                _submit(nameController, qtyController, dialogContext, ref),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _submit(
    TextEditingController nameController,
    TextEditingController qtyController,
    BuildContext dialogContext,
    WidgetRef ref,
  ) {
    final name = nameController.text.trim();
    final quantity = qtyController.text.trim();
    if (name.isNotEmpty) {
      ref
          .read(shoppingItemsProvider(listId).notifier)
          .add(name, quantity: quantity.isEmpty ? null : quantity);
    }
    Navigator.of(dialogContext).pop();
  }
}
