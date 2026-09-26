import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/meal_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/meals/meal_models.dart';
import 'package:yuvomigo/features/meals/meal_providers.dart';
import 'package:yuvomigo/features/meals/meals_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakeMealRepository extends MealRepository {
  FakeMealRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  final List<String> requestedWeeks = [];
  MealWeek response = const MealWeek(
    weekStart: '2026-08-31',
    weekEnd: '2026-09-06',
    meals: [
      Meal(id: 1, date: '2026-09-01', mealType: 'lunch', title: 'Pasta'),
      Meal(id: 2, date: '2026-09-02', mealType: 'dinner', title: 'Zuppa'),
    ],
  );
  int _nextId = 100;

  @override
  Future<MealWeek> fetchWeek(String week) async {
    requestedWeeks.add(week);
    return response;
  }

  @override
  Future<Meal> createMeal({
    required String date,
    required String mealType,
    required String title,
    String? notes,
  }) async {
    final meal = Meal(
      id: _nextId++,
      date: date,
      mealType: mealType,
      title: title,
      notes: notes,
    );
    response = MealWeek(
      weekStart: response.weekStart,
      weekEnd: response.weekEnd,
      meals: [...response.meals, meal],
    );
    return meal;
  }

  @override
  Future<void> deleteMeal(int id) async {
    response = MealWeek(
      weekStart: response.weekStart,
      weekEnd: response.weekEnd,
      meals: response.meals.where((m) => m.id != id).toList(),
    );
  }
}

Widget _pump(FakeMealRepository repo) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      mealRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: MealsScreen()),
  );
}

void main() {
  testWidgets('Meals screen renders the week grouped by day', (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Zuppa'), findsOneWidget);
    expect(find.text('Pranzo'), findsOneWidget);
    expect(find.text('Cena'), findsOneWidget);
  });

  testWidgets('Creating a meal reloads the week', (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Risotto');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.text('Risotto'), findsOneWidget);
    expect(repo.response.meals.map((m) => m.title), contains('Risotto'));
  });

  testWidgets('Deleting a meal removes it', (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Pasta'), findsNothing);
    expect(find.text('Zuppa'), findsOneWidget);
  });

  testWidgets('The next-week button requests another week', (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_pump(repo));
    await tester.pumpAndSettle();
    final firstWeek = repo.requestedWeeks.last;

    await tester.tap(find.byTooltip('Settimana successiva'));
    await tester.pumpAndSettle();

    expect(repo.requestedWeeks, hasLength(2));
    expect(
      DateTime.parse(repo.requestedWeeks.last)
          .difference(DateTime.parse(firstWeek)),
      const Duration(days: 7),
    );
  });
}
