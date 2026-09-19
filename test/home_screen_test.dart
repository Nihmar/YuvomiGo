import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/app.dart';

import 'utils/fake_auth_controller.dart';

final _sample = DashboardData(
  urgentTasks: [
    DashTask(id: 10, title: 'Paga bolletta', priority: 'urgent'),
  ],
  openTaskCount: 7,
);

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

    final navBar =
        tester.widget<NavigationBar>(find.byType(NavigationBar));
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
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // "Calendario" è univoco alla nav (la tile dashboard si intitola "Prossimi eventi").
    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();

    expect(find.text('Vista mese/settimana, eventi e creazione. In arrivo in M2.'),
        findsOneWidget);
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
}
