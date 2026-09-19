import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/app.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/auth/login_screen.dart';
import 'package:yuvomigo/features/auth/server_settings.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeAuthController controller, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: const YuvomiGoApp(),
    ),
  );
  if (settle) {
    // Aspetta che il router applichi il redirect e renda lo screen.
    await tester.pumpAndSettle();
  } else {
    // Per stati con animazione continua (es. splash) non si può settare:
    // lascio correre i frame necessari al redirect iniziale.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

void main() {
  testWidgets('Login screen shows url, username, password fields', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeAuthController(const AuthUnauthenticated()),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('URL server'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Accedi'), findsOneWidget);
  });

  testWidgets('Empty submit shows validation errors and does not login', (
    tester,
  ) async {
    final controller = FakeAuthController(const AuthUnauthenticated());
    await _pump(tester, controller);

    await tester.tap(find.text('Accedi'));
    await tester.pumpAndSettle();

    expect(find.text('Inserisci l\'URL del server.'), findsOneWidget);
    expect(find.text('Inserisci l\'username.'), findsOneWidget);
    expect(find.text('Inserisci la password.'), findsOneWidget);
    expect(controller.loginCalled, isFalse);
  });

  testWidgets('Valid submit logs in and navigates to home', (tester) async {
    final controller = FakeAuthController(const AuthUnauthenticated());
    await _pump(tester, controller);

    // I campi sono EditableText (le label non sono i campi stessi).
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'http://omvnas:4000');
    await tester.enterText(fields.at(1), 'test');
    await tester.enterText(fields.at(2), 'secret');
    await tester.tap(find.text('Accedi'));
    await tester.pumpAndSettle();

    expect(controller.loginCalled, isTrue);
    expect(controller.lastServerUrl, 'http://omvnas:4000');
    expect(controller.lastUsername, 'test');
    expect(controller.lastPassword, 'secret');
    // Il router ha portato a Home: il login screen non c'è più.
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('AuthLoading shows splash (not login)', (tester) async {
    await _pump(tester, FakeAuthController(const AuthLoading()), settle: false);

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('URL field is pre-filled from the last login', (tester) async {
    final storage = InMemoryStorage();
    storage.data['yuvomi.lastServerUrl'] = 'http://omvnas:4000';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(const AuthUnauthenticated()),
          ),
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: const YuvomiGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(TextField).first;
    expect(
      (tester.widget<TextField>(field)).controller?.text,
      'http://omvnas:4000',
    );
  });

  group('ServerUrlMemory', () {
    test('remember persists and read returns it', () async {
      final storage = InMemoryStorage();
      final memory = ServerUrlMemory(storage);
      expect(await memory.read(), isNull);
      await memory.remember('http://omvnas:4000');
      expect(await memory.read(), 'http://omvnas:4000');
    });
  });
}
