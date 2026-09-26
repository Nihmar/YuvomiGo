import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/birthday_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/birthdays/birthday_models.dart';
import 'package:yuvomigo/features/birthdays/birthday_providers.dart';
import 'package:yuvomigo/features/birthdays/birthdays_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeBirthdayRepository extends BirthdayRepository {
  FakeBirthdayRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<Birthday> birthdays = [
    const Birthday(
      id: 1,
      name: 'Marco',
      birthDate: '2015-06-01',
      daysUntil: 0,
      nextAge: 11,
    ),
    const Birthday(
      id: 2,
      name: 'Zia',
      birthDate: '1980-01-01',
      daysUntil: 5,
      nextAge: 46,
    ),
  ];
  int _nextId = 100;

  @override
  Future<List<Birthday>> fetchBirthdays() async {
    final list = [...birthdays]..sort(compareBirthdays);
    return list;
  }

  @override
  Future<Birthday> createBirthday({
    required String name,
    required String birthDate,
    String? notes,
  }) async {
    final birthday = Birthday(
      id: _nextId++,
      name: name,
      birthDate: birthDate,
      notes: notes,
      daysUntil: 10,
    );
    birthdays.add(birthday);
    return birthday;
  }

  @override
  Future<Birthday> updateBirthday(
    int id, {
    required String name,
    required String birthDate,
    String? notes,
  }) async {
    final index = birthdays.indexWhere((b) => b.id == id);
    final updated = Birthday(
      id: id,
      name: name,
      birthDate: birthDate,
      notes: notes,
      daysUntil: birthdays[index].daysUntil,
      nextAge: birthdays[index].nextAge,
    );
    birthdays[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteBirthday(int id) async {
    birthdays.removeWhere((b) => b.id == id);
  }
}

Widget _pump(FakeBirthdayRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      birthdayRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: BirthdaysScreen()),
  );
}

void main() {
  testWidgets('Birthdays screen renders countdowns', (tester) async {
    final repo = FakeBirthdayRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Marco'), findsOneWidget);
    expect(find.text('Zia'), findsOneWidget);
    expect(find.textContaining('oggi'), findsOneWidget);
    expect(find.textContaining('tra 5 giorni'), findsOneWidget);
    expect(find.textContaining('compie 11'), findsOneWidget);
  });

  testWidgets('Creating a birthday adds it', (tester) async {
    final repo = FakeBirthdayRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luca');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Luca'), findsOneWidget);
    expect(repo.birthdays.map((b) => b.name), contains('Luca'));
  });

  testWidgets('Editing a birthday updates it', (tester) async {
    final repo = FakeBirthdayRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marco'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Marco Antonio');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Marco Antonio'), findsOneWidget);
    expect(repo.birthdays.map((b) => b.name), contains('Marco Antonio'));
  });

  testWidgets('Deleting a birthday removes it', (tester) async {
    final repo = FakeBirthdayRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(find.text('Marco'), findsNothing);
    expect(repo.birthdays, hasLength(1));
  });
}
