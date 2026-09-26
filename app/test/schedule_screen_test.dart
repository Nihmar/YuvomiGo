import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/schedule_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/schedule/schedule_models.dart';
import 'package:yuvomigo/features/schedule/schedule_providers.dart';
import 'package:yuvomigo/features/schedule/schedule_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeScheduleRepository extends ScheduleRepository {
  FakeScheduleRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<(String from, String to)> ranges = [];

  @override
  Future<List<ScheduleEntry>> fetchRange(String from, String to) async {
    ranges.add((from, to));
    final start = DateTime.parse(from);
    final next = DateTime(start.year, start.month, start.day + 1);
    String key(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return [
      ScheduleEntry(
        userId: 1,
        dateKey: from,
        shiftType: const ShiftType(
          id: 1,
          name: 'Mattina',
          startTime: '08:00',
          endTime: '14:00',
          color: '#FF9800',
        ),
      ),
      ScheduleEntry(userId: 2, dateKey: key(next), isFree: true),
    ];
  }

  @override
  Future<List<ScheduleMember>> fetchMembers() async => const [
    ScheduleMember(id: 1, displayName: 'Mario'),
    ScheduleMember(id: 2, displayName: 'Luigi'),
  ];
}

Widget _pump(FakeScheduleRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      scheduleRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: ScheduleScreen()),
  );
}

void main() {
  testWidgets('Schedule screen renders shifts and days off', (tester) async {
    final repo = FakeScheduleRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Mattina'), findsOneWidget);
    expect(find.textContaining('Mario'), findsOneWidget);
    expect(find.textContaining('08:00–14:00'), findsOneWidget);
    expect(find.text('Riposo'), findsOneWidget);
  });

  testWidgets('The next-week button requests another week', (tester) async {
    final repo = FakeScheduleRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();
    final firstFrom = repo.ranges.last.$1;

    await tester.tap(find.byTooltip('Settimana successiva'));
    await tester.pumpAndSettle();

    expect(repo.ranges, hasLength(2));
    expect(
      DateTime.parse(repo.ranges.last.$1).difference(DateTime.parse(firstFrom)),
      const Duration(days: 7),
    );
  });
}
