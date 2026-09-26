import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/preferences_repository.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/settings/preferences_providers.dart';
import 'package:yuvomigo/features/settings/settings_screen.dart';

import 'utils/fake_auth_controller.dart';
import 'utils/in_memory_storage.dart';

final class FakePreferencesRepository extends PreferencesRepository {
  FakePreferencesRepository()
    : super(
        YuvomiApi(
          baseUrl: 'http://fake.local',
          sessions: SessionManager(InMemoryStorage()),
        ),
      );

  Map<String, dynamic>? lastPatch;

  @override
  Future<AppPreferences> fetch() async => const AppPreferences();

  @override
  Future<AppPreferences> update(Map<String, dynamic> patch) async {
    lastPatch = patch;
    return AppPreferences(
      holidayCountry: patch['holiday_country'] as String?,
      holidayShowPublic: patch['holiday_show_public'] as bool? ?? true,
      holidayShowSchool: patch['holiday_show_school'] as bool? ?? true,
    );
  }

  @override
  Future<List<HolidayCountry>> fetchHolidayCountries() async => const [
    HolidayCountry(isoCode: 'IT', name: 'Italia'),
    HolidayCountry(isoCode: 'DE', name: 'Germania'),
  ];
}

Widget _pump(
  FakeAuthController controller, {
  FakePreferencesRepository? preferences,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => controller),
      if (preferences != null)
        preferencesRepositoryProvider.overrideWithValue(preferences),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  testWidgets('Settings shows the profile and logs out after confirmation', (
    tester,
  ) async {
    final controller = FakeAuthController(Authenticated(user: fakeUser()));
    await tester.pumpWidget(_pump(controller));
    await tester.pumpAndSettle();

    expect(find.text('Utente Test'), findsOneWidget);
    expect(find.textContaining('test · admin'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Colore tema'), findsOneWidget);
    expect(find.text('Festività'), findsOneWidget);

    await tester.tap(find.text('Esci'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vuoi uscire'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Esci'));
    await tester.pumpAndSettle();

    expect(controller.logoutCalled, isTrue);
  });

  testWidgets('Holiday settings save the country and the switches', (
    tester,
  ) async {
    final preferences = FakePreferencesRepository();
    await tester.pumpWidget(
      _pump(
        FakeAuthController(Authenticated(user: fakeUser())),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Festività'));
    await tester.pumpAndSettle();

    expect(find.text('Paese'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Germania (DE)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Festività scolastiche'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(preferences.lastPatch, {
      'holiday_country': 'DE',
      'holiday_show_public': true,
      'holiday_show_school': false,
    });
  });
}
