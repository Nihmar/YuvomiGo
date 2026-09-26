import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/app.dart';
import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/auth/login_screen.dart';

import 'utils/in_memory_storage.dart';

/// Fake con il timing del controller reale su rete vera: emette AuthLoading,
/// attende come una chiamata HTTP e poi fallisce oppure chiede il 2FA.
/// Il delay lungo serve a far completare le eventuali navigazioni intermedie,
/// come succede con la latenza di rete reale.
final class TimingFakeAuthController extends AuthController {
  TimingFakeAuthController(this._initial, {this.twoFactor = false});

  final AuthState _initial;
  final bool twoFactor;

  @override
  AuthState build() => _initial;

  @override
  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
    bool acceptBadCertificates = false,
  }) async {
    state = const AuthLoading();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (twoFactor) {
      state = const AuthPending2FA(recoveryAvailable: false);
      return;
    }
    state = const AuthUnauthenticated();
    throw const ApiAuthError('Credenziali non valide.');
  }
}

Future<void> _pumpLogin(
  WidgetTester tester,
  TimingFakeAuthController controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => controller),
        // Storage reale fuori dai test: in test il MethodChannel non
        // risponde e la write resta appesa (vedi debug), quindi fake.
        secureStorageProvider.overrideWithValue(InMemoryStorage()),
      ],
      child: const YuvomiGoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  final fields = find.byType(EditableText);
  await tester.enterText(fields.at(0), 'http://omvnas:4000');
  await tester.enterText(fields.at(1), 'test');
  await tester.enterText(fields.at(2), 'secret');
  await tester.tap(find.text('Accedi'));
  // Attesa a passi bounded (niente pumpAndSettle: a metà volo c'è lo splash
  // con spinner indeterminato, e a fine volo il delay fake è un timer).
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Failed login keeps the form and shows the error', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      TimingFakeAuthController(const AuthUnauthenticated()),
    );
    await _fillAndSubmit(tester);

    // Lo screen non deve essere stato smontato dal volo: il form resta
    // compilato e l'errore è visibile inline.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Credenziali non valide.'), findsOneWidget);
    final urlField = tester.widget<TextField>(find.byType(TextField).first);
    expect(urlField.controller?.text, 'http://omvnas:4000');
  });

  testWidgets('Pending 2FA keeps the verify button enabled', (tester) async {
    await _pumpLogin(
      tester,
      TimingFakeAuthController(const AuthUnauthenticated(), twoFactor: true),
    );
    await _fillAndSubmit(tester);

    expect(find.text('Codice'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verifica'),
    );
    expect(button.enabled, isTrue);
  });
}
