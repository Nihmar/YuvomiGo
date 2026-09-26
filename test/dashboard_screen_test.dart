import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/dashboard/dashboard_screen.dart';

import 'utils/fake_auth_controller.dart';

final _sample = DashboardData(
  upcomingEvents: [
    DashEvent(id: 1, title: 'Riunione', startDatetime: '2026-09-20T10:00:00'),
  ],
  urgentTasks: [
    DashTask(
      id: 10,
      title: 'Paga bolletta',
      priority: 'urgent',
      dueDate: '2026-09-20',
    ),
  ],
  openTaskCount: 7,
  overdueTaskCount: 2,
  pinnedNotes: [
    DashNote(id: 20, title: 'WIFI', content: 'password', pinned: true),
  ],
  pinnedNotesCount: 1,
  shoppingLists: [
    DashShoppingList(
      id: 30,
      name: 'Supermarket',
      openCount: 2,
      totalCount: 5,
      items: [
        DashShoppingItem(id: 31, name: 'Latte', quantity: '2'),
        DashShoppingItem(id: 32, name: 'Pane'),
      ],
    ),
  ],
  shoppingOpenCount: 2,
  shoppingOpenLists: 1,
);

void main() {
  testWidgets('Dashboard renders the five module tiles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(AsyncData(_sample)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Task
    expect(find.text('Paga bolletta'), findsOneWidget);
    expect(find.text('2 overdue'), findsOneWidget);
    // Calendario
    expect(find.text('Riunione'), findsOneWidget);
    // Spesa
    expect(find.text('Supermarket'), findsOneWidget);
    expect(find.textContaining('Latte (2)'), findsOneWidget);
    // Note
    expect(find.text('WIFI'), findsOneWidget);
    // Spesa: una sola lista con articoli aperti → niente conteggio liste.
    expect(find.text('2 articoli'), findsOneWidget);
  });

  testWidgets('Shopping badge shows the list count when more than one', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(
            const AsyncData(
              DashboardData(shoppingOpenCount: 5, shoppingOpenLists: 3),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5 articoli · 3 liste'), findsOneWidget);
  });

  testWidgets('Dashboard shows empty state when there is no data', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(const AsyncData(DashboardData())),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Niente in corso'), findsOneWidget);
  });

  testWidgets('Dashboard list is always scrollable for pull-to-refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(const AsyncData(DashboardData())),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('Dashboard shows error tile with retry on failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(Authenticated(user: fakeUser())),
          ),
          dashboardProvider.overrideWithValue(
            const AsyncError('boom', StackTrace.empty),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impossibile caricare la dashboard.'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
  });
}
