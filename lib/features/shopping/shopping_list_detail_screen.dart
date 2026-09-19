import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/features/shopping/shopping_providers.dart';

/// Dettaglio di una lista di spesa: articoli + azioni.
final class ShoppingListDetailScreen extends ConsumerWidget {
  const ShoppingListDetailScreen({super.key, required this.listId});

  final int listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listId = this.listId;
    final items = ref.watch(shoppingItemsProvider(listId));

    return Scaffold(
      appBar: AppBar(title: const Text('Articoli')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Impossibile caricare gli articoli.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(e.toString(),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer)),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Nessun articolo.\nUsa "Aggiungi" per aggiungerne uno.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            );
          }
          return ListView.builder(
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
                    decoration:
                        item.isChecked ? TextDecoration.lineThrough : null,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _promptForItem(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _promptForItem(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuovo articolo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome (e quantità)'),
          onSubmitted: (value) => _submit(controller, dialogContext, ref),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => _submit(controller, dialogContext, ref),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _submit(
    TextEditingController controller,
    BuildContext dialogContext,
    WidgetRef ref,
  ) {
    final raw = controller.text.trim();
    if (raw.isNotEmpty) {
      ref.read(shoppingItemsProvider(listId).notifier).add(raw);
    }
    Navigator.of(dialogContext).pop();
  }
}
