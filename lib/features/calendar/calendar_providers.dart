import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/calendar_repository.dart';
import 'package:yuvomigo/features/calendar/calendar_models.dart';
import 'package:yuvomigo/core/utils/date_utils.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('CalendarRepository senza sessione attiva');
  return CalendarRepository(api);
});

/// Ultimo errore di un refresh con dati validi a schermo (SnackBar).
final calendarActionErrorProvider =
    NotifierProvider<CalendarActionErrorNotifier, Object?>(
      CalendarActionErrorNotifier.new,
    );

final class CalendarActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

final calendarEventsProvider =
    NotifierProvider.autoDispose<
      CalendarEventsNotifier,
      AsyncValue<List<CalendarEvent>>
    >(CalendarEventsNotifier.new);

final class CalendarEventsNotifier
    extends Notifier<AsyncValue<List<CalendarEvent>>> {
  bool _loading = false;

  @override
  AsyncValue<List<CalendarEvent>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo gli eventi correnti (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(calendarRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final events = await repo.fetchRange(_from(), _to());
      if (!ref.mounted) return;
      state = AsyncData(events);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(calendarActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  String _from() {
    final now = DateTime.now();
    return dateKey(now);
  }

  /// Oggi + 6 giorni: `to` è inclusivo, così la finestra copre esattamente
  /// 7 giorni (oggi compreso), come dice la UI.
  String _to() {
    final end = DateTime.now().add(const Duration(days: 6));
    return dateKey(end);
  }
}
