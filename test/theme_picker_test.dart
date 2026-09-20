import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/dashboard/dashboard_screen.dart';
import 'package:yuvomigo/features/theme/theme_controller.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

Future<void> _pumpDashboard(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Authenticated(user: fakeUser())),
      ),
      dashboardProvider.overrideWithValue(const AsyncData(DashboardData())),
      secureStorageProvider.overrideWithValue(InMemoryStorage()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('Theme button opens the picker dialog', (tester) async {
    await _pumpDashboard(tester, _container());

    await tester.tap(find.byTooltip('Cambia tema'));
    await tester.pumpAndSettle();

    expect(find.text('Scegli il colore'), findsOneWidget);
    for (final name in ['Arancione', 'Blu', 'Verde', 'Viola', 'Teal', 'Rosa']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('Picking a color updates the theme state', (tester) async {
    final container = _container();
    await _pumpDashboard(tester, container);

    await tester.tap(find.byTooltip('Cambia tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blu'));
    await tester.pumpAndSettle();

    // Il dialogo si chiude e il seed attivo è quello scelto.
    expect(find.text('Scegli il colore'), findsNothing);
    expect(container.read(themeControllerProvider), 0xFF2196F3);
  });
}
