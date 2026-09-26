import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/reminders/reminder_models.dart';
import 'package:yuvomigo/features/reminders/reminder_providers.dart';

/// Schermata Promemoria: quelli in scadenza, con "fatto" ed elimina.
final class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    ref.listen<Object?>(remindersActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Promemoria')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(remindersProvider.notifier).refresh(),
        child: reminders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              ErrorRetryTile(
                message: 'Impossibile caricare i promemoria.',
                detail: e.toString(),
                onRetry: () => ref.read(remindersProvider.notifier).load(),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: _scrollPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Nessun promemoria in scadenza.',
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
                final reminder = list[index];
                return ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(
                    reminder.entityTitle?.isNotEmpty == true
                        ? reminder.entityTitle!
                        : reminderOriginLabel(reminder.entityType),
                  ),
                  subtitle: Text(_subtitle(context, reminder)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fatto',
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () => ref
                            .read(remindersProvider.notifier)
                            .dismiss(reminder.id),
                      ),
                      IconButton(
                        tooltip: 'Elimina',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(remindersProvider.notifier)
                            .remove(reminder.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _subtitle(BuildContext context, Reminder reminder) {
    final locale = Localizations.localeOf(context).toString();
    final when = DateTime.tryParse(reminder.remindAt)?.toLocal();
    final time = when == null
        ? reminder.remindAt
        : DateFormat('d MMM, HH:mm', locale).format(when);
    final origin = reminderOriginLabel(reminder.entityType);
    return '$origin · $time';
  }
}
