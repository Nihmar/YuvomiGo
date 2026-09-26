import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/calendar_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/calendar/calendar_models.dart';
import 'package:yuvomigo/features/calendar/calendar_providers.dart';
import 'package:yuvomigo/features/calendar/calendar_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeCalendarRepository extends CalendarRepository {
  FakeCalendarRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<CalendarEvent> events = [
    CalendarEvent(
      id: 1,
      title: 'Dentista',
      startDatetime: '2026-09-01T09:30:00',
    ),
    CalendarEvent(
      id: 2,
      title: 'Festa',
      startDatetime: '2026-09-02T00:00:00',
      allDay: true,
    ),
  ];

  @override
  Future<List<CalendarEvent>> fetchRange(String from, String to) async =>
      events.toList();
}

Widget _pump(Widget child, FakeCalendarRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      calendarRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Calendar screen renders events grouped by day', (tester) async {
    final repo = FakeCalendarRepository();
    await tester.pumpWidget(_pump(const CalendarScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsOneWidget);
    expect(find.text('Festa'), findsOneWidget);
    // Il gruppo 2026-09-01 mostra l'ora 09:30.
    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('Empty range shows the empty state', (tester) async {
    final repo = FakeCalendarRepository()..events.clear();
    await tester.pumpWidget(_pump(const CalendarScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Nessun evento nei prossimi 7 giorni.'), findsOneWidget);
  });

  testWidgets('UTC events are shown in local time', (tester) async {
    final repo = FakeCalendarRepository();
    const iso = '2026-09-01T22:30:00Z';
    repo.events
      ..clear()
      ..add(CalendarEvent(id: 3, title: 'Chiamata', startDatetime: iso));

    await tester.pumpWidget(_pump(const CalendarScreen(), repo));
    await tester.pumpAndSettle();

    final local = DateTime.parse(iso).toLocal();
    final expected =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    expect(find.text('Chiamata'), findsOneWidget);
    expect(find.text(expected), findsOneWidget);
  });
}
