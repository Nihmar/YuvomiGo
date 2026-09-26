import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/reminder_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/reminders/reminder_models.dart';
import 'package:yuvomigo/features/reminders/reminder_providers.dart';
import 'package:yuvomigo/features/reminders/reminders_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeReminderRepository extends ReminderRepository {
  FakeReminderRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<Reminder> reminders = [
    const Reminder(
      id: 1,
      entityType: 'task',
      entityTitle: 'Pagare bolletta',
      remindAt: '2026-09-01T08:00:00Z',
    ),
    const Reminder(
      id: 2,
      entityType: 'waste_pickup',
      entityTitle: 'Plastica',
      remindAt: '2026-09-02T06:00:00Z',
    ),
  ];

  @override
  Future<List<Reminder>> fetchPending() async => reminders.toList();

  @override
  Future<void> dismiss(int id) async {
    reminders.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> deleteReminder(int id) async {
    reminders.removeWhere((r) => r.id == id);
  }
}

Widget _pump(FakeReminderRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      reminderRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: RemindersScreen()),
  );
}

void main() {
  testWidgets('Reminders screen renders title and origin', (tester) async {
    final repo = FakeReminderRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Pagare bolletta'), findsOneWidget);
    expect(find.text('Plastica'), findsOneWidget);
    expect(find.textContaining('Task ·'), findsOneWidget);
    expect(find.textContaining('Rifiuti ·'), findsOneWidget);
  });

  testWidgets('Dismissing a reminder removes it from the list', (tester) async {
    final repo = FakeReminderRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Fatto').first);
    await tester.pumpAndSettle();

    expect(find.text('Pagare bolletta'), findsNothing);
    expect(repo.reminders, hasLength(1));
  });

  testWidgets('Deleting a reminder removes it', (tester) async {
    final repo = FakeReminderRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Elimina').last);
    await tester.pumpAndSettle();

    expect(find.text('Plastica'), findsNothing);
    expect(repo.reminders, hasLength(1));
  });
}
