import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/calendar_repository.dart';
import 'package:yuvomigo/data/repositories/meal_repository.dart';
import 'package:yuvomigo/data/repositories/shopping_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/calendar/calendar_models.dart';
import 'package:yuvomigo/features/calendar/calendar_providers.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/meals/meal_models.dart';
import 'package:yuvomigo/features/meals/meal_providers.dart';
import 'package:yuvomigo/features/shopping/shopping_models.dart';
import 'package:yuvomigo/features/shopping/shopping_providers.dart';
import 'package:yuvomigo/app.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  @override
  Future<List<CalendarEvent>> fetchRange(String from, String to) async => [
    CalendarEvent(
      id: 1,
      title: 'Evento nav',
      startDatetime: '2026-09-01T09:00:00',
    ),
  ];
}

final _sample = DashboardData(
  urgentTasks: [DashTask(id: 10, title: 'Paga bolletta', priority: 'urgent')],
  openTaskCount: 7,
);

final class _FakeMealRepository extends MealRepository {
  _FakeMealRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  @override
  Future<MealWeek> fetchWeek(String week) async => const MealWeek(
    weekStart: '2026-08-31',
    weekEnd: '2026-09-06',
    meals: [Meal(id: 1, date: '2026-09-01', mealType: 'lunch', title: 'Pasta')],
  );
}

final class _FakeShoppingRepository extends ShoppingRepository {
  _FakeShoppingRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  @override
  Future<List<ShoppingList>> fetchLists() async => [
    const ShoppingList(id: 1, name: 'Super'),
  ];

  @override
  Future<List<ShoppingItem>> fetchItems(int listId) async => [
    const ShoppingItem(id: 10, name: 'Latte'),
  ];
}

void main() {
  testWidgets('Home shell shows five tab destinations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations, hasLength(5));
    final labels = navBar.destinations
        .map((d) => (d as NavigationDestination).label)
        .toList();
    expect(
      labels,
      containsAll(['Dashboard', 'Task', 'Spesa', 'Calendario', 'Note']),
    );
  });

  testWidgets('Tapping a tab navigates to the module', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository(),
          ),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // "Calendario" è univoco alla nav (la tile dashboard si intitola "Prossimi eventi").
    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();

    // Il tab Calendario è ora lo screen reale: mostra gli eventi.
    expect(find.text('Evento nav'), findsOneWidget);
  });

  testWidgets('Dashboard tab is the initial location', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // La tile task della dashboard è visibile nella tab iniziale.
    expect(find.text('Paga bolletta'), findsOneWidget);
  });

  testWidgets('A detail route keeps its module tab selected', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
          shoppingRepositoryProvider.overrideWithValue(
            _FakeShoppingRepository(),
          ),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Super'));
    await tester.pumpAndSettle();

    // Siamo su /shopping/1: la tab Spesa (indice 2) resta selezionata.
    expect(find.text('Latte'), findsOneWidget);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 2);
  });

  testWidgets('The settings button opens the settings screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Impostazioni'), findsOneWidget);
    expect(find.text('Utente Test'), findsOneWidget);
  });

  testWidgets('The modules button lists the extra modules', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.apps));
    await tester.pumpAndSettle();

    expect(find.text('Pasti'), findsOneWidget);
    expect(find.text('Compleanni'), findsOneWidget);
    expect(find.text('Promemoria'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Ricette'), findsOneWidget);
    expect(find.text('Inventario'), findsOneWidget);
  });

  testWidgets('A module from the sheet opens its screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
          mealRepositoryProvider.overrideWithValue(_FakeMealRepository()),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.apps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasti'));
    await tester.pumpAndSettle();

    expect(find.text('Pasta'), findsOneWidget);
  });
}
