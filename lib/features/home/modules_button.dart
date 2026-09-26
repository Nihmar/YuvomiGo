import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottone "Altri moduli": apre un foglio con i moduli oltre le 5 tab MVP.
final class ModulesButton extends StatelessWidget {
  const ModulesButton({super.key});

  static const _modules = <({String path, IconData icon, String label})>[
    (path: '/meals', icon: Icons.restaurant_menu, label: 'Pasti'),
    (path: '/birthdays', icon: Icons.cake_outlined, label: 'Compleanni'),
    (
      path: '/reminders',
      icon: Icons.notifications_active_outlined,
      label: 'Promemoria',
    ),
    (
      path: '/budget',
      icon: Icons.account_balance_wallet_outlined,
      label: 'Budget',
    ),
    (path: '/recipes', icon: Icons.menu_book_outlined, label: 'Ricette'),
    (path: '/inventory', icon: Icons.inventory_2_outlined, label: 'Inventario'),
    (path: '/pantry', icon: Icons.kitchen_outlined, label: 'Dispensa'),
  ];

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.apps),
      tooltip: 'Altri moduli',
      onPressed: () => _showModules(context),
    );
  }

  Future<void> _showModules(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Altri moduli',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final module in _modules)
                ListTile(
                  leading: Icon(module.icon),
                  title: Text(module.label),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push(module.path);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
