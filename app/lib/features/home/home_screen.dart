import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shell principale: bottom NavigationBar con le 5 tab MVP.
///
/// È il builder della [ShellRoute]: [child] è la tab attiva fornita da
/// go_router. L'indice selezionato è derivato da [currentPath], così resta
/// corretto anche quando la route cambia senza un tap sulla barra (redirect
/// dopo un 401, deep link, `router.go`).
final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  static const _tabs = [
    _Tab('/dashboard', Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _Tab('/tasks', Icons.task_alt_outlined, Icons.task_alt, 'Task'),
    _Tab(
      '/shopping',
      Icons.shopping_cart_outlined,
      Icons.shopping_cart,
      'Spesa',
    ),
    _Tab(
      '/calendar',
      Icons.calendar_month_outlined,
      Icons.calendar_month,
      'Calendario',
    ),
    _Tab('/notes', Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'Note'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _indexFor(currentPath);
    return Scaffold(
      // Niente AppBar qui: ogni route (tab o detail) ha il proprio AppBar.
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == index) return;
          GoRouter.of(context).go(_tabs[i].path);
        },
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }

  /// Indice della tab a cui appartiene [path] (le sotto-route, es.
  /// `/shopping/1`, restano sulla tab del modulo). Fallback: Dashboard.
  static int _indexFor(String path) {
    for (var i = 0; i < _tabs.length; i++) {
      final tabPath = _tabs[i].path;
      if (path == tabPath || path.startsWith('$tabPath/')) return i;
    }
    return 0;
  }
}

final class _Tab {
  const _Tab(this.path, this.icon, this.activeIcon, this.label);

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
