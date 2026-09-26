import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yuvomigo/features/shopping/shopping_providers.dart';

/// Tab Spesa: le liste di spesa + creazione.
final class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

final class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(shoppingListsProvider);
    ref.listen<Object?>(shoppingActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Spesa')),
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorTile(
          detail: e.toString(),
          onRetry: () => ref.read(shoppingListsProvider.notifier).load(),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Nessuna lista di spesa.\nUsa "Aggiungi" per crearne una.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.shopping_cart,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(list.name),
                subtitle: Text(
                  '${list.openCount} aperti · ${list.itemChecked}/${list.itemTotal} spuntati',
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Azioni lista',
                  onSelected: (value) {
                    if (value == 'rename') {
                      _promptForRename(context, list.id, list.name);
                    } else if (value == 'delete') {
                      _confirmDelete(context, list.id, list.name);
                    }
                  },
                  itemBuilder: (menuContext) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Rinomina'),
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
                onTap: () => context.push('/shopping/${list.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _promptForName(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _promptForName(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuova lista di spesa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (value) {
            _submit(controller, dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => _submit(controller, dialogContext),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _submit(TextEditingController controller, BuildContext dialogContext) {
    final name = controller.text.trim();
    if (name.isNotEmpty) {
      ref.read(shoppingListsProvider.notifier).add(name);
    }
    Navigator.of(dialogContext).pop();
  }

  void _promptForRename(BuildContext context, int listId, String current) {
    final controller = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rinomina lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              ref.read(shoppingListsProvider.notifier).rename(listId, name);
            }
            Navigator.of(dialogContext).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(shoppingListsProvider.notifier).rename(listId, name);
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int listId, String name) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina lista'),
        content: Text('Vuoi eliminare la lista "$name" e i suoi articoli?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(shoppingListsProvider.notifier).remove(listId);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

final class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.detail, required this.onRetry});

  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impossibile caricare le liste.',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(detail, style: TextStyle(color: scheme.onErrorContainer)),
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Riprova')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
