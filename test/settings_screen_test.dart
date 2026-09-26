import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/settings/settings_screen.dart';

import 'utils/fake_auth_controller.dart';

void main() {
  testWidgets('Settings shows the profile and logs out after confirmation', (
    tester,
  ) async {
    final controller = FakeAuthController(Authenticated(user: fakeUser()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => controller)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Utente Test'), findsOneWidget);
    expect(find.textContaining('test · admin'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Colore tema'), findsOneWidget);

    await tester.tap(find.text('Esci'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vuoi uscire'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Esci'));
    await tester.pumpAndSettle();

    expect(controller.logoutCalled, isTrue);
  });
}
