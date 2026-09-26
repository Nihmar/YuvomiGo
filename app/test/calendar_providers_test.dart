import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/calendar_repository.dart';
import 'package:yuvomigo/features/calendar/calendar_models.dart';
import 'package:yuvomigo/features/calendar/calendar_providers.dart';

import 'utils/in_memory_storage.dart';

/// Repository che cattura il range richiesto senza rete.
final class _CapturingCalendarRepository extends CalendarRepository {
  _CapturingCalendarRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  String? from;
  String? to;

  @override
  Future<List<CalendarEvent>> fetchRange(String from, String to) async {
    this.from = from;
    this.to = to;
    return const [];
  }
}

void main() {
  test('the loaded range covers today + the next 6 days', () async {
    final repo = _CapturingCalendarRepository();
    final container = ProviderContainer.test(
      overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
    );

    container.read(calendarEventsProvider);
    await pumpEventQueue();

    expect(repo.from, isNotNull);
    expect(repo.to, isNotNull);
    // `to` è inclusivo: 6 giorni di differenza = finestra di 7 giorni.
    final days = DateTime.parse(repo.to!)
        .difference(DateTime.parse(repo.from!))
        .inDays;
    expect(days, 6);
  });
}
