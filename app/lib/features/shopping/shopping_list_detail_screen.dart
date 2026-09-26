import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/shopping/shopping_models.dart';
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
    final categories =
        ref.watch(shoppingCategoriesProvider).value ??
        const <ShoppingCategory>[];
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
        onPressed: () => _AddItemDialog.show(
          context,
          listId: listId,
          categories: categories,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog per aggiungere un articolo: nome + quantità + categoria.
final class _AddItemDialog extends ConsumerStatefulWidget {
  const _AddItemDialog({required this.listId, required this.categories});

  final int listId;
  final List<ShoppingCategory> categories;

  static Future<void> show(
    BuildContext context, {
    required int listId,
    required List<ShoppingCategory> categories,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _AddItemDialog(listId: listId, categories: categories),
    );
  }

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

final class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  String? _category;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final quantity = _quantity.text.trim();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final success = await ref
        .read(shoppingItemsProvider(widget.listId).notifier)
        .add(
          name,
          quantity: quantity.isEmpty ? null : quantity,
          category: _category,
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
      title: const Text('Nuovo articolo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            decoration: const InputDecoration(
              labelText: 'Quantità (opzionale)',
              hintText: 'es. 2, 500g, 1 confezione',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Categoria (opzionale)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Predefinita'),
                ),
                for (final category in widget.categories)
                  DropdownMenuItem<String?>(
                    value: category.name,
                    child: Text(category.name),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _category = value),
            ),
          ],
        ],
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
              : const Text('Aggiungi'),
        ),
      ],
    );
  }
}
