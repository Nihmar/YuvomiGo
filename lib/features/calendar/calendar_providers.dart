import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/calendar_repository.dart';
import 'package:yuvomigo/features/calendar/calendar_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('CalendarRepository senza sessione attiva');
  return CalendarRepository(api);
});

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

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(calendarRepositoryProvider);
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => repo.fetchRange(_from(), _to()));
    } finally {
      _loading = false;
    }
  }

  String _from() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _to() {
    final end = DateTime.now().add(const Duration(days: 7));
    return '${end.year.toString().padLeft(4, '0')}-'
        '${end.month.toString().padLeft(2, '0')}-'
        '${end.day.toString().padLeft(2, '0')}';
  }
}
