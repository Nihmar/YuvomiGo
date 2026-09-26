import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/calendar/calendar_models.dart';
import 'package:yuvomigo/features/calendar/calendar_providers.dart';
import 'package:yuvomigo/features/settings/settings_button.dart';

/// Tab Calendario: eventi prossimi 7 giorni (read-only, MVP).
final class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    ref.listen<Object?>(calendarActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aggiornamento non riuscito: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: const [SettingsButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(calendarEventsProvider.notifier).refresh(),
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              ErrorRetryTile(
                message: 'Impossibile caricare il calendario.',
                detail: e.toString(),
                onRetry: () => ref.read(calendarEventsProvider.notifier).load(),
              ),
            ],
          ),
          data: (events) {
            if (events.isEmpty) {
              return ListView(
                physics: _scrollPhysics,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Nessun evento nei prossimi 7 giorni.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            }
            final groups = _groupByDay(events);
            return ListView(
              physics: _scrollPhysics,
              padding: const EdgeInsets.all(12),
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final event in entry.value)
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(event.title),
                      subtitle: Text(
                        event.allDay ? '' : _timeOf(event.startDatetime),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Raggruppa gli eventi per giorno locale (chiave 'YYYY-MM-DD').
///
/// La `start_datetime` può essere wall-time locale oppure un instant con
/// zona (`Z`/offset) per i calendari sincronizzati: il giorno mostrato è
/// quello del fuso dell'utente, non quello della stringa.
Map<String, List<CalendarEvent>> _groupByDay(List<CalendarEvent> events) {
  final groups = <String, List<CalendarEvent>>{};
  for (final e in events) {
    final dt = _parseLocal(e.startDatetime);
    final date = dt == null ? 's.d.' : _dateKey(dt);
    groups.putIfAbsent(date, () => []).add(e);
  }
  return groups;
}

String _dateKey(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

DateTime? _parseLocal(String iso) {
  if (iso.isEmpty) return null;
  return DateTime.tryParse(iso)?.toLocal();
}

String _timeOf(String iso) {
  final parsed = _parseLocal(iso);
  if (parsed == null) return '';
  final h = parsed.hour.toString().padLeft(2, '0');
  final m = parsed.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
