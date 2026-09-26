import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/theme/theme_picker_button.dart';

/// Dashboard: tile aggregati dei moduli MVP (task, eventi, spesa, note).
final class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          const ThemePickerButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Esci',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          try {
            await ref.read(dashboardProvider.future);
          } catch (_) {
            // L'errore è già nello stato del provider (tile con "Riprova"):
            // qui si evita solo l'errore asincrono sciolto del refresh.
          }
        },
        child: ListView(
          // Contenuto corto (stato vuoto/errore): senza questa physics il
          // trascinamento non parte e il refresh non è raggiungibile.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _Greeting(),
            const SizedBox(height: 16),
            dashboard.when(
              loading: () => const _CenteredSpinner(),
              error: (e, _) => _ErrorTile(
                message: 'Impossibile caricare la dashboard.',
                detail: e.toString(),
                onRetry: () {
                  ref.invalidate(dashboardProvider);
                },
              ),
              data: (d) => _DashboardBody(data: d),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final user = state is Authenticated ? state.user : null;
    final locale = Localizations.localeOf(context);
    final today = DateFormat(
      'EEEE d MMMM',
      locale.toString(),
    ).format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ciao${user == null ? '' : ', ${user.displayName}'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(today, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

final class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

final class _ErrorTile extends StatelessWidget {
  const _ErrorTile({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }
}

final class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (data.openTaskCount != null || data.urgentTasks.isNotEmpty)
          _TasksTile(data: data),
        const SizedBox(height: 16),
        if (data.upcomingEvents.isNotEmpty)
          _EventsTile(events: data.upcomingEvents),
        const SizedBox(height: 16),
        if (data.shoppingLists.isNotEmpty || data.shoppingOpenCount != null)
          _ShoppingTile(data: data),
        const SizedBox(height: 16),
        if (data.pinnedNotes.isNotEmpty) _NotesTile(data: data),
        const SizedBox(height: 16),
        if (_allEmpty(data))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Niente in corso.\nCrea task, liste di spesa o note, '
                    'o aggiungi un evento al calendario.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _allEmpty(DashboardData d) =>
      d.openTaskCount == null &&
      d.urgentTasks.isEmpty &&
      d.upcomingEvents.isEmpty &&
      d.shoppingLists.isEmpty &&
      d.shoppingOpenCount == null &&
      d.pinnedNotes.isEmpty;
}

/// Tile "Task": task urgenti + conteggi.
final class _TasksTile extends StatelessWidget {
  const _TasksTile({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TileHeader(
              icon: Icons.task_alt,
              title: 'Task',
              trailing:
                  data.overdueTaskCount != null && data.overdueTaskCount! > 0
                  ? _Badge(label: '${data.overdueTaskCount} overdue')
                  : (data.openTaskCount != null
                        ? _Badge(label: '${data.openTaskCount} aperti')
                        : null),
            ),
            const SizedBox(height: 12),
            if (data.urgentTasks.isEmpty)
              Text(
                'Nessun task urgente.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...data.urgentTasks.take(5).map((t) => _taskRow(context, t)),
          ],
        ),
      ),
    );
  }

  Widget _taskRow(BuildContext context, DashTask task) {
    final due = task.dueDate == null
        ? null
        : '${task.dueDate}${task.dueTime != null ? ' ${task.dueTime}' : ''}';
    return ListTile(
      dense: true,
      leading: _PriorityChip(priority: task.priority),
      title: Text(task.title),
      subtitle: due == null ? null : Text(due),
      trailing: task.assignedName == null ? null : Text(task.assignedName!),
    );
  }
}

/// Tile "Calendario": prossimi eventi.
final class _EventsTile extends StatelessWidget {
  const _EventsTile({required this.events});

  final List<DashEvent> events;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TileHeader(icon: Icons.event, title: 'Prossimi eventi'),
            const SizedBox(height: 12),
            ...events
                .take(5)
                .map(
                  (e) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Icon(
                        Icons.event,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: Text(e.title),
                    subtitle: Text(_formatEvent(e, locale)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _formatEvent(DashEvent e, String locale) {
    if (e.startDatetime == null) return e.location ?? '';
    final dt = DateTime.tryParse(e.startDatetime!);
    if (dt == null) return e.startDatetime!;
    final parts = <String>[];
    parts.add(
      e.allDay
          ? DateFormat('d MMMM', locale).format(dt)
          : DateFormat('d MMMM · HH:mm', locale).format(dt),
    );
    if (e.location != null && e.location!.isNotEmpty) parts.add(e.location!);
    return parts.join(' · ');
  }
}

/// Tile "Spesa": liste con articoli aperti.
final class _ShoppingTile extends StatelessWidget {
  const _ShoppingTile({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TileHeader(
              icon: Icons.shopping_cart,
              title: 'Spesa',
              trailing: data.shoppingOpenCount != null
                  ? _Badge(label: _badgeLabel(data))
                  : null,
            ),
            const SizedBox(height: 12),
            if (data.shoppingLists.isEmpty)
              Text(
                'Nessuna lista con articoli aperti.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...data.shoppingLists
                  .take(3)
                  .map((list) => _shoppingListRow(context, list)),
          ],
        ),
      ),
    );
  }

  /// "2 articoli" (una lista sola) oppure "2 articoli · 3 liste".
  String _badgeLabel(DashboardData data) {
    final articles = data.shoppingOpenCount!;
    final lists = data.shoppingOpenLists;
    if (lists <= 1) return '$articles articoli';
    return '$articles articoli · $lists liste';
  }

  Widget _shoppingListRow(BuildContext context, DashShoppingList list) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(list.name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(
                '${list.openCount}/${list.totalCount} aperti',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (list.items.isNotEmpty)
            Text(
              list.items
                  .take(6)
                  .map(
                    (i) => i.quantity == null
                        ? i.name
                        : '${i.name} (${i.quantity})',
                  )
                  .join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Tile "Note": note pinnate / recenti.
final class _NotesTile extends StatelessWidget {
  const _NotesTile({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TileHeader(
              icon: Icons.sticky_note_2,
              title: 'Note',
              trailing: _Badge(label: '${data.pinnedNotesCount} pinnate'),
            ),
            const SizedBox(height: 12),
            ...data.pinnedNotes
                .take(5)
                .map(
                  (n) => ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.format_quote,
                      color: Theme.of(context).colorScheme.outline,
                      size: 20,
                    ),
                    title: Text(n.title ?? n.content),
                    subtitle: Text(n.authorName ?? ''),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

final class _TileHeader extends StatelessWidget {
  const _TileHeader({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    );
  }
}

final class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 12),
      ),
    );
  }
}

final class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (priority) {
      case 'urgent':
        return scheme.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 10,
      backgroundColor: _color(context),
      child: const Icon(Icons.priority_high, size: 14, color: Colors.white),
    );
  }
}
