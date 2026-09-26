import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shell principale: bottom NavigationBar con le 5 tab MVP.
///
/// È il builder della [ShellRoute]: [child] è la tab attiva fornita da
/// go_router (ogni route ha il proprio Scaffold + AppBar). L'indice della tab
/// attiva è tenuto nello state e aggiornato dalla NavigationBar.
final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
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

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Niente AppBar qui: ogni route (tab o detail) ha il proprio AppBar.
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          _index = i;
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
}

final class _Tab {
  const _Tab(this.path, this.icon, this.activeIcon, this.label);

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
